#!/usr/bin/env python3
# The public site cannot SSH into the libvirt LAN. This host polls the API and
# runs the card scripts. It does not open a port. The token stays in
# ~/.config/workvm/agent.conf (OPBED_API_URL, OPBED_AGENT_TOKEN).

from __future__ import annotations

import json
import os
import subprocess
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
            parsed = json.loads(raw)
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


def run(action: str, template: str | None, name: str, command: dict[str, object]) -> tuple[int, str, str]:
    if action == "mcps":
        user = command.get("ssh_user")
        host = command.get("ssh_host")
        port = command.get("ssh_port")

        if not isinstance(user, str) or not isinstance(host, str) or not isinstance(port, int):
            return 1, "", "O pedido de MCP não tem o endereço da VM."

        return run_mcps(user, host, port)

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


def post_result(api: str, token: str, command_id: int, code: int, stdout: str, stderr: str) -> None:
    payload = {"code": code, "stdout": stdout, "stderr": stderr}

    for _attempt in range(3):
        try:
            status, _body = request(api, token, "POST", f"/work-vm-commands/{command_id}/result", payload)

            if status < 500:
                return
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
            pass

        time.sleep(1)


def execute(api: str, token: str, command: dict[str, object]) -> None:
    action = command.get("action")
    name = command.get("name")
    template = command.get("template")
    command_id = command.get("id")

    if not isinstance(action, str) or not isinstance(name, str) or not isinstance(command_id, int):
        return

    code, stdout, stderr = run(action, template if isinstance(template, str) else None, name, command)
    post_result(api, token, command_id, code, stdout, stderr)


def main() -> None:
    api, token = load_conf()
    request(api, token, "POST", "/work-vm-commands/release", {})
    # A clone holds the process for minutes. MCP reads have to keep going.
    worker: threading.Thread | None = None

    while True:
        claim: dict[str, object] = {"only": "mcps"} if worker is not None and worker.is_alive() else {}

        try:
            status, body = request(api, token, "POST", "/work-vm-commands/claim", claim)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
            time.sleep(PAUSE_S)
            continue

        if status == 204:
            time.sleep(PAUSE_S)
            continue

        command = body.get("command")

        if status != 200 or not isinstance(command, dict):
            time.sleep(PAUSE_S)
            continue

        action = command.get("action")

        if not isinstance(action, str) or not isinstance(command.get("name"), str) or not isinstance(command.get("id"), int):
            time.sleep(PAUSE_S)
            continue

        if action == "mcps":
            threading.Thread(target=execute, args=(api, token, command), daemon=False).start()
            continue

        if worker is not None and worker.is_alive():
            worker.join()

        worker = threading.Thread(target=execute, args=(api, token, command), daemon=False)
        worker.start()


if __name__ == "__main__":
    main()
