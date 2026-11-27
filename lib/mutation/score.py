#!/usr/bin/env python3
"""Mutation change-set scoring + artifact writer for the project-card manager.

Problema: medir pest --mutate no chat gasta tokens. Este módulo planeja
(*Test.php → --class), parseia UNTESTED in-scope e grava latest.json para o
agente só apertar asserts (lib/mutation/ARTIFACT.md).
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
import subprocess
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

ARTIFACT_VERSION = 1

# Reuse coverage change-set helpers (register in sys.modules for dataclasses)
_COV = Path(__file__).resolve().parent.parent / "coverage" / "score.py"
_spec = importlib.util.spec_from_file_location("workvm_coverage_score", _COV)
assert _spec and _spec.loader
_cov = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = _cov
_spec.loader.exec_module(_cov)

change_set_paths = _cov.change_set_paths
resolve_fqcn = _cov.resolve_fqcn
git_lines = _cov.git_lines
run = _cov.run
is_new_file = _cov.is_new_file

USE_IMPORT_RE = re.compile(r"^use\s+(App\\[^;]+);", re.M)
UNTESTED_RE = re.compile(
    r"UNTESTED\s+(?P<path>\S+)\s+>\s+Line\s+(?P<line>\d+):\s+"
    r"(?P<mutator>\S+)\s+-\s+ID:\s+(?P<id>[0-9a-f]+)",
    re.I,
)
SCORE_RE = re.compile(r"Score:\s+(\d+(?:\.\d+)?)\s*%", re.I)
MUTATIONS_CREATED_RE = re.compile(
    r"(\d+)\s+Mutations for\s+(\d+)\s+Files created", re.I
)
NO_MUTATIONS_RE = re.compile(r"No mutations created", re.I)
LEDGER_ROW_RE = re.compile(
    r"^\|\s*`(?P<file>tests/[^`]+)`\s*\|\s*`(?P<result>[^`]*)`\s*\|\s*(?P<notes>.*?)\s*\|$"
)


@dataclass
class FileResult:
    file: str
    status: str
    result: str
    classes: list[dict[str, Any]]
    in_scope_untested: list[dict[str, Any]]
    pest_raw_score: float | None
    sha: str
    agent_action: str | None
    notes: str
    baseline_ok: bool = True


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


def strip_ansi(text: str) -> str:
    return re.sub(r"\x1b\[[0-9;]*m", "", text)


def ledger_sha(api_main: Path, paths: list[str], sha_bin: Path) -> str:
    if not paths:
        return ""
    cp = run([str(sha_bin), str(api_main), *paths], check=False)
    if cp.returncode != 0:
        return ""
    return cp.stdout.strip()


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
        result = m.group("result").strip()
        done = any(tok in result for tok in ("100%", "equivalent"))
        rows[m.group("file")] = {
            "result": result,
            "notes": notes,
            "sha": f"sha:{sha_m.group(1)}" if sha_m else None,
            "done": done,
        }
    return rows


def fqcn_to_path(fqcn: str) -> str:
    if not fqcn.startswith("App\\"):
        return ""
    return "app/" + fqcn[len("App\\") :].replace("\\", "/") + ".php"


def scoped_classes_for_test(
    api_main: Path,
    test_path: str,
    pool: list[tuple[str, str, set[int]]],
) -> list[dict[str, Any]]:
    """Intersect change-set pool with classes the test likely exercises."""
    text = (api_main / test_path).read_text(encoding="utf-8", errors="replace")
    imports = {m.group(1).strip() for m in USE_IMPORT_RE.finditer(text)}
    chosen: list[dict[str, Any]] = []
    for fqcn, path, hunks in pool:
        base = fqcn.rsplit("\\", 1)[-1]
        if fqcn in imports or fqcn in text or base in text:
            chosen.append(
                {
                    "fqcn": fqcn,
                    "path": path,
                    "hunks": sorted(hunks),
                    "new_file": is_new_file(api_main, path),
                }
            )
    # If nothing matched but pool is small, use whole pool (better than empty)
    if not chosen and len(pool) <= 3:
        for fqcn, path, hunks in pool:
            chosen.append(
                {
                    "fqcn": fqcn,
                    "path": path,
                    "hunks": sorted(hunks),
                    "new_file": is_new_file(api_main, path),
                }
            )
    return chosen


def parse_mutate_log(text: str) -> dict[str, Any]:
    clean = strip_ansi(text)
    untested: list[dict[str, Any]] = []
    for m in UNTESTED_RE.finditer(clean):
        path = m.group("path")
        # normalize absolute → repo-relative app/
        if "/app/" in path:
            path = "app/" + path.split("/app/", 1)[1]
        untested.append(
            {
                "path": path,
                "line": int(m.group("line")),
                "mutator": m.group("mutator"),
                "id": m.group("id"),
            }
        )
    score_m = SCORE_RE.search(clean)
    created_m = MUTATIONS_CREATED_RE.search(clean)
    return {
        "untested": untested,
        "score": float(score_m.group(1)) if score_m else None,
        "mutations_created": int(created_m.group(1)) if created_m else None,
        "files_mutated": int(created_m.group(2)) if created_m else None,
        "no_mutations": bool(NO_MUTATIONS_RE.search(clean)),
    }


def in_scope_untested(
    untested: list[dict[str, Any]],
    classes: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    by_path = {c["path"]: c for c in classes}
    by_fqcn_path = {fqcn_to_path(c["fqcn"]): c for c in classes}
    for u in untested:
        path = u["path"]
        meta = by_path.get(path) or by_fqcn_path.get(path)
        if not meta:
            # try basename match
            for c in classes:
                if path.endswith(c["path"]) or c["path"].endswith(path):
                    meta = c
                    break
        if not meta:
            continue
        hunks = set(meta.get("hunks") or [])
        if meta.get("new_file") or not hunks or u["line"] in hunks:
            row = dict(u)
            row["fqcn"] = meta["fqcn"]
            row["path"] = meta["path"]
            out.append(row)
    return out


def write_plan(
    *,
    api_main: Path,
    code: str,
    ledger_path: Path,
    sha_bin: Path,
    out_path: Path,
) -> dict[str, Any]:
    all_paths, hunks = change_set_paths(api_main, code)
    tests = sorted(
        p
        for p in all_paths
        if p.startswith("tests/") and p.endswith("Test.php") and (api_main / p).is_file()
    )
    app_files = sorted(
        p
        for p in all_paths
        if p.startswith("app/") and p.endswith(".php") and (api_main / p).is_file()
    )
    pool: list[tuple[str, str, set[int]]] = []
    for path in app_files:
        fqcn = resolve_fqcn(api_main, path)
        pool.append((fqcn, path, set(hunks.get(path) or [])))

    ledger = load_ledger(ledger_path)
    remaining: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []

    for test in tests:
        classes = scoped_classes_for_test(api_main, test, pool)
        prod_paths = [c["path"] for c in classes]
        sha = ledger_sha(api_main, [test, *prod_paths], sha_bin)
        row = ledger.get(test)
        if row and row.get("done") and row.get("sha") and sha and row["sha"] == sha:
            skipped.append({"file": test, "sha": sha, "status": "skip_sha"})
            continue
        remaining.append(
            {
                "file": test,
                "classes": classes,
                "sha": sha,
                "prev_result": (row or {}).get("result"),
            }
        )

    plan = {
        "api_main": str(api_main),
        "code": code,
        "tests": tests,
        "app_files": app_files,
        "skipped_sha": skipped,
        "remaining": remaining,
    }
    out_path.write_text(json.dumps(plan, indent=2) + "\n", encoding="utf-8")
    return plan


def score_test_file(
    *,
    item: dict[str, Any],
    mutate_logs: dict[str, str],
    baseline_log: str,
) -> FileResult:
    test = item["file"]
    classes = list(item.get("classes") or [])
    sha = item.get("sha") or ""

    if "FAIL" in strip_ansi(baseline_log) and re.search(
        r"\bFAIL\b|FAILED|ErrorException|SQLSTATE", strip_ansi(baseline_log)
    ):
        # Heuristic: artisan/pest failure before mutate
        if re.search(r"Tests:\s+\d+\s+failed", strip_ansi(baseline_log), re.I) or (
            "PASS" not in strip_ansi(baseline_log)
            and "OK" not in strip_ansi(baseline_log)
            and "Tests:" in strip_ansi(baseline_log)
        ):
            return FileResult(
                file=test,
                status="blocked",
                result="—",
                classes=classes,
                in_scope_untested=[],
                pest_raw_score=None,
                sha=sha,
                agent_action=f"Baseline red for {test}; fix the test (or flake) then re-run Mutation.",
                notes="baseline failed",
                baseline_ok=False,
            )

    all_untested: list[dict[str, Any]] = []
    scores: list[float] = []
    any_run = False
    notes_bits: list[str] = []

    if not classes:
        return FileResult(
            file=test,
            status="pass",
            result="100%",
            classes=[],
            in_scope_untested=[],
            pest_raw_score=None,
            sha=sha,
            agent_action=None,
            notes="no scoped --class in change-set pool (nothing to mutate under this test)",
        )

    for c in classes:
        fqcn = c["fqcn"]
        log = mutate_logs.get(fqcn) or mutate_logs.get(fqcn.replace("\\", "_")) or ""
        if not log:
            notes_bits.append(f"{fqcn}: missing mutate log")
            continue
        any_run = True
        parsed = parse_mutate_log(log)
        if parsed["score"] is not None:
            scores.append(parsed["score"])
        if parsed["no_mutations"] or parsed["mutations_created"] == 0:
            notes_bits.append(f"{fqcn}: no mutations")
            continue
        scoped = in_scope_untested(parsed["untested"], [c])
        for s in scoped:
            all_untested.append(s)
        notes_bits.append(
            f"{fqcn}: raw {parsed['score']}% untested_total={len(parsed['untested'])} "
            f"in_scope_untested={len(scoped)}"
        )

    raw = round(sum(scores) / len(scores), 2) if scores else None

    if all_untested:
        ids = ", ".join(f"`{u['id']}` L{u['line']} {u['mutator']}" for u in all_untested[:12])
        more = "" if len(all_untested) <= 12 else f" (+{len(all_untested) - 12} more)"
        return FileResult(
            file=test,
            status="fail",
            result="—",
            classes=classes,
            in_scope_untested=all_untested,
            pest_raw_score=raw,
            sha=sha,
            agent_action=(
                f"Kill in-scope untested mutants in {test} (or accept true equivalents with ids): "
                f"{ids}{more}. Do not change production only for mutation. Then re-run Mutation."
            ),
            notes="; ".join(notes_bits),
            baseline_ok=True,
        )

    if not any_run and classes:
        return FileResult(
            file=test,
            status="blocked",
            result="—",
            classes=classes,
            in_scope_untested=[],
            pest_raw_score=None,
            sha=sha,
            agent_action=f"No mutate logs for {test}; re-run Mutation in the manager.",
            notes="missing logs",
        )

    return FileResult(
        file=test,
        status="pass",
        result="100%",
        classes=classes,
        in_scope_untested=[],
        pest_raw_score=raw,
        sha=sha,
        agent_action=None,
        notes="; ".join(notes_bits) or "in-scope clean",
    )


def render_md(artifact: Artifact) -> str:
    lines = [
        f"# Mutation report — {artifact.project} / {artifact.code}",
        "",
        f"- measured_at: `{artifact.measured_at}`",
        f"- tip: `{artifact.tip}`",
        f"- status: **{artifact.status}**",
        f"- summary: `{json.dumps(artifact.summary)}`",
        "",
        "| Test | Status | Result | In-scope untested | Agent action |",
        "| --- | --- | --- | --- | --- |",
    ]
    for f in artifact.files:
        unt = f.get("in_scope_untested") or []
        unt_s = ", ".join(f"L{u['line']}:{u['mutator']}" for u in unt[:6]) or "—"
        if len(unt) > 6:
            unt_s += f" (+{len(unt) - 6})"
        action = (f.get("agent_action") or "—").replace("|", "/")
        lines.append(
            f"| `{f['file']}` | `{f['status']}` | `{f.get('result') or '—'}` | {unt_s} | {action} |"
        )
    lines += [
        "",
        "Gates: `olie/prompts/mutation-testing.md` / ledger. Contract: `lib/mutation/ARTIFACT.md`.",
        "",
    ]
    return "\n".join(lines)


def update_ledger_rows(ledger_path: Path, results: list[FileResult], code: str) -> None:
    if not ledger_path.is_file():
        return
    by_file = {r.file: r for r in results if r.status == "pass"}
    if not by_file:
        return
    text = ledger_path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines(keepends=True)
    seen: set[str] = set()
    out: list[str] = []

    def row_for(r: FileResult) -> str:
        classes = ", ".join(c["fqcn"].rsplit("\\", 1)[-1] for c in r.classes) or "—"
        notes = f"{code}. `--class` {classes}. {r.notes}. {r.sha}."
        return f"| `{r.file}` | `{r.result}` | {notes} |\n"

    for ln in lines:
        m = LEDGER_ROW_RE.match(ln.rstrip("\n"))
        if m and m.group("file") in by_file:
            r = by_file[m.group("file")]
            out.append(row_for(r))
            seen.add(r.file)
        else:
            out.append(ln if ln.endswith("\n") else ln + "\n")
    for path, r in by_file.items():
        if path not in seen:
            out.append(row_for(r))
    ledger_path.write_text("".join(out), encoding="utf-8")


def write_artifact(
    *,
    project: str,
    code: str,
    api_main: Path,
    ledger_path: Path,
    plan: dict[str, Any],
    run_dir: Path,
    out_dir: Path,
    update_ledger: bool,
) -> Artifact:
    tip = run(
        ["git", "-C", str(api_main), "rev-parse", "--short=12", "HEAD"], check=False
    ).stdout.strip()
    measured_at = datetime.now().astimezone().isoformat(timespec="seconds")
    results: list[FileResult] = []

    for skip in plan.get("skipped_sha") or []:
        results.append(
            FileResult(
                file=skip["file"],
                status="skip_sha",
                result="100%",
                classes=[],
                in_scope_untested=[],
                pest_raw_score=None,
                sha=skip.get("sha") or "",
                agent_action=None,
                notes="skip: ledger sha matches",
            )
        )

    for item in plan.get("remaining") or []:
        test = item["file"]
        safe = re.sub(r"[^A-Za-z0-9._-]+", "_", test)
        baseline = ""
        bpath = run_dir / "baseline" / f"{safe}.log"
        if bpath.is_file():
            baseline = bpath.read_text(encoding="utf-8", errors="replace")
        mutate_logs: dict[str, str] = {}
        mdir = run_dir / "mutate" / safe
        if mdir.is_dir():
            for f in mdir.glob("*.log"):
                # filename is fqcn with _ for \
                fqcn = f.stem.replace("_", "\\")
                mutate_logs[fqcn] = f.read_text(encoding="utf-8", errors="replace")
                mutate_logs[f.stem] = mutate_logs[fqcn]
        results.append(
            score_test_file(item=item, mutate_logs=mutate_logs, baseline_log=baseline)
        )

    summary = {
        "passed": sum(1 for r in results if r.status == "pass"),
        "failed": sum(1 for r in results if r.status == "fail"),
        "skipped_sha": sum(1 for r in results if r.status == "skip_sha"),
        "blocked": sum(1 for r in results if r.status == "blocked"),
    }
    if not plan.get("tests") and not plan.get("skipped_sha"):
        status = "empty"
    elif summary["failed"] or summary["blocked"]:
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
        logs={"mutate_dir": str(run_dir)},
    )
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "latest.json").write_text(
        json.dumps(asdict(artifact), indent=2) + "\n", encoding="utf-8"
    )
    (out_dir / "latest.md").write_text(render_md(artifact), encoding="utf-8")
    if update_ledger:
        update_ledger_rows(ledger_path, results, code)
    return artifact


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    plan_p = sub.add_parser("plan")
    plan_p.add_argument("--api-main", required=True)
    plan_p.add_argument("--code", required=True)
    plan_p.add_argument("--ledger", required=True)
    plan_p.add_argument("--sha-bin", required=True)
    plan_p.add_argument("--out", required=True)

    art_p = sub.add_parser("artifact")
    art_p.add_argument("--project", required=True)
    art_p.add_argument("--code", required=True)
    art_p.add_argument("--api-main", required=True)
    art_p.add_argument("--ledger", required=True)
    art_p.add_argument("--plan", required=True)
    art_p.add_argument("--run-dir", required=True)
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

    plan = json.loads(Path(args.plan).read_text(encoding="utf-8"))
    art = write_artifact(
        project=args.project,
        code=args.code,
        api_main=Path(args.api_main),
        ledger_path=Path(args.ledger),
        plan=plan,
        run_dir=Path(args.run_dir),
        out_dir=Path(args.out_dir),
        update_ledger=bool(args.update_ledger),
    )
    print(json.dumps({"status": art.status, "summary": art.summary}))
    return 0 if art.status in {"pass", "empty"} else 1


if __name__ == "__main__":
    sys.exit(main())
