# Card Correction Workflow

Fix card `{{ code }}` after review. Read Card Spec + PR feedback → plan → TDD. Shared policy: module index `workflow-policy.md`.

If tooling fails/stalls: stop, offer `resolva` / `documente` / `resolva permanentemente` (`workflow-policy/tools.md`) — treat it as a signal that **this prompt needs updating**. Exception: `olie-flow-ai` `needsAuth` with desktop authenticated → **MCP auth**.

### 0. Host-card + Card Spec

1. Ensure: `~/git/bin/workvm-host-card ensure --project olie --code '{{ code }}'` (`workflow-policy/host.md`). No destroy at end of correction.
2. Spec at `~/git/olie/cards/{{ code }}/` required. Missing → stop; user runs **Card Spec**. Do not MCP-rebuild.
3. Read `project.md`, `media.md`, `notebook/`. Findings + requirements + Caderno are source of truth (inspect code; list is not exhaustive). **Deferred decisions** → stop/ask/recommend (`workflow-policy/card-context.md`).
4. Media analyses: reuse or skill-write under `olie/cards/{CODE}/`; never post to card content; no commit in this pass.

### 1. Stage

If still `changes-requested` → move to `in-progress` (`workflow-policy/board.md`). Already there → continue. Other stage → report and wait. No project execution.

### 2. PR review feedback (before plan)

From Card Spec forms/content, for **each** associated PR load **threads** and **reviews** (GitHub MCP; **Tool preference** in `workflow-policy/tools.md`). Empty threads ≠ no feedback if the review body has blockers. Every actionable thread/body point is a finding.

### 3. Merge conflicts only

Never touch `olie/docs`. If the return is conflicts: fetch/ff `develop`, checkout the **existing** card branch, **start** `git rebase develop`, **do not** resolve markers / continue / abort — leave for the user and **stop**. When they resume: verify rebase finished; do corrections/TDD locally; **`--force-with-lease` last** after verification (never push an unverified tip).

### 4. Branches

Use the card/PR branch in every involved repo (incl. private e2e root — `workflow-policy/host.md`). Preserve dirty work; never invent alternate branch names; never edit `olie/docs`.

### 5. Plan (Plan mode)

`SwitchMode` → **plan**. Document: PRs checked (threads + bodies); each finding + root cause; files; expected behavior; tests; TDD steps; checklist; issues log.

**Scope triage** per item: in-scope / simple (fix here) / out-of-scope (propose card). If **>3 new** findings not in the return → stop and ask before expanding.

**Stop** until `next` (or explicit waive). Re-run budget: only what this correction changed (`workflow-policy/gates.md`).

### 6. TDD + execute

Per fix: Red (failing regression) → Green (minimal) → verify → refactor → recheck → update plan. Observable behavior; no weakened asserts; `pt-br.json` only. Controlled mode: one item per `next`.

reCAPTCHA: **Temporary E2E CAPTCHA** in `workflow-policy/host.md`.

### 7. GitHub close — prepare only

Do **not** Resolve threads or post review-body audit comments in this paste (**Closing PR review feedback** in `workflow-policy/card-context.md`). Draft the audit checklist in the chat report. Public close = `pre-qa.md` Phase B after manager Pre-QA + validations.

### 8. Done

Every finding addressed or documented (non-issue / out-of-scope); checklist verified; report triage + new-finding count + touched paths + tests. **Do not** commit/push/PR hint — next is `implementation-validation.md`. Post `### Evidência — {N}º Correção` now (`workflow-policy/evidence.md`); Pre-QA refreshes the same heading later.
