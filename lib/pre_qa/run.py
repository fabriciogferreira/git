#!/usr/bin/env python3
"""Pre-QA mechanical runner: commitlint, gh PR, checklist, forms, move.

Problema: pre-qa.md misturava UX/docs/evidência com I/O (gh, board). Manager
roda isto; o agente só julga o resto (lib/pre_qa/ARTIFACT.md).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "lib"))

from pre_qa.mgmt import (  # noqa: E402
    get_project_details,
    get_project_http,
    load_mcp_token,
    load_mgmt_token,
    mcp_call,
    move_project_http,
    move_project_mcp,
    toggle_checklist,
)

ARTIFACT_VERSION = 1

PRODUCT_REPOS = (
    "api-main",
    "olie-fronts",
    "backoffice",
    "landing",
    "websocket",
)

QA_STEP_NAMES = ("qa/cr", "qa / cr", "quality-review")
PR_CHECKLIST_NAMES = ("pull request criado", "pull request created")
DOCS_LABEL_HINTS = (
    "documentação do api-main",
    "documentacao do api-main",
    "postman",
    "atualizar a documentação",
)


def run(cmd: list[str], *, cwd: Path | None = None, check: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        check=check,
        capture_output=True,
        text=True,
    )


def norm(s: str) -> str:
    return re.sub(r"\s+", " ", (s or "").strip().lower())


def find_qa_step(project_http: dict[str, Any]) -> dict[str, Any] | None:
    for funnel in project_http.get("funnels") or []:
        for step in funnel.get("steps") or []:
            name = norm(str(step.get("name") or ""))
            if name in QA_STEP_NAMES or name.replace(" ", "") == "qa/cr":
                return step
    # fallback: funnel_steps on MCP payload may lack checklists
    return None


def find_checklist(step: dict[str, Any]) -> dict[str, Any] | None:
    for ch in step.get("checklists") or []:
        if norm(str(ch.get("name") or "")) in PR_CHECKLIST_NAMES:
            return ch
    return None


def branch_from_forms(project: dict[str, Any]) -> str | None:
    for block in project.get("all_forms_answers") or []:
        for ans in block.get("answers") or []:
            if norm(str(ans.get("label") or "")) == "branch":
                val = ans.get("answer")
                if isinstance(val, str) and val.strip():
                    return val.strip()
                if isinstance(val, list) and val:
                    return str(val[0]).strip()
    return None


def assignee_github_hints(project: dict[str, Any]) -> list[str]:
    """Best-effort: env map or empty (gh --assignee may fail → artifact notes)."""
    raw = os.environ.get("WORKVM_PR_ASSIGNEE", "").strip()
    if raw:
        return [x.strip() for x in raw.split(",") if x.strip()]
    # Optional JSON map name→login
    map_path = Path(os.environ.get("WORKVM_GITHUB_LOGIN_MAP", Path.home() / ".config/workvm/github-logins.json"))
    mapping: dict[str, str] = {}
    if map_path.is_file():
        try:
            mapping = json.loads(map_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            mapping = {}
    out: list[str] = []
    for u in project.get("users") or []:
        role = norm(str((u.get("pivot") or {}).get("role") or ""))
        if role and role not in ("assignee", "atribuido", "atribuído", "owner", "executor"):
            # still try all users if map hits
            pass
        name = str(u.get("name") or "")
        email = str(u.get("email") or "")
        login = mapping.get(name) or mapping.get(email) or mapping.get(norm(name))
        if login:
            out.append(login)
    return out


def reviewers_from_env(exclude: list[str]) -> list[str]:
    raw = os.environ.get("WORKVM_PR_REVIEWERS", "").strip()
    if not raw:
        return []
    ex = {x.lower() for x in exclude}
    return [x.strip() for x in raw.split(",") if x.strip() and x.strip().lower() not in ex]


def label_from_branch(branch: str) -> str | None:
    prefix = branch.split("/", 1)[0].lower() if "/" in branch else ""
    # closest labels commonly used
    mapping = {
        "feature": "feature",
        "feat": "feature",
        "fix": "fix",
        "bugfix": "fix",
        "hotfix": "hotfix",
        "chore": "chore",
        "refactor": "refactor",
        "docs": "docs",
        "test": "test",
    }
    return mapping.get(prefix)


def detect_repos(worktree: Path, branch: str) -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    for name in PRODUCT_REPOS:
        path = worktree / name
        if not path.is_dir() or not (path / ".git").exists() and not (path / ".git").is_file():
            # worktree path may be gitfile
            if not (path / ".git").exists():
                continue
        cur = run(["git", "-C", str(path), "branch", "--show-current"]).stdout.strip()
        # also accept detached if HEAD matches branch tip name via describe
        on_branch = cur == branch
        if not on_branch:
            # check if branch exists locally/remotely
            has_local = run(["git", "-C", str(path), "show-ref", "--verify", "--quiet", f"refs/heads/{branch}"]).returncode == 0
            has_remote = run(["git", "-C", str(path), "show-ref", "--verify", "--quiet", f"refs/remotes/origin/{branch}"]).returncode == 0
            if not has_local and not has_remote:
                continue
        remote = run(["git", "-C", str(path), "remote", "get-url", "origin"]).stdout.strip()
        tip = run(["git", "-C", str(path), "rev-parse", "HEAD"]).stdout.strip()
        # dirty vs develop?
        base = "develop"
        if name in ("landing",) and False:
            base = "master"
        ahead = run(["git", "-C", str(path), "rev-list", "--count", f"origin/{base}..HEAD"]).stdout.strip()
        try:
            ahead_n = int(ahead or "0")
        except ValueError:
            ahead_n = 0
        # only include if card branch checked out OR has commits vs develop on that branch
        if not on_branch and ahead_n == 0:
            # switch check: log on branch vs develop
            cnt = run(
                ["git", "-C", str(path), "rev-list", "--count", f"origin/{base}..origin/{branch}"]
            )
            try:
                ahead_n = int(cnt.stdout.strip() or "0")
            except ValueError:
                ahead_n = 0
            if ahead_n == 0 and not on_branch:
                continue
        found.append(
            {
                "name": name,
                "path": str(path),
                "branch": branch,
                "current_branch": cur or "(detached)",
                "on_card_branch": on_branch,
                "remote": remote,
                "tip": tip,
                "base": base,
                "commits_ahead": ahead_n,
            }
        )
    return found


def repo_slug(remote: str) -> str | None:
    # git@github.com:olie-ai/api-main.git / https://github.com/olie-ai/api-main.git
    m = re.search(r"github\.com[:/]([^/]+)/([^/.]+)(?:\.git)?$", remote)
    if not m:
        return None
    return f"{m.group(1)}/{m.group(2)}"


def lint_commits(repo: dict[str, Any]) -> dict[str, Any]:
    path = Path(repo["path"])
    base = repo["base"]
    name = repo["name"]
    # ensure origin/base
    run(["git", "-C", str(path), "fetch", "origin", base, repo["branch"]], check=False)
    base_sha = run(["git", "-C", str(path), "rev-parse", f"origin/{base}"]).stdout.strip()
    head_sha = run(["git", "-C", str(path), "rev-parse", "HEAD"]).stdout.strip()
    if repo["current_branch"] != repo["branch"]:
        # lint the card branch tip if present
        alt = run(["git", "-C", str(path), "rev-parse", f"origin/{repo['branch']}"]
                  if run(["git", "-C", str(path), "show-ref", "--verify", "--quiet", f"refs/remotes/origin/{repo['branch']}"]).returncode == 0
                  else ["git", "-C", str(path), "rev-parse", repo["branch"]])
        if alt.returncode == 0 and alt.stdout.strip():
            head_sha = alt.stdout.strip()

    shas = run(
        ["git", "-C", str(path), "log", "--no-merges", "--format=%H", f"{base_sha}..{head_sha}"]
    ).stdout.splitlines()
    result: dict[str, Any] = {
        "base_sha": base_sha,
        "head_sha": head_sha,
        "commit_count": len(shas),
        "ok": True,
        "failures": [],
        "tool": None,
    }
    if not shas:
        result["ok"] = True
        result["tool"] = "none"
        result["note"] = "no non-merge commits in range"
        return result

    if name == "api-main":
        result["tool"] = "captainhook"
        hook = ROOT / "bin" / "workvm-host-card-captainhook"
        for sha in shas:
            msg = run(["git", "-C", str(path), "log", "-1", "--format=%B", sha]).stdout
            msg_file = Path(f"/tmp/workvm-pre-qa-msg-{sha[:12]}")
            msg_file.write_text(msg, encoding="utf-8")
            env = os.environ.copy()
            # help captainhook find the app container from worktree
            env["WORKVM_HOST_CARD_API_MAIN"] = str(path)
            cp = subprocess.run(
                [str(hook), "commit-msg", str(msg_file)],
                capture_output=True,
                text=True,
                env=env,
            )
            msg_file.unlink(missing_ok=True)
            if cp.returncode != 0:
                result["ok"] = False
                result["failures"].append(
                    {
                        "sha": sha[:12],
                        "subject": msg.splitlines()[0] if msg else "",
                        "stderr": (cp.stderr or cp.stdout or "")[:500],
                    }
                )
        return result

    if name == "olie-fronts":
        result["tool"] = "commitlint"
        # Prefer host node_modules
        commitlint = path / "node_modules" / ".bin" / "commitlint"
        if commitlint.is_file():
            cp = run(
                [str(commitlint), "--from", base_sha, "--to", head_sha, "--verbose"],
                cwd=path,
            )
        else:
            # docker fallback if container exists
            cp = run(
                [
                    "docker",
                    "container",
                    "exec",
                    "-i",
                    "olie-front-management",
                    "yarn",
                    "commitlint",
                    "--from",
                    base_sha,
                    "--to",
                    head_sha,
                    "--verbose",
                ]
            )
        if cp.returncode != 0:
            result["ok"] = False
            result["failures"].append({"stderr": (cp.stderr or cp.stdout or "")[:800]})
        return result

    result["tool"] = "hard-rules-only"
    result["note"] = "no repo commit linter wired; apply conventional hard rules in agent review"
    return result


def existing_pr(slug: str, branch: str) -> dict[str, Any] | None:
    cp = run(
        [
            "gh",
            "pr",
            "list",
            "--repo",
            slug,
            "--head",
            branch,
            "--json",
            "number,url,title,baseRefName,state",
            "--limit",
            "5",
        ]
    )
    if cp.returncode != 0:
        return None
    try:
        items = json.loads(cp.stdout or "[]")
    except json.JSONDecodeError:
        return None
    for it in items:
        if it.get("state") == "OPEN" or True:
            return it
    return None


def create_or_edit_pr(
    repo: dict[str, Any],
    *,
    code: str,
    assignees: list[str],
    reviewers: list[str],
    dry_run: bool,
) -> dict[str, Any]:
    slug = repo_slug(repo["remote"] or "")
    out: dict[str, Any] = {"repo": repo["name"], "slug": slug, "branch": repo["branch"]}
    if not slug:
        out["status"] = "error"
        out["error"] = "cannot parse github slug from remote"
        return out

    # push branch
    if not dry_run:
        push = run(
            ["git", "-C", repo["path"], "push", "-u", "origin", f"HEAD:{repo['branch']}"],
        )
        out["push_exit"] = push.returncode
        if push.returncode != 0:
            # try push from branch ref
            push2 = run(
                ["git", "-C", repo["path"], "push", "-u", "origin", repo["branch"]],
            )
            out["push_exit"] = push2.returncode
            out["push_stderr"] = (push2.stderr or push.stderr or "")[:400]
            if push2.returncode != 0:
                out["status"] = "needs_work"
                out["error"] = "git push failed"
                return out

    existing = existing_pr(slug, repo["branch"])
    label = label_from_branch(repo["branch"])
    title = f"{code}: {repo['name']} handoff"
    body = f"Card `{code}`.\n\nAutomated pre-QA handoff for `{repo['name']}` (`{repo['branch']}` → `{repo['base']}`)."

    if existing:
        out["status"] = "exists"
        out["number"] = existing.get("number")
        out["url"] = existing.get("url")
        if dry_run:
            out["edit_planned"] = True
            return out
        edit_cmd = ["gh", "pr", "edit", str(existing["number"]), "--repo", slug]
        for a in assignees:
            edit_cmd.extend(["--add-assignee", a])
        for r in reviewers:
            edit_cmd.extend(["--add-reviewer", r])
        if label:
            edit_cmd.extend(["--add-label", label])
        if len(edit_cmd) > 5:
            cp = run(edit_cmd)
            out["edit_exit"] = cp.returncode
            if cp.returncode != 0:
                out["edit_stderr"] = (cp.stderr or "")[:400]
        return out

    if dry_run:
        out["status"] = "would_create"
        out["title"] = title
        out["label"] = label
        out["assignees"] = assignees
        out["reviewers"] = reviewers
        return out

    cmd = [
        "gh",
        "pr",
        "create",
        "--repo",
        slug,
        "--base",
        repo["base"],
        "--head",
        repo["branch"],
        "--title",
        title,
        "--body",
        body,
    ]
    for a in assignees:
        cmd.extend(["--assignee", a])
    if reviewers:
        cmd.append("--reviewer")
        cmd.append(",".join(reviewers))
    if label:
        cmd.extend(["--label", label])
    cp = run(cmd)
    out["create_exit"] = cp.returncode
    out["stdout"] = (cp.stdout or "").strip()
    out["stderr"] = (cp.stderr or "")[:500]
    if cp.returncode != 0:
        out["status"] = "needs_work"
        out["error"] = "gh pr create failed"
        return out
    out["status"] = "created"
    out["url"] = out["stdout"].splitlines()[-1] if out["stdout"] else None
    # re-list for number
    again = existing_pr(slug, repo["branch"])
    if again:
        out["number"] = again.get("number")
        out["url"] = again.get("url") or out["url"]
    return out


def write_docs_form(
    mcp_token: str,
    project_id: str,
    qa_step_id: int,
    docs: str,
    *,
    dry_run: bool,
) -> dict[str, Any]:
    out: dict[str, Any] = {"docs": docs}
    if docs not in ("sim", "nao"):
        out["status"] = "skipped"
        out["reason"] = "pass --docs sim|nao"
        return out
    answer = "Sim" if docs == "sim" else "Não"
    forms = mcp_call(
        mcp_token,
        "get-model-dynamic-forms-tool",
        {"model": "project", "model_id": project_id},
    )
    groups = (forms.get("forms") or forms) if isinstance(forms, dict) else {}
    targets = groups.get("forms_from_project_funnel_steps") or []
    target = None
    for t in targets:
        if int(t.get("funnel_step_id") or 0) == int(qa_step_id) and int(t.get("form_id") or 0) == 762:
            target = t
            break
    if target is None:
        # any step form whose get-form has docs label
        for t in targets:
            if int(t.get("funnel_step_id") or 0) == int(qa_step_id):
                target = t
                break
    if target is None:
        out["status"] = "error"
        out["error"] = "docs form target not found on QA/CR step"
        return out

    answers = mcp_call(mcp_token, "get-form-answers-tool", {"target": target})
    field_id = None
    entries = answers.get("answers") or answers.get("form_answers") or answers
    if isinstance(entries, dict):
        entries = entries.get("answers") or []
    for a in entries or []:
        label = norm(str(a.get("label") or ""))
        if any(h in label for h in DOCS_LABEL_HINTS):
            field_id = a.get("id")
            break
    if field_id is None:
        # known field from live funnel
        field_id = 4163
        out["field_fallback"] = True
    out["field_id"] = field_id
    out["target_form_id"] = target.get("form_id")
    if dry_run:
        out["status"] = "would_set"
        out["answer"] = answer
        return out
    res = mcp_call(
        mcp_token,
        "set-form-answers-tool",
        {"target": target, "form_answers": [{"id": int(field_id), "answer": answer}]},
    )
    out["status"] = "set"
    out["result_message"] = (res.get("message") if isinstance(res, dict) else str(res))[:300]
    return out


def write_pr_urls_form(
    mcp_token: str,
    project: dict[str, Any],
    project_id: str,
    prs: list[dict[str, Any]],
    *,
    dry_run: bool,
) -> dict[str, Any]:
    """Write 'Pull Requests por repositório' when field exists (JSON map)."""
    out: dict[str, Any] = {}
    urls_by_repo: dict[str, list[str]] = {}
    for p in prs:
        if p.get("url") and p.get("repo"):
            urls_by_repo.setdefault(p["repo"], []).append(p["url"])
    if not urls_by_repo:
        out["status"] = "skipped"
        out["reason"] = "no PR urls"
        return out

    # Find field in all_forms_answers
    field_id = None
    current: Any = None
    for block in project.get("all_forms_answers") or []:
        for ans in block.get("answers") or []:
            label = norm(str(ans.get("label") or ""))
            if "pull request" in label and "reposit" in label:
                field_id = ans.get("id")
                current = ans.get("answer")
                break
    if field_id is None:
        out["status"] = "skipped"
        out["reason"] = "no PR-by-repo form field; agent may append to description"
        out["urls"] = urls_by_repo
        return out

    payload: dict[str, Any] = {}
    if isinstance(current, str):
        try:
            payload = json.loads(current)
        except json.JSONDecodeError:
            payload = {}
    elif isinstance(current, dict):
        payload = dict(current)
    for repo, urls in urls_by_repo.items():
        entry = payload.get(repo) if isinstance(payload.get(repo), dict) else {}
        existing = list(entry.get("prs") or [])
        for u in urls:
            if u not in existing:
                existing.append(u)
        payload[repo] = {"prs": existing}

    forms = mcp_call(
        mcp_token,
        "get-model-dynamic-forms-tool",
        {"model": "project", "model_id": project_id},
    )
    groups = (forms.get("forms") or forms) if isinstance(forms, dict) else {}
    target = None
    for t in groups.get("forms_from_project_funnel_steps") or []:
        if int(t.get("form_id") or 0) == 394:
            target = t
            break
    if target is None:
        out["status"] = "error"
        out["error"] = "repo form target (394) not found"
        out["payload"] = payload
        return out

    out["field_id"] = field_id
    out["payload"] = payload
    if dry_run:
        out["status"] = "would_set"
        return out
    # link fields want JSON-encoded array sometimes; this field stores object JSON string
    res = mcp_call(
        mcp_token,
        "set-form-answers-tool",
        {
            "target": target,
            "form_answers": [{"id": int(field_id), "answer": json.dumps(payload, ensure_ascii=False)}],
        },
    )
    out["status"] = "set"
    out["result_message"] = (res.get("message") if isinstance(res, dict) else str(res))[:300]
    return out


def read_gate(data_dir: Path, kind: str, project: str, code: str) -> dict[str, Any]:
    safe = re.sub(r"[^a-z0-9._-]+", "_", code.lower())
    path = data_dir / kind / project / safe / "latest.json"
    if not path.is_file():
        return {"status": "missing", "path": str(path)}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {"status": "error", "path": str(path)}
    return {"status": data.get("status"), "path": str(path), "measured_at": data.get("measured_at")}


def write_artifact(out_dir: Path, data: dict[str, Any]) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "latest.json").write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    lines = [
        f"# Pre-QA — {data.get('code')}",
        "",
        f"- status: `{data.get('status')}`",
        f"- dry_run: `{data.get('dry_run')}`",
        f"- docs_update: `{data.get('docs_update')}`",
        f"- measured_at: {data.get('measured_at')}",
        "",
        "## Gates",
        "",
    ]
    for k, v in (data.get("gates") or {}).items():
        lines.append(f"- **{k}:** `{v.get('status')}` ({v.get('path')})")
    lines.extend(["", "## Repos / PRs", ""])
    for r in data.get("repos") or []:
        lint = r.get("commitlint") or {}
        pr = r.get("pr") or {}
        lines.append(
            f"- `{r.get('name')}` branch `{r.get('branch')}` lint=`{lint.get('ok')}` "
            f"pr=`{pr.get('status')}` {pr.get('url') or ''}"
        )
    lines.extend(["", "## Checklist / forms / move", ""])
    lines.append(f"- checklist: `{json.dumps(data.get('checklist'), ensure_ascii=False)[:200]}`")
    lines.append(f"- forms.docs: `{json.dumps(data.get('forms', {}).get('docs'), ensure_ascii=False)[:200]}`")
    lines.append(f"- forms.prs: `{json.dumps(data.get('forms', {}).get('prs'), ensure_ascii=False)[:200]}`")
    lines.append(f"- move: `{json.dumps(data.get('move'), ensure_ascii=False)[:300]}`")
    lines.extend(["", "## Agent actions", ""])
    for a in data.get("agent_actions") or []:
        lines.append(f"- {a}")
    lines.append("")
    (out_dir / "latest.md").write_text("\n".join(lines), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--project", required=True)
    p.add_argument("--code", required=True)
    p.add_argument("--api-worktree", required=True, type=Path)
    p.add_argument("--out-dir", required=True, type=Path)
    p.add_argument("--docs", choices=("sim", "nao", "unknown"), default="unknown")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--skip-pr", action="store_true")
    p.add_argument("--skip-move", action="store_true")
    p.add_argument("--skip-checklist", action="store_true")
    p.add_argument("--skip-commitlint", action="store_true")
    args = p.parse_args(argv)

    code = args.code.strip().upper()
    data_dir = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "project-card-manager"
    measured_at = datetime.now().isoformat(timespec="seconds")
    agent_actions: list[str] = [
        "Phase 1 UX/code-quality judgment still belongs to the agent (pre-qa.md).",
        "Post Decisões (if any) then Evidência via save-media-tool after handoff.",
        "§5.0 Resolve PR threads / audit comment when returning from Corrigir.",
    ]

    artifact: dict[str, Any] = {
        "version": ARTIFACT_VERSION,
        "project": args.project,
        "code": code,
        "measured_at": measured_at,
        "dry_run": bool(args.dry_run),
        "docs_update": args.docs,
        "status": "error",
        "gates": {},
        "repos": [],
        "checklist": {},
        "forms": {},
        "move": {},
        "agent_actions": agent_actions,
    }

    # Gates (backend)
    for kind in ("pest", "coverage", "mutation", "gap"):
        artifact["gates"][kind] = read_gate(data_dir, kind, args.project, code)

    mcp_token = load_mcp_token()
    mgmt_token = load_mgmt_token()
    project = get_project_details(mcp_token, code)
    project_id = str(project.get("id") or "")
    if not project_id:
        artifact["error"] = "project id missing"
        write_artifact(args.out_dir, artifact)
        return 1
    artifact["project_id"] = project_id

    project_http = get_project_http(mgmt_token, project_id)
    # merge forms from whichever has them
    if not project.get("all_forms_answers") and project_http.get("all_forms_answers"):
        project["all_forms_answers"] = project_http["all_forms_answers"]

    branch = branch_from_forms(project) or branch_from_forms(project_http)
    if not branch:
        # fallback: resolve from api-main worktree current
        api = args.api_worktree / "api-main"
        if api.is_dir():
            branch = run(["git", "-C", str(api), "branch", "--show-current"]).stdout.strip() or None
    artifact["branch"] = branch
    if not branch:
        artifact["status"] = "blocked"
        artifact["error"] = "Branch field missing on card; fill form or checkout card branch"
        agent_actions.append("Fill Branch on the repository form, then re-run Pre-QA.")
        write_artifact(args.out_dir, artifact)
        return 1

    qa_step = find_qa_step(project_http)
    if not qa_step:
        artifact["status"] = "blocked"
        artifact["error"] = "QA/CR step not found on live funnel"
        write_artifact(args.out_dir, artifact)
        return 1
    artifact["qa_step"] = {"id": qa_step.get("id"), "name": qa_step.get("name")}

    # Backend gate soft-check: if api-main in repos and pest missing/red → blocked unless dry-run note
    repos = detect_repos(args.api_worktree, branch)
    has_api = any(r["name"] == "api-main" for r in repos)
    if has_api:
        pest = artifact["gates"].get("pest") or {}
        if pest.get("status") not in ("pass", "empty", "skipped") and pest.get("status") != "missing":
            # missing is common if user hasn't run — warn but allow with agent_action
            pass
        if pest.get("status") in ("needs_work", "fail", "error"):
            artifact["status"] = "blocked"
            artifact["error"] = f"Pest gate is {pest.get('status')}; run manager Pest first"
            write_artifact(args.out_dir, artifact)
            return 1
        if pest.get("status") == "missing":
            agent_actions.append("Manager Pest artifact missing — run Pest before claiming handoff complete.")

    assignees = assignee_github_hints(project)
    reviewers = reviewers_from_env(assignees)
    if not assignees:
        agent_actions.append(
            "Set WORKVM_PR_ASSIGNEE or ~/.config/workvm/github-logins.json to map card assignee → GitHub login."
        )
    if not reviewers:
        agent_actions.append(
            "Set WORKVM_PR_REVIEWERS=login1,login2 for automatic reviewer add (optional)."
        )

    pr_results: list[dict[str, Any]] = []
    for repo in repos:
        entry = dict(repo)
        if args.skip_commitlint:
            entry["commitlint"] = {"ok": True, "skipped": True}
        else:
            entry["commitlint"] = lint_commits(repo)
        if args.skip_pr:
            entry["pr"] = {"status": "skipped"}
        elif not entry["commitlint"].get("ok"):
            entry["pr"] = {"status": "blocked", "reason": "commitlint failed"}
            agent_actions.append(
                f"Fix commit messages on {repo['name']} ({len(entry['commitlint'].get('failures') or [])} failures), then re-run Pre-QA."
            )
        else:
            entry["pr"] = create_or_edit_pr(
                repo,
                code=code,
                assignees=assignees,
                reviewers=reviewers,
                dry_run=args.dry_run,
            )
            if entry["pr"].get("url"):
                pr_results.append(
                    {"repo": repo["name"], "url": entry["pr"]["url"], "number": entry["pr"].get("number")}
                )
        artifact["repos"].append(entry)

    # Docs form
    artifact["forms"]["docs"] = write_docs_form(
        mcp_token,
        project_id,
        int(qa_step["id"]),
        args.docs,
        dry_run=args.dry_run,
    )
    if args.docs == "unknown":
        agent_actions.append("Re-run with --docs sim|nao after Phase 2 API docs determination.")

    # PR urls on form
    artifact["forms"]["prs"] = write_pr_urls_form(
        mcp_token,
        project,
        project_id,
        pr_results,
        dry_run=args.dry_run,
    )

    # Checklist
    ch = find_checklist(qa_step)
    if args.skip_checklist:
        artifact["checklist"] = {"status": "skipped"}
    elif not ch:
        artifact["checklist"] = {"status": "error", "error": "Pull Request criado checklist missing"}
    elif args.dry_run:
        artifact["checklist"] = {
            "status": "would_toggle",
            "id": ch.get("id"),
            "name": ch.get("name"),
        }
    else:
        try:
            res = toggle_checklist(mgmt_token, project_id, int(ch["id"]))
            artifact["checklist"] = {
                "status": "toggled",
                "id": ch.get("id"),
                "name": ch.get("name"),
                "response": res,
            }
        except Exception as e:  # noqa: BLE001
            artifact["checklist"] = {"status": "error", "error": str(e)[:400]}

    # Move
    if args.skip_move:
        artifact["move"] = {"status": "skipped"}
    elif args.dry_run:
        artifact["move"] = {
            "status": "would_move",
            "step_id": qa_step.get("id"),
            "step_name": qa_step.get("name"),
        }
    else:
        # Prefer HTTP bulk move (mgmt token); MCP as fallback
        try:
            res = move_project_http(mgmt_token, project_id, int(qa_step["id"]))
            artifact["move"] = {
                "status": "moved",
                "via": "http",
                "step_id": qa_step.get("id"),
                "step_name": qa_step.get("name"),
                "response": res if not isinstance(res, dict) else {k: res.get(k) for k in list(res)[:8]},
            }
        except Exception as e_http:  # noqa: BLE001
            try:
                res = move_project_mcp(mcp_token, code, int(qa_step["id"]))
                artifact["move"] = {
                    "status": "moved",
                    "via": "mcp",
                    "step_id": qa_step.get("id"),
                    "step_name": qa_step.get("name"),
                    "response": str(res)[:400],
                }
            except Exception as e_mcp:  # noqa: BLE001
                artifact["move"] = {
                    "status": "error",
                    "error_http": str(e_http)[:300],
                    "error_mcp": str(e_mcp)[:300],
                }
                agent_actions.append(
                    "Move failed (often incoming_restrictions). Ensure --docs was set; fill destination forms; re-run."
                )

        # verify
        try:
            again = get_project_details(mcp_token, code)
            steps = [(s.get("id"), s.get("name")) for s in (again.get("funnel_steps") or [])]
            artifact["move"]["verified_steps"] = steps
            names = {norm(str(n)) for _, n in steps}
            if "qa/cr" in names or any("qa" in n and "cr" in n for n in names):
                artifact["move"]["verified"] = True
            else:
                artifact["move"]["verified"] = False
                agent_actions.append(f"Card not on QA/CR after move; current steps={steps}")
        except Exception as e:  # noqa: BLE001
            artifact["move"]["verify_error"] = str(e)[:200]

    # Final status
    lint_ok = all((r.get("commitlint") or {}).get("ok", True) for r in artifact["repos"]) or not artifact["repos"]
    pr_bad = any(
        (r.get("pr") or {}).get("status") in ("needs_work", "error", "blocked") for r in artifact["repos"]
    )
    move_ok = args.skip_move or args.dry_run or artifact.get("move", {}).get("status") == "moved"
    ch_ok = args.skip_checklist or args.dry_run or artifact.get("checklist", {}).get("status") in (
        "toggled",
        "would_toggle",
    )

    if not lint_ok or pr_bad:
        artifact["status"] = "needs_work"
    elif not move_ok or not ch_ok:
        artifact["status"] = "needs_work"
    elif args.dry_run:
        artifact["status"] = "pass"  # plan ok
        artifact["note"] = "dry-run plan only; re-run without --dry-run to apply"
    else:
        artifact["status"] = "pass"

    artifact["agent_actions"] = agent_actions
    write_artifact(args.out_dir, artifact)
    print(json.dumps({"status": artifact["status"], "out": str(args.out_dir / "latest.json")}))
    return 0 if artifact["status"] in ("pass",) or args.dry_run else 1


if __name__ == "__main__":
    raise SystemExit(main())
