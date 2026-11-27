#!/usr/bin/env python3
"""Gap seed: Card Spec requirements + change-set tests for the agent to judge.

Problema: test-gap-analysis.md montava contexto (MCP + git + skim de testes) no
chat. Este módulo grava latest.json / latest.md; o agente só compara e lista gaps.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

ARTIFACT_VERSION = 1
ROOT = Path(__file__).resolve().parents[2]

# it('…') / test('…') / describe('…') — Pest + PHPUnit style titles
TITLE_RE = re.compile(
    r"""(?P<kind>it|test|describe)\s*\(\s*(['"])(?P<title>(?:\\.|(?!\2).)*)\2""",
    re.M,
)


def _load_coverage():
    path = ROOT / "lib" / "coverage" / "score.py"
    name = "workvm_coverage_score"
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def git_out(api_main: Path, *args: str) -> str:
    r = subprocess.run(
        ["git", "-C", str(api_main), *args],
        check=False,
        capture_output=True,
        text=True,
    )
    return (r.stdout or "").strip()


def extract_titles(php: Path) -> list[dict[str, str]]:
    text = php.read_text(encoding="utf-8", errors="replace")
    out: list[dict[str, str]] = []
    for m in TITLE_RE.finditer(text):
        title = (
            m.group("title")
            .replace(r"\'", "'")
            .replace(r'\"', '"')
            .replace(r"\\", "\\")
        )
        out.append({"kind": m.group("kind"), "title": title})
    return out


def read_requirements(spec_dir: Path) -> dict[str, Any]:
    project = spec_dir / "project.md"
    notebook_index = spec_dir / "notebook" / "index.md"
    project_text = ""
    if project.is_file():
        project_text = project.read_text(encoding="utf-8", errors="replace")
    # Cap very large dumps so the artifact stays agent-readable
    max_chars = 60_000
    truncated = len(project_text) > max_chars
    if truncated:
        project_text = project_text[:max_chars] + "\n\n… [truncated]\n"

    notebook_titles: list[str] = []
    if notebook_index.is_file():
        for ln in notebook_index.read_text(encoding="utf-8", errors="replace").splitlines():
            s = ln.strip()
            if s.startswith("- ") or s.startswith("* ") or s.startswith("#"):
                notebook_titles.append(s.lstrip("#*- ").strip())
            if len(notebook_titles) >= 80:
                break

    return {
        "project_md": str(project) if project.is_file() else None,
        "project_excerpt": project_text,
        "project_truncated": truncated,
        "notebook_index": str(notebook_index) if notebook_index.is_file() else None,
        "notebook_titles": notebook_titles,
    }


def write_md(path: Path, data: dict[str, Any]) -> None:
    lines = [
        f"# Gap seed — {data.get('code')}",
        "",
        f"- status: `{data.get('status')}`",
        f"- measured_at: {data.get('measured_at')}",
        f"- tip: `{data.get('tip')}`",
        f"- api_main: `{data.get('api_main')}`",
        f"- spec_dir: `{data.get('spec_dir')}`",
        "",
        f"**agent_action:** {data.get('agent_action')}",
        "",
        "## App files (change-set)",
        "",
    ]
    apps = data.get("app_files") or []
    if not apps:
        lines.append("_none_")
    else:
        for p in apps:
            lines.append(f"- `{p}`")
    lines.extend(["", "## Tests (change-set)", ""])
    tests = data.get("tests") or []
    if not tests:
        lines.append("_none_")
    else:
        for t in tests:
            lines.append(f"### `{t['path']}`")
            titles = t.get("titles") or []
            if not titles:
                lines.append("- _(no it/test/describe titles found)_")
            else:
                for tit in titles:
                    lines.append(f"- **{tit['kind']}:** {tit['title']}")
            lines.append("")
    req = data.get("requirements") or {}
    lines.extend(["## Notebook titles", ""])
    ntitles = req.get("notebook_titles") or []
    if not ntitles:
        lines.append("_none / no notebook index_")
    else:
        for t in ntitles:
            lines.append(f"- {t}")
    lines.extend(
        [
            "",
            "## project.md excerpt",
            "",
            "```markdown",
            (req.get("project_excerpt") or "_missing project.md_").rstrip(),
            "```",
            "",
        ]
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build(
    *,
    project: str,
    code: str,
    api_main: Path,
    spec_dir: Path,
    out_dir: Path,
) -> dict[str, Any]:
    cov = _load_coverage()
    tip = git_out(api_main, "rev-parse", "HEAD") or None
    measured_at = datetime.now().isoformat(timespec="seconds")

    if not (spec_dir / "README.md").is_file() and not (spec_dir / "project.md").is_file():
        data: dict[str, Any] = {
            "version": ARTIFACT_VERSION,
            "project": project,
            "code": code,
            "measured_at": measured_at,
            "api_main": str(api_main),
            "tip": tip,
            "status": "error",
            "spec_dir": str(spec_dir),
            "requirements": {},
            "tests": [],
            "app_files": [],
            "agent_action": (
                f"Card Spec missing under {spec_dir}. "
                "User: manager → Card Spec for this code, then re-run Gap."
            ),
            "error": "card_spec_missing",
        }
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / "latest.json").write_text(
            json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        write_md(out_dir / "latest.md", data)
        return data

    all_paths, _hunks = cov.change_set_paths(api_main, code)
    app_files = [p for p in all_paths if p.startswith("app/") and p.endswith(".php")]
    test_paths = [
        p for p in all_paths if p.startswith("tests/") and p.endswith("Test.php")
    ]

    if not app_files and not test_paths:
        data = {
            "version": ARTIFACT_VERSION,
            "project": project,
            "code": code,
            "measured_at": measured_at,
            "api_main": str(api_main),
            "tip": tip,
            "status": "skip_no_backend",
            "spec_dir": str(spec_dir),
            "requirements": read_requirements(spec_dir),
            "tests": [],
            "app_files": [],
            "agent_action": (
                "No api-main paths in change-set. Skip gap analysis "
                "(or confirm Backend change-set / merged-tip fallback)."
            ),
        }
    else:
        tests: list[dict[str, Any]] = []
        for rel in test_paths:
            php = api_main / rel
            tests.append(
                {
                    "path": rel,
                    "titles": extract_titles(php) if php.is_file() else [],
                }
            )
        data = {
            "version": ARTIFACT_VERSION,
            "project": project,
            "code": code,
            "measured_at": measured_at,
            "api_main": str(api_main),
            "tip": tip,
            "status": "ready" if (app_files or test_paths) else "empty",
            "spec_dir": str(spec_dir),
            "requirements": read_requirements(spec_dir),
            "tests": tests,
            "app_files": app_files,
            "agent_action": (
                "Compare requirements (project.md excerpt + notebook titles + "
                "spec_dir files) with tests[]. Report exactly one exit: "
                "**No tests to add** or **Tests to add** (title + description each). "
                "Do not MCP-rebuild the card. Do not implement unless user sends `add`."
            ),
        }

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "latest.json").write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    write_md(out_dir / "latest.md", data)

    # Human copy next to Card Spec when possible
    if spec_dir.is_dir() and data.get("status") != "error":
        seed_md = spec_dir / "gap-seed.md"
        write_md(seed_md, data)
        data["gap_seed_md"] = str(seed_md)
        (out_dir / "latest.json").write_text(
            json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )

    return data


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Build gap seed artifact")
    p.add_argument("--project", required=True)
    p.add_argument("--code", required=True)
    p.add_argument("--api-main", required=True, type=Path)
    p.add_argument("--spec-dir", required=True, type=Path)
    p.add_argument("--out-dir", required=True, type=Path)
    args = p.parse_args(argv)

    if not args.api_main.is_dir():
        print(f"api-main ausente: {args.api_main}", file=sys.stderr)
        return 1

    data = build(
        project=args.project,
        code=args.code,
        api_main=args.api_main,
        spec_dir=args.spec_dir,
        out_dir=args.out_dir,
    )
    print(json.dumps({"status": data["status"], "out": str(args.out_dir / "latest.json")}))
    if data["status"] == "error":
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
