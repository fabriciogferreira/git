"""Management HTTP + MCP helpers for pre-QA (tokens never printed)."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

ENV_D = Path.home() / ".config" / "environment.d"
MCP_URL = os.environ.get("OLIE_MCP_URL", "https://api.olie.ai/mcp/management")
MGMT_BASE = os.environ.get("OLIE_MANAGEMENT_BASE_URL", "https://api.olie.ai/api/management")
UA = "workvm-host-card-pre-qa/1.0"


def _read_env_var(name: str) -> str:
    value = os.environ.get(name) or ""
    if value:
        return value
    if ENV_D.is_dir():
        for path in sorted(ENV_D.glob("*.conf")):
            for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
                if line.startswith(f"{name}="):
                    return line.split("=", 1)[1].strip().strip('"').strip("'")
    return ""


def load_mgmt_token() -> str:
    tok = _read_env_var("OLIE_MANAGEMENT_TOKEN")
    if not tok:
        raise SystemExit("error: OLIE_MANAGEMENT_TOKEN missing in environment.d")
    return tok


def load_mcp_token() -> str:
    tok = _read_env_var("OLIE_FLOW_AI_MCP_TOKEN") or _read_env_var("OLIE_MANAGEMENT_TOKEN")
    if not tok:
        raise SystemExit("error: OLIE_FLOW_AI_MCP_TOKEN / OLIE_MANAGEMENT_TOKEN missing")
    return tok


def http_json(
    method: str,
    url: str,
    token: str,
    body: dict[str, Any] | None = None,
    timeout: int = 120,
) -> Any:
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": UA,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code} {method} {url}: {err[:800]}") from e
    if not raw.strip():
        return {}
    return json.loads(raw)


def mcp_call(token: str, name: str, arguments: dict[str, Any], req_id: int = 1) -> Any:
    body = json.dumps(
        {
            "jsonrpc": "2.0",
            "id": req_id,
            "method": "tools/call",
            "params": {"name": name, "arguments": arguments},
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        MCP_URL,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "User-Agent": UA,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"MCP HTTP {e.code} on {name}: {err[:500]}") from e

    payload = None
    if raw.lstrip().startswith("{"):
        payload = json.loads(raw)
    else:
        for line in raw.splitlines():
            if line.startswith("data:"):
                chunk = line[5:].strip()
                if chunk and chunk != "[DONE]":
                    try:
                        payload = json.loads(chunk)
                    except json.JSONDecodeError:
                        continue
    if not isinstance(payload, dict):
        raise RuntimeError(f"MCP bad response for {name}: {raw[:300]}")
    if "error" in payload:
        raise RuntimeError(f"MCP error {name}: {payload['error']}")
    result = payload.get("result") or {}
    if result.get("isError"):
        raise RuntimeError(f"MCP tool error {name}: {result}")
    content = result.get("content") or []
    texts = [c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text"]
    joined = "\n".join(texts).strip()
    if not joined:
        return result
    try:
        return json.loads(joined)
    except json.JSONDecodeError:
        return {"text": joined}


def get_project_details(mcp_token: str, code: str) -> dict[str, Any]:
    details = mcp_call(mcp_token, "get-project-details-tool", {"project_identifier": code})
    return details.get("project") or details


def get_project_http(mgmt_token: str, project_id: str) -> dict[str, Any]:
    raw = http_json("GET", f"{MGMT_BASE}/projects/{project_id}", mgmt_token)
    return raw.get("project") or raw.get("data") or raw


def toggle_checklist(mgmt_token: str, project_id: str, step_checklist_id: int) -> Any:
    return http_json(
        "POST",
        f"{MGMT_BASE}/toggle-funnel-checklist",
        mgmt_token,
        {"project_id": project_id, "step_checklist_id": step_checklist_id},
    )


def move_project_http(
    mgmt_token: str,
    project_id: str,
    step_id: int,
    *,
    unlink_others: bool = True,
    force_funnel_link: bool = False,
) -> Any:
    return http_json(
        "POST",
        f"{MGMT_BASE}/project-bulk-step-move",
        mgmt_token,
        {
            "project_ids": [project_id],
            "step_id": step_id,
            "unlink_others": unlink_others,
            "force_funnel_link": force_funnel_link,
        },
    )


def move_project_mcp(mcp_token: str, code: str, step_id: int) -> Any:
    return mcp_call(
        mcp_token,
        "move-project-to-funnel-step-tool",
        {
            "project_identifier": code,
            "funnel_step_id": step_id,
            "unlink_others": True,
            "force_funnel_link": False,
        },
    )
