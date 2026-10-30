# Test gap analysis

Review card {{ code }}. Compare the card’s requirements with the tests already written for this change set.

This prompt has **exactly two exits**:

1. **No tests to add** — every card-related use case already has automated coverage in the change set.
2. **Tests to add** — a list of missing tests, each with a **title** and a **description**. Write that list into the card content (Brazilian Portuguese) through OlieFlowAi. Titles and descriptions only — no prompt paths (**Card content vs chat** in `~/git/olie/prompts/workflow-policy.md`).

Do **not** invent a third exit. Do **not** implement the missing tests in this paste unless the user explicitly asks. Do not run mutation testing here.

Run this **before** `~/git/olie/prompts/mutation-testing.md` when that step applies.

Two entry points:

1. **Own card (develop handoff)** — after `~/git/olie/prompts/implementation-validation.md` passes and the change set touched `~/git/olie/api-main`. Next paste: `mutation-testing.md` (then `pre-qa.md`). If there is no backend change, skip this prompt.
2. **Colleague card in 'QA/CR'** — after `~/git/olie/prompts/colleague-review.md`, when the change set touched `api-main`, **before** mutation. Leave the card in 'QA/CR' until the remaining stack finishes. Gaps reported here count as “fixes for the author” for the colleague follow-up loop in `~/git/olie/prompts/workflow-policy.md` / `colleague-review.md`.

Chat commands: `~/git/olie/prompts/workflow-policy.md` → **Chat commands**.

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

1. **No tests to add** — Say so. In the **Cursor chat** only, recommend `~/git/olie/prompts/mutation-testing.md` when backend mutation still applies; otherwise continue the handoff (`pre-qa.md` or colleague funnel rules).
2. **Tests to add** — In the chat report, list each missing test as **title** + **description**. **Also write that same list into the card content** through OlieFlowAi (Brazilian Portuguese; no prompt paths). On the colleague stack, leave 'QA/CR' and continue to `mutation-testing.md` when it applies; treat these items like mutation-reported fixes in the follow-up / Corrigir loop. On own-card handoff, still recommend mutation next in chat when backend applies; do not open `pre-qa.md` from this prompt.

Never invent a third exit or funnel path. Shared rules: `~/git/olie/prompts/workflow-policy.md`.
