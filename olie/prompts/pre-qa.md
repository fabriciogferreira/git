# Pre-QA/CR (agent)

Prepare card `{{ code }}` for colleague 'QA/CR'. **You judge** Phase 1–2 (UX/code/docs) and post Decisões/Evidência. **You do not** drive `gh pr create`, checklist toggle, or the board move — the user runs **Pre-QA** in `~/git/manager.sh` for that.

Contract: `~/git/lib/pre_qa/ARTIFACT.md`  
Shared modules: `workflow-policy/board.md` · `card-context.md` · `evidence.md` (index `workflow-policy.md`).

If tooling fails or stalls: stop, report, offer `resolva` / `documente` / `resolva permanentemente` — treat it as a signal that **this prompt needs updating**. Exception: `olie-flow-ai` `needsAuth` with desktop authenticated → **MCP auth** (`workflow-policy/tools.md`).

**Re-run budget:** do not re-walk an unchanged Pre-QA artifact “to confirm”. Shared: **Expensive re-run budget**.

## What the user does

1. Finish Gap → Coverage → Mutation → Pest in the manager when backend changed (artifacts `pass`/`empty`).
2. You complete **Phase A** below (judgment) and state **docs = sim|nao**.
3. Manager → **Pre-QA** → card → docs answer → **Apply** (or Dry-run first).
4. Script: commitlint/CaptainHook, `gh pr create`/`edit`, toggle **Pull Request criado**, set docs/PR forms, move to 'QA/CR' → `latest.json`.
5. You complete **Phase B** (read artifact + evidence).

Default artifact:

```
~/.local/share/project-card-manager/pre-qa/olie/<code-lower>/latest.json
```

Env the user may set once: `WORKVM_PR_ASSIGNEE`, `WORKVM_PR_REVIEWERS`, `WORKVM_GITHUB_LOGIN_MAP` (see `lib/pre_qa/ARTIFACT.md`).

## Phase A — Judgment (agent, before manager Pre-QA)

Use Card Spec dump when present (`olie/cards/{{ code }}/`). Do not MCP-rebuild it.

### A.1 User experience & code quality

Same intent as the old Phase 1 checklist (feedback on requests, no duplicate submit, no stray `console`/debug comments from this card, enums, Bootstrap/PrimeVue dialog sizing, `useLocalStorage`, no unrelated layout/style). **Report** pass/fail per area in chat. Fix in scope when authorized; do not open PRs here.

### A.2 Repo checks (smoke you still own)

- `api-main`: PHPStan / relevant tests / Pint when you changed PHP — prefer host-card containers. Dedicated Pint commit if Pint rewrote files.
- Front management: `docker container exec -i olie-front-management yarn lint` when management changed.
- `olie-fronts`: do not edit `en.json` (pt-br only for new keys).
- Meta-repo dirty for this card (`olie/cards/`, e2e, prompts): note it — Pre-QA script does **not** auto-commit meta; you still commit/push meta per **§4.3** rules in `workflow-policy` / host-card meta path **before or right after** Apply if those paths are required for the handoff.

### A.3 API documentation impact

Decide whether api-main **inputs/outputs** changed. Output exactly: **`docs: sim`** or **`docs: nao`** for the manager Pre-QA docs menu (Postman form on QA/CR).

### A.4 Stop and hand to user

Tell the user to run manager **Pre-QA** with that docs choice (Apply). Do **not** call `gh pr create`, `toggle-funnel-checklist`, or `move-project-to-funnel-step` yourself unless the user explicitly asks you to bypass the manager.

## Phase B — After manager Pre-QA (agent)

1. Open `latest.json` / `latest.md`.
2. If `status` is `blocked` / `needs_work` / `error`: fix what `agent_actions` and `repos[].commitlint` / `pr` say (messages, push, assignees). Tell the user to **re-run Pre-QA**. Do not claim QA/CR ready.
3. If `status` is `pass` (Apply, not only dry-run):
   - Confirm `move.verified` / checklist / PR URLs in the artifact.
   - **§5.0** when returning from Corrigir: Resolve addressed inline threads; audit-comment review bodies (**Closing PR review feedback**). Skip if first handoff with no prior review feedback.
   - Post **Decisões** (if any deferred answers this round) then **Evidência** via `save-media-tool` (**Decisions** in `workflow-policy/card-context.md` / **Evidence** in `workflow-policy/evidence.md`).
4. Final report: repos, lint/commitlint results from artifact, PR URLs, docs sim/nao, checklist, verified stage, §5.0, open `agent_actions`.

## Forbidden (agent) while manager owns Apply

- `gh pr create` / `gh pr edit` as the primary path (manager runs them)
- `toggle-funnel-checklist` / `project-bulk-step-move` / `move-project-to-funnel-step-tool` to finish handoff
- Claiming 'QA/CR' while artifact is dry-run only or `needs_work`

## Chat commands

| Command | Do this |
| --- | --- |
| (user ran Pre-QA / pasted artifact) | Phase B |
| `try again` | After they re-ran Pre-QA: re-read `latest.json` |
| `next prompt` | Only when artifact Apply `pass` and Phase B done — colleague may take 'QA/CR' |

Code quality gates assume `implementation-validation.md` already cleared the five code criteria when this handoff follows implementation.
