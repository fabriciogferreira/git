#!/usr/bin/env python3
"""Coverage change-set scoring + artifact writer for the project-card manager.

Problema: medir in-scope/ratchet no chat do agente gasta tokens em orquestração.
Este módulo monta o change-set, parseia Pest --coverage, aplica os gates do ledger
e grava latest.json / latest.md para o agente só implementar gaps.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

SMALL_EXECUTABLE_MAX = 80
ARTIFACT_VERSION = 1

FQCN_RE = re.compile(r"^namespace\s+([^;]+);", re.M)
CLASS_RE = re.compile(r"^(?:abstract\s+|final\s+)?(?:class|interface|enum|trait)\s+(\w+)", re.M)
PEST_FILE_LINE_RE = re.compile(
    r"^\s*(?P<path>(?:App\\[\w\\]+|(?:app/[\w./-]+\.php)))\s+\.{2,}\s+"
    r"(?P<uncovered>\d+)\s*/\s*(?P<pct>\d+(?:\.\d+)?)%",
    re.M,
)
UNCOVERED_BLOCK_RE = re.compile(
    r"(?P<header>(?:App\\[\w\\]+|app/[\w./-]+\.php))\s*\n(?P<body>(?:^[ \t]+.+\n?)+)",
    re.M,
)
LEDGER_ROW_RE = re.compile(
    r"^\|\s*`(?P<file>app/[^`]+)`\s*\|\s*`(?P<measured>[^`]*)`\s*\|\s*"
    r"`(?P<inscope>[^`]*)`\s*\|\s*`(?P<uncovered>[^`]*)`\s*\|\s*"
    r"`(?P<raw>[^`]*)`\s*\|\s*`(?P<via>[^`]*)`\s*\|\s*(?P<notes>.*?)\s*\|$"
)


@dataclass
class FileResult:
    file: str
    fqcn: str
    status: str
    band: str
    in_scope_pct: float | None
    in_scope_uncovered: list[str]
    file_raw_pct: float | None
    prev_file_raw_pct: float | None
    ratchet_target_pct: float | None
    via_tests: list[str]
    sha: str
    agent_action: str | None
    notes: str
    executable_lines: int | None = None


@dataclass
class Artifact:
    version: int
    project: str
    code: str
    measured_at: str
    api_main: str
    tip: str
    status: str
    summary: dict[str, int]
    files: list[dict[str, Any]] = field(default_factory=list)
    logs: dict[str, str] = field(default_factory=dict)


def run(cmd: list[str], cwd: Path | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        text=True,
        capture_output=True,
        check=check,
    )


def git_lines(api_main: Path, *args: str) -> list[str]:
    cp = run(["git", "-C", str(api_main), *args], check=False)
    if cp.returncode != 0:
        return []
    return [ln for ln in cp.stdout.splitlines() if ln.strip()]


def resolve_fqcn(api_main: Path, rel: str) -> str:
    text = (api_main / rel).read_text(encoding="utf-8", errors="replace")
    ns_m = FQCN_RE.search(text)
    cl_m = CLASS_RE.search(text)
    if not ns_m or not cl_m:
        # Fallback PSR-4 guess
        return "App\\" + rel[len("app/") : -4].replace("/", "\\")
    return f"{ns_m.group(1).strip()}\\{cl_m.group(1)}"


def parse_pct(raw: str) -> float | None:
    raw = raw.strip().rstrip("%")
    if not raw or raw in {"—", "-", "n/a"}:
        return None
    try:
        return float(raw)
    except ValueError:
        return None


def format_pct(value: float | None) -> str:
    if value is None:
        return "—"
    return f"{value:.1f}%"


def expand_line_tokens(token: str) -> list[int]:
    token = token.strip().rstrip(",")
    if not token:
        return []
    if ".." in token:
        a, b = token.split("..", 1)
        start, end = int(a), int(b)
        if end < start:
            start, end = end, start
        return list(range(start, end + 1))
    return [int(token)]


def parse_uncovered_list(text: str) -> list[int]:
    lines: list[int] = []
    for part in re.split(r"[,\s]+", text.strip()):
        if not part:
            continue
        try:
            lines.extend(expand_line_tokens(part))
        except ValueError:
            continue
    return sorted(set(lines))


def compact_lines(nums: list[int]) -> list[str]:
    if not nums:
        return []
    nums = sorted(set(nums))
    out: list[str] = []
    start = prev = nums[0]
    for n in nums[1:]:
        if n == prev + 1:
            prev = n
            continue
        out.append(f"{start}..{prev}" if start != prev else str(start))
        start = prev = n
    out.append(f"{start}..{prev}" if start != prev else str(start))
    return out


def parse_hunk_added_lines(diff_text: str) -> set[int]:
    """Added/modified line numbers from unified diff -U0 (new-file side)."""
    added: set[int] = set()
    for ln in diff_text.splitlines():
        if ln.startswith("@@"):
            # @@ -a,b +c,d @@
            m = re.search(r"\+(\d+)(?:,(\d+))?", ln)
            if not m:
                continue
            start = int(m.group(1))
            count = int(m.group(2) or "1")
            if count == 0:
                continue
            for i in range(start, start + count):
                added.add(i)
    return added


def change_set_paths(api_main: Path, code: str) -> tuple[list[str], dict[str, set[int]]]:
    """Return sorted production+test paths and in-scope added lines per app file."""
    candidates: set[str] = set()
    for args in (
        ["diff", "--name-only", "--diff-filter=ACMR", "develop...HEAD"],
        ["diff", "--cached", "--name-only", "--diff-filter=ACMR"],
        ["diff", "--name-only", "--diff-filter=ACMR", "HEAD"],
        ["ls-files", "--others", "--exclude-standard"],
    ):
        candidates.update(git_lines(api_main, *args))

    # Merged tip fallback when three-dot is empty but card still has backend.
    three = git_lines(api_main, "diff", "--name-only", "--diff-filter=ACMR", "develop...HEAD")
    if not three:
        merges = git_lines(
            api_main,
            "log",
            "--merges",
            "--grep",
            code,
            "--format=%H",
        )
        for merge in merges:
            subject = run(
                ["git", "-C", str(api_main), "log", "-1", "--format=%s", merge],
                check=False,
            ).stdout.strip().lower()
            if "merge develop" in subject or "merge branch 'develop'" in subject:
                continue
            candidates.update(
                git_lines(api_main, "diff", "--name-only", f"{merge}^1...{merge}^2")
            )

    app_files = sorted(
        p
        for p in candidates
        if p.startswith("app/") and p.endswith(".php") and (api_main / p).is_file()
    )
    tests = sorted(
        p
        for p in candidates
        if p.startswith("tests/") and p.endswith("Test.php") and (api_main / p).is_file()
    )

    hunks: dict[str, set[int]] = {}
    for path in app_files:
        # Prefer branch hunks; fall back to dirty vs HEAD; new file = all lines later.
        diff = run(
            ["git", "-C", str(api_main), "diff", "-U0", "develop...HEAD", "--", path],
            check=False,
        ).stdout
        if not diff.strip():
            diff = run(
                ["git", "-C", str(api_main), "diff", "-U0", "HEAD", "--", path],
                check=False,
            ).stdout
        if not diff.strip() and path in git_lines(api_main, "ls-files", "--others", "--exclude-standard"):
            # Whole new file — mark as new via empty set sentinel handled later
            hunks[path] = set()
            continue
        # Merged tip: union merge-parent hunks for this path
        if not diff.strip():
            lines: set[int] = set()
            for merge in git_lines(api_main, "log", "--merges", "--grep", code, "--format=%H"):
                subject = run(
                    ["git", "-C", str(api_main), "log", "-1", "--format=%s", merge],
                    check=False,
                ).stdout.strip().lower()
                if "merge develop" in subject:
                    continue
                piece = run(
                    [
                        "git",
                        "-C",
                        str(api_main),
                        "diff",
                        "-U0",
                        f"{merge}^1...{merge}^2",
                        "--",
                        path,
                    ],
                    check=False,
                ).stdout
                lines |= parse_hunk_added_lines(piece)
            hunks[path] = lines
        else:
            hunks[path] = parse_hunk_added_lines(diff)

    return app_files + tests, hunks


def is_new_file(api_main: Path, path: str) -> bool:
    if path in git_lines(api_main, "ls-files", "--others", "--exclude-standard"):
        return True
    # Added on branch vs develop
    names = git_lines(api_main, "diff", "--name-only", "--diff-filter=A", "develop...HEAD")
    return path in names


def load_ledger(ledger_path: Path) -> dict[str, dict[str, Any]]:
    if not ledger_path.is_file():
        return {}
    rows: dict[str, dict[str, Any]] = {}
    for ln in ledger_path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = LEDGER_ROW_RE.match(ln)
        if not m:
            continue
        notes = m.group("notes")
        sha_m = re.search(r"sha:([0-9a-f+]+)", notes)
        rows[m.group("file")] = {
            "file_raw": parse_pct(m.group("raw")),
            "in_scope": m.group("inscope"),
            "notes": notes,
            "sha": f"sha:{sha_m.group(1)}" if sha_m else None,
            "done": m.group("inscope").strip() in {"100%", "n/a"},
        }
    return rows


def ledger_sha(api_main: Path, path: str, sha_bin: Path) -> str:
    cp = run([str(sha_bin), str(api_main), path], check=False)
    if cp.returncode != 0:
        return ""
    return cp.stdout.strip()


def map_via_tests(api_main: Path, app_files: list[str], change_tests: list[str]) -> dict[str, list[str]]:
    """Map each app file to one or more Via tests (prefer change-set tests)."""
    mapping: dict[str, list[str]] = {}
    # Index tests by basename mentions / use FQCN
    test_texts: dict[str, str] = {}
    search_roots = list(dict.fromkeys(change_tests))
    # Always allow searching a shallow set under tests/ for fallback
    if not search_roots:
        for p in (api_main / "tests").rglob("*Test.php"):
            rel = str(p.relative_to(api_main))
            search_roots.append(rel)
            if len(search_roots) > 400:
                break

    for t in search_roots:
        fp = api_main / t
        if fp.is_file():
            test_texts[t] = fp.read_text(encoding="utf-8", errors="replace")

    for app in app_files:
        fqcn = resolve_fqcn(api_main, app)
        base = Path(app).stem
        hits: list[str] = []
        # Prefer change-set tests
        for t in change_tests:
            body = test_texts.get(t, "")
            if fqcn in body or base in body or Path(t).stem.replace("Test", "") in base:
                hits.append(t)
        if not hits:
            for t, body in test_texts.items():
                if t in change_tests:
                    continue
                if f"use {fqcn}" in body or fqcn in body:
                    hits.append(t)
                    if len(hits) >= 3:
                        break
        mapping[app] = hits
    return mapping


def parse_pest_coverage(text: str) -> dict[str, dict[str, Any]]:
    """Parse Pest --coverage terminal table into path/FQCN → metrics."""
    by_key: dict[str, dict[str, Any]] = {}

    for m in PEST_FILE_LINE_RE.finditer(text):
        key = m.group("path").strip()
        uncovered_n = int(m.group("uncovered"))
        pct = float(m.group("pct"))
        by_key[key] = {
            "file_raw_pct": pct,
            "uncovered_count": uncovered_n,
            "uncovered_lines": [],
        }

    # Uncovered line blocks (best-effort)
    for m in UNCOVERED_BLOCK_RE.finditer(text):
        key = m.group("header").strip()
        body = m.group("body")
        nums = parse_uncovered_list(body.replace("\n", " "))
        if key not in by_key:
            by_key[key] = {"file_raw_pct": None, "uncovered_count": len(nums), "uncovered_lines": nums}
        else:
            by_key[key]["uncovered_lines"] = nums

    return by_key


def lookup_coverage(
    cov: dict[str, dict[str, Any]], path: str, fqcn: str
) -> dict[str, Any] | None:
    if path in cov:
        return cov[path]
    if fqcn in cov:
        return cov[fqcn]
    # Pest sometimes prints truncated path after App\
    short = path[len("app/") :] if path.startswith("app/") else path
    for k, v in cov.items():
        if k.endswith(short) or k.endswith(fqcn.split("\\")[-1]):
            return v
    return None


def score_file(
    *,
    api_main: Path,
    path: str,
    hunks: set[int],
    via: list[str],
    cov_row: dict[str, Any] | None,
    ledger_row: dict[str, Any] | None,
    sha: str,
    new_file: bool,
) -> FileResult:
    fqcn = resolve_fqcn(api_main, path)
    if not via:
        return FileResult(
            file=path,
            fqcn=fqcn,
            status="no_related_test",
            band="new" if new_file else "large",
            in_scope_pct=None,
            in_scope_uncovered=[],
            file_raw_pct=None,
            prev_file_raw_pct=(ledger_row or {}).get("file_raw"),
            ratchet_target_pct=None,
            via_tests=[],
            sha=sha,
            agent_action=f"Create or point a Via *Test.php that boots {fqcn}, then re-run Coverage in the manager.",
            notes="no related test",
        )

    raw = None if not cov_row else cov_row.get("file_raw_pct")
    uncovered = list((cov_row or {}).get("uncovered_lines") or [])
    uncovered_n = (cov_row or {}).get("uncovered_count")
    if raw is not None and uncovered_n is not None and raw < 100 and not uncovered:
        # Lines unknown — treat entire hunk as needing attention if report silent
        pass

    # Executable estimate from Pest: uncovered_count and raw %
    executable = None
    if raw is not None and uncovered_n is not None:
        if raw >= 100:
            executable = max(0, int(round(uncovered_n / 0.001))) if uncovered_n else None
            # When 100%, uncovered_n is 0; estimate from covered only unknown — leave None
            if uncovered_n == 0:
                executable = None
        elif raw > 0:
            # uncovered = total * (1 - raw/100)
            frac = 1.0 - (raw / 100.0)
            if frac > 0:
                executable = int(round(uncovered_n / frac))

    if new_file:
        band = "new"
        # whole file in-scope
        in_scope_lines = set(uncovered)  # unknown exec set; use uncovered ∩ all
        # If we have no uncovered list, require raw 100
        in_scope_uncovered = uncovered[:]
    else:
        if not hunks:
            # comment-only / no executable added lines detected
            in_scope_uncovered = []
            in_scope_pct = 100.0
        else:
            if uncovered:
                in_scope_uncovered = sorted(set(uncovered) & hunks)
            else:
                # No line list from Pest — if raw missing or 0 and hunks exist, flag hunks
                if cov_row is None or (raw is not None and raw == 0.0):
                    in_scope_uncovered = sorted(hunks)
                else:
                    in_scope_uncovered = []
        band = "small" if (executable is not None and executable <= SMALL_EXECUTABLE_MAX) else "large"
        if executable is None:
            # Heuristic: count non-empty non-comment lines in hunks as proxy
            band = "small" if len(hunks) <= SMALL_EXECUTABLE_MAX else "large"

    if new_file:
        in_scope_pct = 100.0 if (raw is not None and raw >= 100.0) else (
            0.0 if in_scope_uncovered else 100.0
        )
        if raw is not None and raw < 100.0 and not in_scope_uncovered and uncovered:
            in_scope_uncovered = uncovered[:]
            in_scope_pct = raw
    elif not hunks:
        in_scope_pct = 100.0
        in_scope_uncovered = []
    else:
        # Without full executable-in-hunk set, treat uncovered∩hunk empty as 100%
        in_scope_pct = 100.0 if not in_scope_uncovered else (
            100.0 * (1.0 - len(in_scope_uncovered) / max(len(hunks), 1))
        )

    prev = (ledger_row or {}).get("file_raw")
    ratchet_target = None
    if band == "large" and prev is not None:
        ratchet_target = min(100.0, round(prev + 1.0, 1))

    notes_parts = [fqcn, f"band={band}"]
    if hunks:
        notes_parts.append("hunks " + ",".join(compact_lines(sorted(hunks))))
    else:
        notes_parts.append("no executable in-scope lines" if not new_file else "new file")

    status = "pass"
    agent_action = None

    if in_scope_pct < 100.0 - 1e-9:
        status = "fail"
        agent_action = (
            f"Cover in-scope lines {', '.join(compact_lines(in_scope_uncovered)) or '(unknown)'} "
            f"via {', '.join(via)} (do not change production only for coverage)."
        )
    elif band in {"new", "small"} and (raw is None or raw < 100.0 - 1e-9):
        status = "fail"
        agent_action = (
            f"{band} file requires File raw 100% (now {format_pct(raw)}); "
            f"tighten {', '.join(via)}."
        )
    elif band == "large" and ratchet_target is not None and (raw is None or raw + 1e-9 < ratchet_target):
        status = "fail"
        agent_action = (
            f"Large-file ratchet: File raw {format_pct(raw)} < target {format_pct(ratchet_target)} "
            f"(prev {format_pct(prev)}); cover cheap out-of-scope branches in the same file via "
            f"{', '.join(via)}."
        )
    elif cov_row is None:
        status = "fail"
        agent_action = (
            f"Via {', '.join(via)} did not report coverage for {fqcn}; "
            "make the test boot this class, then re-run Coverage."
        )

    if status == "pass" and not hunks and not new_file:
        notes_parts.append("no executable in-scope lines")
    if ratchet_target is not None:
        notes_parts.append(f"ratchet {format_pct(prev)}→≥{format_pct(ratchet_target)}")

    return FileResult(
        file=path,
        fqcn=fqcn,
        status=status,
        band=band,
        in_scope_pct=round(in_scope_pct, 1) if in_scope_pct is not None else None,
        in_scope_uncovered=compact_lines(in_scope_uncovered),
        file_raw_pct=raw,
        prev_file_raw_pct=prev,
        ratchet_target_pct=ratchet_target,
        via_tests=via,
        sha=sha,
        agent_action=agent_action,
        notes="; ".join(notes_parts),
        executable_lines=executable,
    )


def render_md(artifact: Artifact) -> str:
    lines = [
        f"# Coverage report — {artifact.project} / {artifact.code}",
        "",
        f"- measured_at: `{artifact.measured_at}`",
        f"- tip: `{artifact.tip}`",
        f"- status: **{artifact.status}**",
        f"- summary: `{json.dumps(artifact.summary)}`",
        "",
        "| File | Status | In-scope | Uncovered | File raw | Band | Agent action |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for f in artifact.files:
        unc = ", ".join(f.get("in_scope_uncovered") or []) or "—"
        action = f.get("agent_action") or "—"
        lines.append(
            "| `{file}` | `{status}` | `{ins}` | `{unc}` | `{raw}` | `{band}` | {action} |".format(
                file=f["file"],
                status=f["status"],
                ins=format_pct(f.get("in_scope_pct")),
                unc=unc,
                raw=format_pct(f.get("file_raw_pct")),
                band=f.get("band") or "—",
                action=action.replace("|", "/"),
            )
        )
    lines.append("")
    lines.append("Gates and ledger: `olie/prompts/coverage-testing.md` / `coverage-ledger.md`.")
    lines.append("Contract: `lib/coverage/ARTIFACT.md`.")
    lines.append("")
    return "\n".join(lines)


def update_ledger_rows(ledger_path: Path, results: list[FileResult], code: str, when: str) -> None:
    """Upsert pass rows into coverage-ledger.md."""
    if not ledger_path.is_file():
        return
    text = ledger_path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines(keepends=True)
    by_file = {r.file: r for r in results if r.status == "pass"}
    if not by_file:
        return

    def row_for(r: FileResult) -> str:
        unc = ", ".join(r.in_scope_uncovered) if r.in_scope_uncovered else "—"
        via = ", ".join(f"`{v}`" for v in r.via_tests) if r.via_tests else "`—`"
        # via column in ledger is plain paths historically
        via_plain = ", ".join(r.via_tests) if r.via_tests else "—"
        notes = f"{code}. {r.notes}. {r.sha}."
        return (
            f"| `{r.file}` | `{when}` | `{format_pct(r.in_scope_pct)}` | `{unc}` | "
            f"`{format_pct(r.file_raw_pct)}` | `{via_plain}` | {notes} |\n"
        )

    seen: set[str] = set()
    out: list[str] = []
    for ln in lines:
        m = LEDGER_ROW_RE.match(ln.rstrip("\n"))
        if m and m.group("file") in by_file:
            r = by_file[m.group("file")]
            out.append(row_for(r))
            seen.add(r.file)
        else:
            out.append(ln if ln.endswith("\n") else ln + "\n")

    # Append new pass rows before EOF
    for path, r in by_file.items():
        if path not in seen:
            out.append(row_for(r))

    ledger_path.write_text("".join(out), encoding="utf-8")


def write_plan(
    *,
    api_main: Path,
    code: str,
    ledger_path: Path,
    sha_bin: Path,
    out_path: Path,
) -> dict[str, Any]:
    all_paths, hunks = change_set_paths(api_main, code)
    app_files = [p for p in all_paths if p.startswith("app/")]
    change_tests = [p for p in all_paths if p.startswith("tests/") and p.endswith("Test.php")]
    ledger = load_ledger(ledger_path)
    via_map = map_via_tests(api_main, app_files, change_tests)

    remaining: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    for path in app_files:
        sha = ledger_sha(api_main, path, sha_bin)
        row = ledger.get(path)
        if row and row.get("done") and row.get("sha") and sha and row["sha"] == sha:
            skipped.append({"file": path, "sha": sha, "status": "skip_sha"})
            continue
        remaining.append(
            {
                "file": path,
                "fqcn": resolve_fqcn(api_main, path),
                "via_tests": via_map.get(path) or [],
                "hunks": sorted(hunks.get(path) or []),
                "new_file": is_new_file(api_main, path),
                "sha": sha,
                "prev_file_raw_pct": (row or {}).get("file_raw"),
            }
        )

    # Batches by frozenset of via tests (empty via → own batch)
    batches: dict[str, list[dict[str, Any]]] = {}
    for item in remaining:
        key = ",".join(item["via_tests"]) if item["via_tests"] else f"__none__:{item['file']}"
        batches.setdefault(key, []).append(item)

    plan = {
        "api_main": str(api_main),
        "code": code,
        "app_files": app_files,
        "change_tests": change_tests,
        "skipped_sha": skipped,
        "batches": [
            {"via_tests": (b[0]["via_tests"] if b else []), "files": b}
            for b in batches.values()
        ],
    }
    out_path.write_text(json.dumps(plan, indent=2) + "\n", encoding="utf-8")
    return plan


def write_artifact_from_runs(
    *,
    project: str,
    code: str,
    api_main: Path,
    ledger_path: Path,
    sha_bin: Path,
    plan: dict[str, Any],
    pest_outputs: dict[str, str],
    out_dir: Path,
    update_ledger: bool,
) -> Artifact:
    tip = run(["git", "-C", str(api_main), "rev-parse", "--short=12", "HEAD"], check=False).stdout.strip()
    when = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M %Z")
    measured_at = datetime.now().astimezone().isoformat(timespec="seconds")
    ledger = load_ledger(ledger_path)

    # Merge all pest outputs
    merged_cov: dict[str, dict[str, Any]] = {}
    for text in pest_outputs.values():
        merged_cov.update(parse_pest_coverage(text))

    results: list[FileResult] = []
    for skip in plan.get("skipped_sha") or []:
        results.append(
            FileResult(
                file=skip["file"],
                fqcn=resolve_fqcn(api_main, skip["file"]),
                status="skip_sha",
                band="large",
                in_scope_pct=100.0,
                in_scope_uncovered=[],
                file_raw_pct=(ledger.get(skip["file"]) or {}).get("file_raw"),
                prev_file_raw_pct=(ledger.get(skip["file"]) or {}).get("file_raw"),
                ratchet_target_pct=None,
                via_tests=[],
                sha=skip.get("sha") or "",
                agent_action=None,
                notes="skip: ledger sha matches",
            )
        )

    for batch in plan.get("batches") or []:
        for item in batch.get("files") or []:
            path = item["file"]
            fqcn = item["fqcn"]
            cov = lookup_coverage(merged_cov, path, fqcn)
            results.append(
                score_file(
                    api_main=api_main,
                    path=path,
                    hunks=set(item.get("hunks") or []),
                    via=list(item.get("via_tests") or []),
                    cov_row=cov,
                    ledger_row=ledger.get(path),
                    sha=item.get("sha") or ledger_sha(api_main, path, sha_bin),
                    new_file=bool(item.get("new_file")),
                )
            )

    summary = {
        "passed": sum(1 for r in results if r.status == "pass"),
        "failed": sum(1 for r in results if r.status == "fail"),
        "skipped_sha": sum(1 for r in results if r.status == "skip_sha"),
        "blocked": sum(1 for r in results if r.status == "blocked"),
        "no_related_test": sum(1 for r in results if r.status == "no_related_test"),
    }

    if not plan.get("app_files") and not plan.get("skipped_sha"):
        status = "empty"
    elif summary["failed"] or summary["blocked"] or summary["no_related_test"]:
        status = "needs_work"
    else:
        status = "pass"

    artifact = Artifact(
        version=ARTIFACT_VERSION,
        project=project,
        code=code,
        measured_at=measured_at,
        api_main=str(api_main),
        tip=tip,
        status=status,
        summary=summary,
        files=[asdict(r) for r in results],
        logs={"pest_dir": str(out_dir / "pest")},
    )

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "latest.json").write_text(json.dumps(asdict(artifact), indent=2) + "\n", encoding="utf-8")
    (out_dir / "latest.md").write_text(render_md(artifact), encoding="utf-8")

    # Also stamp immutable run copy when out_dir is the card coverage root's timestamp child
    if update_ledger:
        update_ledger_rows(ledger_path, results, code, when)

    return artifact


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    plan_p = sub.add_parser("plan", help="Build Via batches + change-set plan JSON")
    plan_p.add_argument("--api-main", required=True)
    plan_p.add_argument("--code", required=True)
    plan_p.add_argument("--ledger", required=True)
    plan_p.add_argument("--sha-bin", required=True)
    plan_p.add_argument("--out", required=True)

    art_p = sub.add_parser("artifact", help="Score pest logs + write latest.json/md")
    art_p.add_argument("--project", required=True)
    art_p.add_argument("--code", required=True)
    art_p.add_argument("--api-main", required=True)
    art_p.add_argument("--ledger", required=True)
    art_p.add_argument("--sha-bin", required=True)
    art_p.add_argument("--plan", required=True)
    art_p.add_argument("--pest-dir", required=True)
    art_p.add_argument("--out-dir", required=True)
    art_p.add_argument("--update-ledger", action="store_true")

    args = p.parse_args(argv)

    if args.cmd == "plan":
        write_plan(
            api_main=Path(args.api_main),
            code=args.code,
            ledger_path=Path(args.ledger),
            sha_bin=Path(args.sha_bin),
            out_path=Path(args.out),
        )
        return 0

    if args.cmd == "artifact":
        plan = json.loads(Path(args.plan).read_text(encoding="utf-8"))
        pest_dir = Path(args.pest_dir)
        pest_outputs: dict[str, str] = {}
        if pest_dir.is_dir():
            for f in sorted(pest_dir.glob("*.log")):
                pest_outputs[f.stem] = f.read_text(encoding="utf-8", errors="replace")
        art = write_artifact_from_runs(
            project=args.project,
            code=args.code,
            api_main=Path(args.api_main),
            ledger_path=Path(args.ledger),
            sha_bin=Path(args.sha_bin),
            plan=plan,
            pest_outputs=pest_outputs,
            out_dir=Path(args.out_dir),
            update_ledger=bool(args.update_ledger),
        )
        print(json.dumps({"status": art.status, "summary": art.summary}))
        return 0 if art.status in {"pass", "empty"} else 1

    return 2


if __name__ == "__main__":
    sys.exit(main())
