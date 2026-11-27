#!/usr/bin/env python3
"""Pest full-suite artifact + ledger for the project-card manager.

Problema: pest-parallel.md media no chat. Manager Pest já roda a suite; isto
grava latest.json / pest-ledger.md para o agente só consertar fails.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from dataclasses import asdict, dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

ARTIFACT_VERSION = 1

SUMMARY_RE = re.compile(
    r"Tests:\s*(?:(?P<failed>\d+)\s+failed(?:,\s*)?)?"
    r"(?:(?P<passed>\d+)\s+passed(?:,\s*)?)?"
    r"(?:(?P<skipped>\d+)\s+skipped(?:,\s*)?)?"
    r"(?:(?P<todo>\d+)\s+todo(?:,\s*)?)?"
    r"(?:(?P<pending>\d+)\s+pending(?:,\s*)?)?",
    re.I,
)
# Pest compact: "FAILED  Tests\Feature\Foo" or "⨯ Foo bar"
FAIL_LINE_RE = re.compile(
    r"(?:FAILED|FAIL)\s+(?P<name>.+?)(?:\s+\d+\.\d+s)?\s*$",
    re.I | re.M,
)
LEDGER_ROW_RE = re.compile(
    r"^\|\s*`(?P<code>[^`]+)`\s*\|\s*`(?P<tip>[^`]*)`\s*\|\s*"
    r"`(?P<result>[^`]*)`\s*\|\s*`(?P<measured>[^`]*)`\s*\|\s*(?P<notes>.*?)\s*\|$"
)


@dataclass
class Artifact:
    version: int
    project: str
    code: str
    measured_at: str
    api_main: str
    tip: str
    status: str
    exit_code: int
    summary: dict[str, int]
    failures: list[str] = field(default_factory=list)
    agent_action: str | None = None
    log: str = ""
    notes: str = ""


def run(cmd: list[str], check: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, text=True, capture_output=True, check=check)


def resolve_api_main(git_root: Path, project: str, code: str) -> Path:
    # Prefer host-card meta
    try:
        # shell out to bash sourcing host-card is heavy; duplicate id formula
        safe = re.sub(r"[^a-z0-9]+", "-", code.lower()).strip("-")
        card_id = f"{project}-{safe}"
        meta = (
            Path.home()
            / ".local/share/workvm/host-cards"
            / project
            / card_id
            / "meta.json"
        )
        # also try workvm_host_card_id style: olie-dop-1136
        if not meta.is_file():
            # scan
            root = Path.home() / ".local/share/workvm/host-cards" / project
            if root.is_dir():
                for p in root.glob("*/meta.json"):
                    try:
                        data = json.loads(p.read_text(encoding="utf-8"))
                        if str(data.get("code") or "").upper() == code.upper():
                            meta = p
                            break
                    except Exception:
                        continue
        if meta.is_file():
            data = json.loads(meta.read_text(encoding="utf-8"))
            wt = data.get("api_worktree") or ""
            if wt:
                cand = Path(wt) / "api-main"
                if cand.is_dir():
                    return cand
                if Path(wt).is_dir():
                    return Path(wt)
    except Exception:
        pass
    return git_root / project / "api-main"


def parse_log(text: str) -> tuple[dict[str, int], list[str]]:
    summary = {"passed": 0, "failed": 0, "skipped": 0}
    m = SUMMARY_RE.search(text)
    if m:
        for k in ("passed", "failed", "skipped", "todo", "pending"):
            if m.groupdict().get(k):
                summary[k if k in summary else k] = int(m.group(k))
        if m.group("failed"):
            summary["failed"] = int(m.group("failed"))
        if m.group("passed"):
            summary["passed"] = int(m.group("passed"))
        if m.group("skipped"):
            summary["skipped"] = int(m.group("skipped"))

    failures: list[str] = []
    for fm in FAIL_LINE_RE.finditer(text):
        name = fm.group("name").strip()
        if name and name not in failures and len(failures) < 40:
            failures.append(name)
    # Fallback: lines with "⨯" or "FAILED"
    if not failures:
        for ln in text.splitlines():
            if "FAILED" in ln or ln.strip().startswith("⨯"):
                cleaned = re.sub(r"^.*?FAILED\s+", "", ln).strip()
                cleaned = cleaned.lstrip("⨯").strip()
                if cleaned and cleaned not in failures and len(failures) < 40:
                    failures.append(cleaned[:200])
    return summary, failures


def render_md(art: Artifact) -> str:
    fails = "\n".join(f"- `{f}`" for f in art.failures) or "- —"
    return "\n".join(
        [
            f"# Pest suite — {art.project} / {art.code}",
            "",
            f"- measured_at: `{art.measured_at}`",
            f"- tip: `{art.tip}`",
            f"- status: **{art.status}**",
            f"- exit_code: `{art.exit_code}`",
            f"- summary: `{json.dumps(art.summary)}`",
            f"- log: `{art.log}`",
            "",
            "## Failures",
            fails,
            "",
            f"Agent: {art.agent_action or '—'}",
            "",
            "Contract: `lib/pest/ARTIFACT.md`. Ledger: `olie/prompts/pest-ledger.md`.",
            "",
        ]
    )


def update_ledger(ledger_path: Path, art: Artifact) -> None:
    if art.status != "pass" or not ledger_path.parent.is_dir():
        return
    if not ledger_path.is_file():
        ledger_path.write_text(
            "# Pest ledger\n\n"
            "Full-suite gate (manager **Pest**). One row per card@tip when green.\n\n"
            "| Card | Tip | Result | Last measured | Notes |\n"
            "| --- | --- | --- | --- | --- |\n",
            encoding="utf-8",
        )
    when = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M %Z")
    notes = f"full suite. sha:{art.tip}. log `{art.log}`."
    new_row = (
        f"| `{art.code}` | `{art.tip}` | `pass` | `{when}` | {notes} |\n"
    )
    lines = ledger_path.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
    out: list[str] = []
    seen = False
    for ln in lines:
        m = LEDGER_ROW_RE.match(ln.rstrip("\n"))
        if m and m.group("code").upper() == art.code.upper():
            out.append(new_row)
            seen = True
        else:
            out.append(ln if ln.endswith("\n") else ln + "\n")
    if not seen:
        out.append(new_row)
    ledger_path.write_text("".join(out), encoding="utf-8")


def write_artifact(
    *,
    project: str,
    code: str,
    exit_code: int,
    log_path: Path,
    out_dir: Path,
    api_main: Path,
    ledger_path: Path | None,
) -> Artifact:
    tip = ""
    if api_main.is_dir():
        tip = run(
            ["git", "-C", str(api_main), "rev-parse", "--short=12", "HEAD"]
        ).stdout.strip()
    text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.is_file() else ""
    summary, failures = parse_log(text)
    if exit_code == 0:
        status = "pass"
        action = None
    else:
        status = "needs_work"
        fail_s = ", ".join(failures[:8]) or "(see log)"
        action = (
            f"Fix failing Pest suite tests for {code}: {fail_s}. "
            "Do not re-run the full suite in chat — user re-runs Pest in the manager."
        )

    art = Artifact(
        version=ARTIFACT_VERSION,
        project=project,
        code=code,
        measured_at=datetime.now().astimezone().isoformat(timespec="seconds"),
        api_main=str(api_main),
        tip=tip,
        status=status,
        exit_code=exit_code,
        summary=summary,
        failures=failures,
        agent_action=action,
        log=str(log_path),
        notes="full suite via workvm-host-card-pest",
    )
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "latest.json").write_text(
        json.dumps(asdict(art), indent=2) + "\n", encoding="utf-8"
    )
    (out_dir / "latest.md").write_text(render_md(art), encoding="utf-8")
    if ledger_path is not None:
        update_ledger(ledger_path, art)
    return art


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--project", required=True)
    p.add_argument("--code", required=True)
    p.add_argument("--exit-code", type=int, required=True)
    p.add_argument("--log", required=True)
    p.add_argument("--out-dir", required=True)
    p.add_argument("--git-root", default=str(Path.home() / "git"))
    p.add_argument("--ledger", default="")
    p.add_argument("--api-main", default="")
    args = p.parse_args(argv)

    api_main = Path(args.api_main) if args.api_main else resolve_api_main(
        Path(args.git_root), args.project, args.code
    )
    ledger = Path(args.ledger) if args.ledger else None
    art = write_artifact(
        project=args.project,
        code=args.code,
        exit_code=args.exit_code,
        log_path=Path(args.log),
        out_dir=Path(args.out_dir),
        api_main=api_main,
        ledger_path=ledger,
    )
    print(json.dumps({"status": art.status, "tip": art.tip, "summary": art.summary}))
    return 0 if art.status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
