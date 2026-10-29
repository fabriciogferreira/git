# Test gap analysis

Review card {{ code }}. Compare the card’s requirements with the tests already written for this change set.

This prompt has **exactly two exits**:

1. **No tests to add** — every card-related use case already has automated coverage in the change set.
2. **Tests to add** — a list of missing tests, each with a **title** and a **description**. Write that list into the card content (Brazilian Portuguese) through OlieFlowAi.

Do **not** invent a third exit. Do **not** implement the missing tests in this paste unless the user explicitly asks. Do not run mutation testing here.

Run this **before** `~/git/locav/prompts/mutation-testing.md` when that step applies.

Two entry points:

1. **Own card (develop handoff)** — after `~/git/locav/prompts/implementation-validation.md` passes, when the change set touched `LocavApi` and/or `locav-front`. Next: `mutation-testing.md` only if `LocavApi` changed; then `pre-qa.md`. If neither backend nor front changed, skip this prompt.
2. **Colleague card in 'QA/CR'** — after `~/git/locav/prompts/colleague-review.md`, when backend and/or front changed, **before** mutation (mutation still only if `LocavApi` changed). Leave the card in 'QA/CR' until the remaining stack finishes. Gaps reported here count as “fixes for the author” in the colleague follow-up.

Chat commands: `~/git/locav/prompts/workflow-policy.md` → **Chat commands**.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/locav/prompts/workflow-policy.md`.

## Scope (Locav)

Analyze **both** sides the change set touched:

| Area | Path | What counts as tests |
| --- | --- | --- |
| Backend | `~/git/locav/LocavApi` | `*Test.php` under `tests/` (Pest/PHPUnit) |
| Frontend | `~/git/locav/locav-front` | Cypress under `cypress/e2e` (and unit tests the repo already uses for that change, if any) |

Skip an area that the change set did not touch. Skip the whole prompt when neither `LocavApi` nor `locav-front` changed.

## 1. Load the card and requirements

Follow **Tool preference** in `~/git/locav/prompts/workflow-policy.md` (MCP → `gh` → curl).

1. Load the card via MCP `olie-flow-ai`.
2. Read every project thread (**Reading the project forum** in `workflow-policy.md`).
3. Read acceptance criteria, description, comments, and media when they define behavior.
4. List repositories/branches and open PRs.

Do not judge from the title alone.

## 2. Collect tests in the change set

Base branch: `preview` (`~/git/locav/prompts/project.md`).

**Backend** (if touched): added/modified `*Test.php` under `LocavApi/tests/`, including local edits. Optionally `docker exec -w /var/www/html locav-backend php artisan test --compact <paths>`.

**Frontend** (if touched): added/modified specs under `locav-front/cypress/e2e` (and other front test files in the diff). Do not require a full Cypress run in this paste; skim the specs against the card. If a quick host Cypress for one file is needed and tooling fails, stop and report (prompt-health).

## 3. Gap analysis

From the card requirements (and only those), derive concrete use cases. Tag each as **backend**, **frontend**, or **both**. Skim existing change-set tests to decide covered vs missing. Do not mark a use case covered because UI or PHP “looks right”.

Out of scope: unrelated product areas, full-tree inventory, mutation score, meta-repo-only suites.

For every **missing** test, draft one list item:

- **Title** — short name the author can turn into a test / example / Cypress title.
- **Description** — what to assert, backend vs frontend, and why the card requires it (optional: suggested Pest file or `cypress/e2e/...`).

## 4. Report

- Card {{ code }}.
- Owner(s) ('atribuído a').
- Repositories / branches / PRs reviewed.
- Exactly one of the two exits below.
- Checks that did not run, and why.

## 5. Outcome (two exits only)

1. **No tests to add** — Say so. If `LocavApi` changed, recommend `~/git/locav/prompts/mutation-testing.md`; else continue to `pre-qa.md` (own card) or colleague funnel rules (no mutation).
2. **Tests to add** — In the chat report, list each missing test as **title** + **description**. **Also write that same list into the card content** through OlieFlowAi (Brazilian Portuguese). On the colleague stack, leave 'QA/CR'; continue to mutation when backend applies; treat these items like mutation-reported fixes in the Corrigir / loop rules. On own-card handoff, recommend mutation next when backend applies; do not open `pre-qa.md` from this prompt when mutation still applies.

Never invent a third exit or funnel path. Shared rules: `~/git/locav/prompts/workflow-policy.md`.
