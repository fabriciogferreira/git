# Test gap analysis

Review card {{ code }}. Compare the card’s requirements with the tests already written for this change set.

This prompt has **exactly two exits** (own-card chat commands in the table below):

1. **No tests to add** → suggest **`next prompt`** (mutation when `LocavApi` changed; else pre-QA).
2. **Tests to add** → suggest **`to correct`** (implement the missing tests), then **`try again`** (re-run this gap analysis). Write the list into the card content (Brazilian Portuguese) through OlieFlowAi. Titles and descriptions only — no prompt paths (**Card content vs chat** in `~/git/locav/prompts/workflow-policy.md`).

Do **not** invent a third exit. Do **not** implement the missing tests in this paste unless the user already sent `to correct` (or otherwise asks). Do not run mutation testing here.

### Chat commands

Same phrases as in `~/git/locav/prompts/workflow-policy.md` (**Chat commands**):

| Command | Do this |
| --- | --- |
| `next prompt` | After **No tests to add** (own-card), run the next recommended file (`mutation-testing.md` when `LocavApi` changed, else `pre-qa.md`) without waiting for a paste. |
| `try again` | Re-run **this** gap analysis (e.g. after `to correct` added the missing tests). |
| `to correct` | After **Tests to add**: implement every missing test from this pass’s list, then stop and recommend `try again` (re-run this gap analysis). Do not implement during the analysis pass itself unless the user already sent `to correct`. |

Run this **before** `~/git/locav/prompts/mutation-testing.md` when that step applies.

Two entry points:

1. **Own card (develop handoff)** — after `~/git/locav/prompts/implementation-validation.md` passes, when the change set touched `LocavApi` and/or `locav-front`. After a clean gap pass, next is `mutation-testing.md` only if `LocavApi` changed (else `pre-qa.md`) via `next prompt`. If neither backend nor front changed, skip this prompt.
2. **Colleague card in 'QA/CR'** — after `~/git/locav/prompts/colleague-review.md`, when backend and/or front changed, **before** mutation (mutation still only if `LocavApi` changed). Leave the card in 'QA/CR' until the remaining stack finishes. Gaps reported here count as “fixes for the author” in the colleague follow-up. Do **not** treat colleague stack as own-card `to correct` / `next prompt` sequencing unless that chat is the author fixing gaps.

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
2. Read every project thread (**Reading the project notebook** in `workflow-policy.md`).
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

1. **No tests to add** — Say so.
   - **Own-card:** in the **Cursor chat** only, name `~/git/locav/prompts/mutation-testing.md` when `LocavApi` changed (else `pre-qa.md`), and tell the user to send **`next prompt`**.
   - **Colleague stack:** leave 'QA/CR'; continue per colleague funnel rules (mutation when backend applies). Do **not** suggest own-card `next prompt` / `to correct` sequencing here.
2. **Tests to add** — In the chat report, list each missing test as **title** + **description**. **Also write that same list into the card content** through OlieFlowAi (Brazilian Portuguese; no prompt paths).
   - **Own-card:** tell the user to send **`to correct`** to implement every missing test from this list, then **`try again`** to re-run this gap analysis. Do **not** recommend mutation or `pre-qa.md` until a later gap pass exits **No tests to add**.
   - **Colleague stack:** leave 'QA/CR'; treat these items like mutation-reported fixes in the Corrigir / loop rules. Do **not** suggest own-card `to correct` / `next prompt` sequencing here.

Never invent a third exit or funnel path. Shared rules: `~/git/locav/prompts/workflow-policy.md`.
