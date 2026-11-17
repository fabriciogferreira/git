# Test gap analysis

Review card {{ code }}. Compare the card’s requirements with the tests already written for this change set.

This prompt has **exactly two exits**:

1. **No tests to add** — every card-related use case already has automated coverage in the change set.
2. **Tests to add** — a list of missing tests, each with a **title** and a **description** (Brazilian Portuguese; no prompt paths — **Card content vs chat** in `~/git/olie/prompts/workflow-policy.md`).

**Where the list goes** depends on the entry point:

- **Own card (develop handoff)** — chat only. Do **not** write the list into the project/card content. The author closes those gaps in the same handoff before `pre-qa.md` / pull requests.
- **Colleague stack** — Cursor chat / scoreboard only by default. Write into the project/card **only** when **Colleague review outcome** moves to 'Corrigir' for a failure outside gap/mutation/coverage (see **Project content (gap / mutation / coverage)** in `workflow-policy.md`).

Do **not** invent a third exit. Do **not** implement the missing tests in this paste unless the user explicitly asks. Do not run mutation testing here.

Run this **before** `~/git/olie/prompts/coverage-testing.md` when that step applies (own-card order: gap → coverage → mutation → Pest parallel → pre-qa).

Two entry points:

1. **Own card (develop handoff)** — after `~/git/olie/prompts/implementation-validation.md` passes and the change set touched `~/git/olie/api-main` (reached via the `implementation.md` handoff chain). Next paste: `coverage-testing.md`, then `mutation-testing.md`, then `pest-parallel.md`, then `pre-qa.md`. If there is no backend change, skip this prompt. Gaps stay in chat; close them before coverage / PRs.
2. **Colleague card in 'QA/CR'** — after `~/git/olie/prompts/colleague-review.md`, when the change set touched `api-main`, **before** mutation. Leave the card in 'QA/CR' until the remaining stack finishes. Gaps reported here feed the colleague scoreboard; **Colleague review outcome** decides Corrigir vs **reviewer-fix** (gap/mutation/coverage alone do not bounce the author).

Chat commands: `~/git/olie/prompts/workflow-policy.md` → **Chat commands**.

### Chat commands (this prompt)

| Command | Meaning |
| --- | --- |
| `add` | After this pass reported **Tests to add**: leave analysis mode and implement every listed missing test from that report. Then stop and recommend `try again` (re-run this gap analysis). Do not implement during the analysis pass itself unless the user already sent `add`. |
| `try again` | Re-run **this** gap analysis **after** `add` or after the author closed gaps / changed the diff. Do not re-scan an unchanged change-set “to confirm”. |

**Re-run budget:** if this pass already reported No tests to add / Tests to add for the current diff in this chat, do not re-derive the matrix until requirements or tests change. Shared rule: **Expensive re-run budget** in `workflow-policy.md`.
| `next prompt` | After **No tests to add**, run the next recommended file (`coverage-testing.md` when backend applies). While this pass still reported open **Tests to add**, refuse and tell the user to send `add` (or close the gaps) first. |
| `to correct` | Not for this prompt’s list — use `add`. (`to correct` remains for validation / Pest parallel failures.) |

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

## Scope (Olie)

**Backend only** — `~/git/olie/api-main` (tests under `tests/`, plus production PHP they exercise). Do **not** require frontend / Playwright coverage in this prompt.

Skip entirely when the change set has no `api-main` paths.

## 1. Load the card and requirements

Follow **Tool preference** in `~/git/olie/prompts/workflow-policy.md` (MCP → `gh` → curl).

1. Load the card via MCP `olie-flow-ai`.
2. Read project threads when the product prompts require forum reading for this card; otherwise use description, acceptance criteria, comments, and media.
3. List repositories/branches and open PRs for this card when present.

Do not judge from the title alone.

## 2. Collect tests in the change set

On `~/git/olie/api-main` (checked-out card branch):

1. List added/modified `*Test.php` under `tests/` in the diff vs the repository base (`develop` in `~/git/olie/prompts/project.md`), including uncommitted local edits.
2. Skim those files for scenarios covered.
3. Optionally run touched files: `docker exec olie-api-main php artisan test --compact <paths>`. If they fail, stop and report.

## 3. Gap analysis

From the card requirements (and only those), derive concrete use cases for automated tests. Skim existing change-set tests to decide covered vs missing. Do not mark a use case covered because production code “looks right”.

Out of scope: unrelated areas, full `tests/` inventory, mutation score, frontend e2e.

For every **missing** test, draft one list item:

- **Title** — short name the author can turn into a test / example title.
- **Description** — what to assert and why the card requires it (optional: suggested file or describe block).

## 4. Report

- Card {{ code }}.
- Owner(s) ('atribuído a').
- Backend branch / PR reviewed.
- Exactly one of the two exits below.
- Checks that did not run, and why.

## 5. Outcome (two exits only)

1. **No tests to add** — Say so. In the **Cursor chat** only, recommend `~/git/olie/prompts/coverage-testing.md` when backend coverage still applies; otherwise continue the handoff (`pre-qa.md` or colleague funnel rules).
2. **Tests to add** — In the chat report, list each missing test as **title** + **description**. Do **not** approve and do **not** move the funnel in this paste. Tell the user they can send `add` to implement those items in this chat, then `try again` to re-run this gap analysis.
   - **Own-card:** chat only — do **not** write into the card. Still recommend coverage next in chat when backend applies; do not open `pre-qa.md` from this prompt. Close the gaps via `add` (or manually) before coverage / PRs.
   - **Colleague stack:** leave 'QA/CR' and continue the colleague gates. Keep the list in Cursor chat for the scoreboard / **reviewer-fix** path. Write into the card only when the combined outcome moves to 'Corrigir' (colleague core fail) and the author still needs those tests.

Never invent a third exit or funnel path. Shared rules: `~/git/olie/prompts/workflow-policy.md`.
