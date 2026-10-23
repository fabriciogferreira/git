#!/usr/bin/env python3
# The public site cannot SSH into the libvirt LAN. This host polls the API and
# runs the card scripts. It does not open a port. The token stays in
# ~/.config/workvm/agent.conf (OPBED_API_URL, OPBED_AGENT_TOKEN).

from __future__ import annotations

import json
import os
import subprocess
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


def run(action: str, template: str | None, name: str) -> tuple[int, str, str]:
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


def main() -> None:
    api, token = load_conf()
    request(api, token, "POST", "/work-vm-commands/release", {})

    while True:
        try:
            status, body = request(api, token, "POST", "/work-vm-commands/claim", {})
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
        name = command.get("name")
        template = command.get("template")
        command_id = command.get("id")

        if not isinstance(action, str) or not isinstance(name, str) or not isinstance(command_id, int):
            time.sleep(PAUSE_S)
            continue

        code, stdout, stderr = run(action, template if isinstance(template, str) else None, name)

        try:
            request(api, token, "POST", f"/work-vm-commands/{command_id}/result", {
                "code": code,
                "stdout": stdout,
                "stderr": stderr,
            })
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
            time.sleep(PAUSE_S)


if __name__ == "__main__":
    main()
