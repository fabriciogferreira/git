#!/usr/bin/env python3
# The public site cannot SSH into the libvirt LAN. This host polls the API and
# runs the card scripts. It does not open a port. The token stays in
# ~/.config/workvm/agent.conf (OPBED_API_URL, OPBED_AGENT_TOKEN).

from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path

CONF = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "workvm" / "agent.conf"
ROOT = Path.home() / "git" / "bin"
PAUSE_S = 2


def load_conf() -> tuple[str, str]:
    values: dict[str, str] = {}

    for line in CONF.read_text().splitlines():
        line = line.strip()

        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip("'\"")

    api = values["OPBED_API_URL"].rstrip("/")
    token = values["OPBED_AGENT_TOKEN"]

    return api, token


def log(text: str) -> None:
    print(text, file=sys.stderr, flush=True)


def request(api: str, token: str, method: str, path: str, payload: dict[str, object] | None) -> tuple[int, dict[str, object]]:
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        f"{api}{path}",
        data=data,
        method=method,
        headers={
            "Accept": "application/json",
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read()
            body = json.loads(raw) if raw else {}
            return response.status, body if isinstance(body, dict) else {}
    except urllib.error.HTTPError as error:
        raw = error.read()
        body: dict[str, object] = {}

        if raw:
            try:
                parsed = json.loads(raw)
            except json.JSONDecodeError:
                parsed = {"message": raw[:180].decode("utf-8", "replace")}

            if isinstance(parsed, dict):
                body = parsed

        return error.code, body


LIST_MCPS = r"""
base="$HOME/.cursor/projects"
best=""
best_m=0
if [ -d "$base" ]; then
  for dir in "$base"/*/mcps; do
    [ -d "$dir" ] || continue
    m=$(stat -c %Y "$dir" 2>/dev/null || printf '0')
    if [ "$m" -gt "$best_m" ]; then
      best=$dir
      best_m=$m
    fi
  done
fi
if [ -z "$best" ]; then
  exit 0
fi
for server in "$best"/*; do
  [ -d "$server" ] || continue
  id=$(basename "$server")
  case "$id" in
    cursor-*) continue ;;
  esac
  name=$id
  meta="$server/SERVER_METADATA.json"
  if [ -f "$meta" ]; then
    extracted=$(sed -n 's/.*"serverName"[[:space:]]*:[[:space:]]*"\([A-Za-z0-9._-]\{1,64\}\)".*/\1/p' "$meta" | head -n 1)
    if [ -n "$extracted" ]; then
      name=$extracted
    fi
  fi
  printf '%s' "$name" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' || continue
  status=ok
  if [ -f "$server/STATUS.md" ]; then
    if grep -qi authentication "$server/STATUS.md"; then
      status=auth
    else
      status=error
    fi
  fi
  printf '%s\t%s\n' "$name" "$status"
done
"""


def sh_quote(value: str) -> str:
    return "'" + value.replace("'", "'\\''") + "'"


def run_mcps(user: str, host: str, port: int) -> tuple[int, str, str]:
    key = Path.home() / ".ssh" / "workvm_ed25519"
    argv = [
        "ssh",
        "-o", "BatchMode=yes",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "UserKnownHostsFile=/tmp/work-vm-known_hosts",
        "-o", "ConnectTimeout=12",
        "-o", "LogLevel=ERROR",
        "-o", "IdentitiesOnly=yes",
        "-i", str(key),
        "-p", str(port),
        f"{user}@{host}",
        f"bash -lc {sh_quote(LIST_MCPS)}",
    ]

    try:
        completed = subprocess.run(argv, text=True, capture_output=True, timeout=20, check=False)
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout if isinstance(error.stdout, str) else ""
        stderr = error.stderr if isinstance(error.stderr, str) else ""
        return 1, stdout, stderr or "A VM não respondeu a tempo."

    return completed.returncode, completed.stdout, completed.stderr


def run_turn(command: dict[str, object]) -> tuple[int, str, str]:
    user = command.get("ssh_user")
    host = command.get("ssh_host")
    port_number = whole_int(command.get("ssh_port"))
    workspace = command.get("workspace")
    prompt = command.get("prompt")
    session = command.get("session_id")

    if not isinstance(user, str) or not isinstance(host, str) or port_number is None:
        return 1, "", "O pedido de mensagem não tem o endereço da VM."

    if not isinstance(workspace, str) or not isinstance(prompt, str) or not prompt.strip():
        return 1, "", "O pedido de mensagem está incompleto."

    resume = ""

    if isinstance(session, str) and session.strip():
        resume = f"--resume={sh_quote(session)} "

    # cursor-bin ships the IDE. The card chat runs the separate CLI, which
    # lands in ~/.local/bin. A clone made before that install does not have it.
    inner = (
        'if [ ! -x "$HOME/.local/bin/agent" ]; then '
        'curl -fsSL https://cursor.com/install | bash; '
        'fi; '
        'export PATH="$HOME/.local/bin:$PATH"; '
        'if [ ! -x "$HOME/.local/bin/agent" ]; then '
        'printf "%s\\n" "O comando agent não está instalado nesta VM." >&2; exit 127; '
        'fi; '
        'if [ -z "${CURSOR_API_KEY:-}" ] && [ -f "$HOME/.config/workvm/cursor-api-key" ]; then '
        'CURSOR_API_KEY=$(tr -d "\\n" < "$HOME/.config/workvm/cursor-api-key"); export CURSOR_API_KEY; fi; '
        'if [ -z "${CURSOR_API_KEY:-}" ]; then '
        'agent_status=$("$HOME/.local/bin/agent" status 2>&1 || true); '
        'case "$agent_status" in '
        '"Not logged in"*) printf "%s\\n" "O agent desta VM não está logado. Grave a chave do Cursor em ~/.config/workvm/cursor-api-key." >&2; exit 1 ;; '
        'esac; '
        'fi; '
        f'"$HOME/.local/bin/agent" -p --force --trust --output-format json {resume}--workspace {sh_quote(workspace)} {sh_quote(prompt)}'
    )
    key = Path.home() / ".ssh" / "workvm_ed25519"
    argv = [
        "ssh",
        "-o", "BatchMode=yes",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "UserKnownHostsFile=/tmp/work-vm-known_hosts",
        "-o", "ConnectTimeout=20",
        "-o", "LogLevel=ERROR",
        "-o", "IdentitiesOnly=yes",
        "-i", str(key),
        "-p", str(port_number),
        f"{user}@{host}",
        f"bash -lc {sh_quote(inner)}",
    ]

    try:
        # The site gives up at 540s. Finish first so the card gets this answer.
        completed = subprocess.run(argv, text=True, capture_output=True, timeout=520, check=False)
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout if isinstance(error.stdout, str) else ""
        stderr = error.stderr if isinstance(error.stderr, str) else ""
        return 1, stdout, stderr or "O agent passou do tempo."

    return completed.returncode, completed.stdout, completed.stderr


def run(action: str, template: str | None, name: str, command: dict[str, object]) -> tuple[int, str, str]:
    if action == "mcps":
        user = command.get("ssh_user")
        host = command.get("ssh_host")
        port = command.get("ssh_port")

        port_number = whole_int(port)

        if not isinstance(user, str) or not isinstance(host, str) or port_number is None:
            return 1, "", "O pedido de MCP não tem o endereço da VM."

        return run_mcps(user, host, port_number)

    if action == "turn":
        return run_turn(command)

    if action == "ensure":
        argv = [str(ROOT / "workvm-ensure-card-vm.sh"), template or "", name]
        timeout = 1700
    elif action == "drop":
        argv = [str(ROOT / "workvm-drop-card-vm.sh"), template or "", name]
        timeout = 170
    elif action == "open":
        argv = [str(ROOT / "workvm-open-project-vm.sh"), name]
        timeout = 170
    else:
        return 1, "", f"ação desconhecida: {action}"

    try:
        completed = subprocess.run(argv, text=True, capture_output=True, timeout=timeout, check=False)
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout if isinstance(error.stdout, str) else ""
        stderr = error.stderr if isinstance(error.stderr, str) else ""
        return 1, stdout, stderr or "O comando passou do tempo."

    return completed.returncode, completed.stdout, completed.stderr


def detail(body: dict[str, object]) -> str:
    message = body.get("message")

    if isinstance(message, str) and message.strip():
        return message.replace("\n", " ")[:180]

    errors = body.get("errors")

    if isinstance(errors, dict):
        return ",".join(str(key) for key in list(errors)[:6])

    return ""


def whole_int(value: object) -> int | None:
    if isinstance(value, bool):
        return None

    if isinstance(value, int):
        return value

    if isinstance(value, float) and value.is_integer():
        return int(value)

    if isinstance(value, str) and value.isdigit():
        return int(value)

    return None


def post_result(api: str, token: str, command_id: int, code: int, stdout: str, stderr: str) -> None:
    payload = {"code": code, "stdout": stdout, "stderr": stderr}

    for _attempt in range(3):
        try:
            status, body = request(api, token, "POST", f"/work-vm-commands/{command_id}/result", payload)
            # 404 used to count as done and left the row running forever.
            if 200 <= status < 300:
                command = body.get("command") if isinstance(body.get("command"), dict) else {}
                command_status = command.get("status") if isinstance(command, dict) else None
                log(f"result {command_id} {status} {command_status}")
                return

            log(f"result {command_id} {status} {detail(body)}")
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as error:
            log(f"result {command_id} error {error.__class__.__name__}")

        time.sleep(1)


def execute_tracked(api: str, token: str, command: dict[str, object], command_id: int, inflight: set[int], inflight_lock: threading.Lock) -> None:
    try:
        execute(api, token, command)
    finally:
        with inflight_lock:
            inflight.discard(command_id)


def execute(api: str, token: str, command: dict[str, object]) -> None:
    action = command.get("action")
    name = command.get("name")
    template = command.get("template")
    command_id = whole_int(command.get("id"))

    if not isinstance(action, str) or not isinstance(name, str) or command_id is None:
        log(f"skip claimed id={command.get('id')!r} action={action!r}")
        if command_id is not None:
            post_result(api, token, command_id, 1, "", "O pedido da VM está incompleto.")
        return

    try:
        code, stdout, stderr = run(action, template if isinstance(template, str) else None, name, command)
    except Exception as error:
        log(f"run {command_id} {error.__class__.__name__}: {error}")
        code, stdout, stderr = 1, "", str(error)

    post_result(api, token, command_id, code, stdout, stderr)


def main() -> None:
    api, token = load_conf()
    try:
        me_status, me_body = request(api, token, "GET", "/user/me", None)
        me_user = me_body.get("user") if isinstance(me_body.get("user"), dict) else {}
        me_id = me_user.get("id") if isinstance(me_user, dict) else None
        me_role = me_user.get("system_role") if isinstance(me_user, dict) else None
        log(f"me {me_status} id={me_id} role={me_role}")
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as error:
        log(f"me error {error.__class__.__name__}")

    try:
        release_status, release_body = request(api, token, "POST", "/work-vm-commands/release", {})
        log(f"release {release_status} {detail(release_body)}")
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as error:
        log(f"release error {error.__class__.__name__}")
    # A clone holds the process for minutes. MCP reads have to keep going.
    # working tells the API which MCP rows this process is still inside.
    worker: threading.Thread | None = None
    inflight: set[int] = set()
    inflight_lock = threading.Lock()
    quiet = 0

    while True:
        with inflight_lock:
            working = sorted(inflight)

        claim: dict[str, object] = {"working": working}

        if worker is not None and worker.is_alive():
            claim["only"] = "mcps"

        try:
            status, body = request(api, token, "POST", "/work-vm-commands/claim", claim)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as error:
            log(f"claim error {error.__class__.__name__}")
            time.sleep(PAUSE_S)
            continue

        if status == 204:
            quiet += 1
            if quiet == 1 or quiet % 15 == 0:
                log("claim 204")
            time.sleep(PAUSE_S)
            continue

        quiet = 0

        command = body.get("command")

        if status != 200 or not isinstance(command, dict):
            log(f"claim {status} {detail(body)}")
            time.sleep(PAUSE_S)
            continue

        action = command.get("action")
        command_id = whole_int(command.get("id"))
        log(f"claim {status} id={command_id} action={action}")

        if not isinstance(action, str) or not isinstance(command.get("name"), str) or command_id is None:
            log(f"claim shape id={command.get('id')!r} action={action!r}")
            time.sleep(PAUSE_S)
            continue

        if action == "mcps":
            with inflight_lock:
                inflight.add(command_id)

            threading.Thread(
                target=execute_tracked,
                args=(api, token, command, command_id, inflight, inflight_lock),
                daemon=False,
            ).start()
            continue

        if worker is not None and worker.is_alive():
            worker.join()

        worker = threading.Thread(target=execute, args=(api, token, command), daemon=False)
        worker.start()


if __name__ == "__main__":
    main()
