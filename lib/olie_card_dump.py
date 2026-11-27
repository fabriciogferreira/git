#!/usr/bin/env python3
"""Dump card project + Caderno + media to markdown under olie/cards/<CODE>/.

Problema: implementation.md pedia ao agente get-project / notebook / media via
MCP e gastava tokens. O manager dispara isto; o agente só lê os .md.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

MCP_URL = os.environ.get("OLIE_MCP_URL", "https://api.olie.ai/mcp/management")
ENV_D = Path.home() / ".config" / "environment.d"


def load_token() -> str:
    value = os.environ.get("OLIE_FLOW_AI_MCP_TOKEN") or os.environ.get("OLIE_MANAGEMENT_TOKEN") or ""
    if value:
        return value
    if ENV_D.is_dir():
        for path in sorted(ENV_D.glob("*.conf")):
            for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
                if line.startswith("OLIE_FLOW_AI_MCP_TOKEN="):
                    value = line.split("=", 1)[1].strip().strip('"').strip("'")
                elif line.startswith("OLIE_MANAGEMENT_TOKEN=") and not value:
                    value = line.split("=", 1)[1].strip().strip('"').strip("'")
    if not value:
        raise SystemExit("error: set OLIE_FLOW_AI_MCP_TOKEN in ~/.config/environment.d/*.conf")
    return value


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
            # Cloudflare 1010 bans default Python-urllib signature.
            "User-Agent": "workvm-olie-card-dump/1.0 (curl-compatible)",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")
        raise SystemExit(f"MCP HTTP {e.code} on {name}: {err[:500]}") from e

    # SSE or plain JSON
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
        raise SystemExit(f"MCP bad response for {name}: {raw[:300]}")
    if "error" in payload:
        raise SystemExit(f"MCP error {name}: {payload['error']}")
    result = payload.get("result") or {}
    if result.get("isError"):
        raise SystemExit(f"MCP tool error {name}: {result}")
    content = result.get("content") or []
    texts = [c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text"]
    joined = "\n".join(texts).strip()
    if not joined:
        return result
    try:
        return json.loads(joined)
    except json.JSONDecodeError:
        return {"text": joined}


def strip_signed_urls(md: str) -> str:
    # Drop query strings on https URLs (signed S3 expire)
    return re.sub(r"(https://[^\s)\]]+)\?[^\s)\]]+", r"\1", md)


def slugify(name: str, page_id: Any) -> str:
    base = re.sub(r"[^a-zA-Z0-9._-]+", "-", (name or "page").strip()).strip("-").lower()
    if not base:
        base = "page"
    return f"{page_id}-{base[:60]}"


def walk_pages(nodes: list[Any], acc: list[dict[str, Any]], depth: int = 0) -> None:
    for node in nodes or []:
        if not isinstance(node, dict):
            continue
        acc.append(
            {
                "id": node.get("id"),
                "name": node.get("name") or "",
                "parent_id": node.get("parent_id"),
                "order": node.get("order"),
                "revision": node.get("revision"),
                "depth": depth,
            }
        )
        walk_pages(node.get("children") or [], acc, depth + 1)


def md_escape_fence(text: str) -> str:
    return text.replace("```", "``\u200b`")


def write_project_md(out: Path, project: dict[str, Any], dumped_at: str) -> None:
    code = project.get("code") or ""
    lines = [
        f"# {code} — {project.get('name') or ''}",
        "",
        f"_Dumped at {dumped_at}_",
        "",
        "## Meta",
        "",
        f"- id: `{project.get('id')}`",
        f"- code: `{code}`",
        f"- impact: `{project.get('impact')}`",
        f"- status: `{project.get('status')}`",
        f"- parent_id: `{project.get('parent_id')}`",
        "",
        "## Description",
        "",
        project.get("description") or "_(empty)_",
        "",
        "## Current funnel steps",
        "",
    ]
    for step in project.get("funnel_steps") or []:
        lines.append(f"- `{step.get('id')}` {step.get('name')}")
    lines += ["", "## Assignees", ""]
    for u in project.get("users") or []:
        role = (u.get("pivot") or {}).get("role") or ""
        lines.append(f"- {u.get('name')} (`{role}`)")
    lines += ["", "## Tags", ""]
    for t in project.get("tags") or []:
        lines.append(f"- {t.get('name')}")
    lines += ["", "## Form answers (summary)", ""]
    for block in project.get("all_forms_answers") or []:
        form = block.get("form") or {}
        title = form.get("title") or "form"
        lines.append(f"### {title}")
        lines.append("")
        for ans in block.get("answers") or []:
            label = ans.get("label") or "?"
            val = ans.get("answer_markdown") or ans.get("answer")
            if val is None:
                val = "—"
            elif isinstance(val, (dict, list)):
                val = "```json\n" + json.dumps(val, ensure_ascii=False, indent=2) + "\n```"
            else:
                val = str(val)
            lines.append(f"**{label}**")
            lines.append("")
            lines.append(val)
            lines.append("")
    parent = project.get("parent")
    if isinstance(parent, dict) and parent.get("code"):
        lines += [
            "## Parent",
            "",
            f"- `{parent.get('code')}` — {parent.get('name')}",
            f"- {parent.get('description') or ''}",
            "",
        ]
    children = project.get("children") or []
    if children:
        lines += ["## Children", ""]
        for ch in children:
            lines.append(f"- `{ch.get('code')}` — {ch.get('name')}")
        lines.append("")
    (out / "project.md").write_text("\n".join(lines), encoding="utf-8")


def write_notebook(
    out: Path,
    token: str,
    notebook_payload: Any,
    req_id_start: int,
) -> int:
    nb_dir = out / "notebook"
    nb_dir.mkdir(parents=True, exist_ok=True)
    req_id = req_id_start

    if not notebook_payload or notebook_payload.get("notebook") is None:
        (nb_dir / "index.md").write_text(
            "# Caderno\n\n_No notebook on this project (`notebook: null`)._\n",
            encoding="utf-8",
        )
        return req_id

    notebook = notebook_payload.get("notebook") or notebook_payload
    pages_tree = notebook.get("pages") or notebook_payload.get("pages") or []
    flat: list[dict[str, Any]] = []
    walk_pages(pages_tree, flat)

    index = [
        "# Caderno — index",
        "",
        f"- notebook_id: `{notebook.get('id')}`",
        f"- default_page_id: `{notebook.get('default_page_id') or notebook_payload.get('default_page_id')}`",
        f"- pages: **{len(flat)}**",
        "",
    ]
    for p in flat:
        indent = "  " * int(p.get("depth") or 0)
        slug = slugify(str(p.get("name")), p.get("id"))
        index.append(f"{indent}- [{p.get('name')}](./{slug}.md) (`{p.get('id')}`)")
    index.append("")
    (nb_dir / "index.md").write_text("\n".join(index), encoding="utf-8")

    for p in flat:
        page_id = p.get("id")
        if page_id is None:
            continue
        req_id += 1
        data = mcp_call(token, "read-notebook-page-tool", {"page_id": int(page_id)}, req_id)
        blocks = data.get("blocks") or []
        revision = data.get("revision")
        slug = slugify(str(p.get("name")), page_id)
        body = [
            f"# {p.get('name')}",
            "",
            f"- page_id: `{page_id}`",
            f"- revision: `{revision}`",
            f"- parent_id: `{p.get('parent_id')}`",
            "",
            "## Content",
            "",
        ]
        if not blocks:
            body.append("_(empty page)_")
            body.append("")
        for b in blocks:
            md = strip_signed_urls(str(b.get("markdown") or ""))
            btype = b.get("type") or "block"
            body.append(f"<!-- type:{btype} ref:{b.get('ref')} -->")
            body.append(md)
            body.append("")
        (nb_dir / f"{slug}.md").write_text("\n".join(body), encoding="utf-8")
    return req_id


def write_media(out: Path, token: str, code: str, req_id_start: int) -> int:
    req_id = req_id_start
    items: list[Any] = []
    page = 1
    while True:
        req_id += 1
        data = mcp_call(
            token,
            "get-project-media-tool",
            {"project_identifier": code, "filter": "default", "page": page},
            req_id,
        )
        batch = data.get("data") or data.get("media") or data.get("items") or []
        if isinstance(data, dict) and "project" in data and not batch:
            # unexpected shape
            batch = data.get("content") or []
        if not isinstance(batch, list):
            batch = []
        if not batch:
            # some APIs nest under meta pagination
            if page == 1 and isinstance(data, dict):
                # keep raw dump for debugging
                (out / "media.raw.json").write_text(
                    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8",
                )
            break
        items.extend(batch)
        # stop if last page
        meta = data.get("meta") or data.get("pagination") or {}
        last = meta.get("last_page") or meta.get("lastPage")
        if last is not None and page >= int(last):
            break
        if len(batch) < 20:
            break
        page += 1
        if page > 50:
            break

    lines = [
        f"# Media — {code}",
        "",
        f"_filter=default · {len(items)} items_",
        "",
    ]
    for i, it in enumerate(items, 1):
        if not isinstance(it, dict):
            lines.append(f"## Item {i}")
            lines.append("")
            lines.append("```")
            lines.append(str(it)[:2000])
            lines.append("```")
            lines.append("")
            continue
        mid = it.get("id") or it.get("uuid") or i
        created = it.get("created_at") or it.get("createdAt") or ""
        author = ""
        user = it.get("user") or it.get("author") or {}
        if isinstance(user, dict):
            author = user.get("name") or ""
        text = it.get("text") or it.get("content") or it.get("message") or ""
        if isinstance(text, dict):
            text = json.dumps(text, ensure_ascii=False)
        text = strip_signed_urls(str(text))
        kind = it.get("type") or it.get("media_type") or ""
        file_url = it.get("file_url") or ""
        if file_url:
            file_url = strip_signed_urls(str(file_url))
        lines.append(f"## {mid}")
        lines.append("")
        lines.append(f"- at: `{created}`")
        lines.append(f"- by: {author or '—'}")
        lines.append(f"- type: `{kind}`")
        if file_url:
            lines.append(f"- file: `{file_url}`")
        lines.append("")
        if text:
            lines.append(text)
            lines.append("")
    (out / "media.md").write_text("\n".join(lines), encoding="utf-8")
    return req_id


def write_index(out: Path, code: str, dumped_at: str) -> None:
    (out / "README.md").write_text(
        "\n".join(
            [
                f"# Card dump — {code}",
                "",
                f"_Generated {dumped_at} by `workvm-olie-card-dump` / manager **Card Spec**._",
                "",
                "Agent: read these files instead of calling get-project / notebook / media MCP.",
                "",
                "- [project.md](./project.md) — details, description, forms",
                "- [notebook/index.md](./notebook/index.md) — Caderno tree + pages",
                "- [media.md](./media.md) — timeline (`filter=default`)",
                "",
            ]
        ),
        encoding="utf-8",
    )


def dump_card(code: str, cards_root: Path) -> Path:
    code = code.strip().upper()
    token = load_token()
    dumped_at = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
    out = cards_root / code
    out.mkdir(parents=True, exist_ok=True)

    print(f"dump {code} → {out}", file=sys.stderr)
    details = mcp_call(token, "get-project-details-tool", {"project_identifier": code}, 1)
    project = details.get("project") or details
    write_project_md(out, project, dumped_at)

    model_id = project.get("id") or code
    notebook = mcp_call(
        token,
        "get-notebook-tool",
        {"model_type": "project", "model_id": str(model_id)},
        2,
    )
    req_id = write_notebook(out, token, notebook, 2)
    req_id = write_media(out, token, code, req_id)
    write_index(out, code, dumped_at)

    # compact manifest for scripts
    (out / "manifest.json").write_text(
        json.dumps(
            {
                "code": code,
                "project_id": project.get("id"),
                "dumped_at": dumped_at,
                "paths": ["README.md", "project.md", "notebook/", "media.md"],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"ok {out}/README.md", file=sys.stderr)
    return out


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--code", required=True, help="Card code, e.g. DOP-1136")
    p.add_argument(
        "--cards-root",
        default=str(Path.home() / "git" / "olie" / "cards"),
        help="Directory that holds per-card folders",
    )
    args = p.parse_args(argv)
    dump_card(args.code, Path(args.cards_root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
