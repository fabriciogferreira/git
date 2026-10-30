# Test gap analysis

Review card {{ code }}. Compare the card’s requirements with the tests already written for this change set.

This prompt has **exactly two exits**:

1. **No tests to add** — every card-related use case already has automated coverage in the change set.
2. **Tests to add** — a list of missing tests, each with a **title** and a **description**. Write that list into the card content (Brazilian Portuguese) through OlieFlowAi. Titles and descriptions only — no prompt paths (**Card content vs chat** in `~/git/televisao/prompts/workflow-policy.md`).

Do **not** invent a third exit. Do **not** implement the missing tests in this paste unless the user explicitly asks. Do not run mutation testing here.

Run this **before** `~/git/televisao/prompts/mutation-testing.md` when that step applies.

Two entry points:

1. **Own card (develop handoff)** — after `~/git/televisao/prompts/implementation-validation.md` passes and the change set touched `~/git/televisao/televisao-api`. Next paste: `mutation-testing.md` (then `pre-qa.md`). If there is no backend change, skip this prompt.
2. **Colleague card in 'QA/CR'** — after `~/git/televisao/prompts/colleague-review.md`, when the change set touched `televisao-api`, **before** mutation. Leave the card in 'QA/CR' until the remaining stack (this prompt + mutation when applicable) finishes. Gaps reported here count as “fixes for the author” in **Colleague review outcome** (`~/git/televisao/prompts/workflow-policy.md`).

Chat commands: `~/git/televisao/prompts/workflow-policy.md` → **Chat commands**.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/televisao/prompts/workflow-policy.md`.

## Scope (Televisão)

**Backend only** — `~/git/televisao/televisao-api` (Pest/PHPUnit under `tests/`, plus production PHP the tests exercise). Do **not** require or invent frontend / meta-repo Playwright coverage in this prompt.

Skip entirely when the change set has no `televisao-api` paths.

## 1. Load the card and requirements

Follow **Tool preference** in `~/git/televisao/prompts/workflow-policy.md` (MCP → `gh` → curl).

1. Load the card via MCP `olie-flow-ai` (`get-project-details-tool` / search).
2. Read every project thread (**Reading the project forum** in `workflow-policy.md`) — latest version of each thread.
3. Read acceptance criteria, description, comments, and **project media** when they define expected behavior.
4. List repositories/branches and open PRs for this card when present.

Do not judge from the title alone.

## 2. Collect tests in the change set

On `~/git/televisao/televisao-api` (checked-out card branch):

1. List added/modified test files: `*Test.php` under `tests/` in the diff vs the repository base (`preview` in `~/git/televisao/prompts/project.md`), including uncommitted local edits.
2. Skim those files (and only neighboring helpers they use) for scenarios covered: happy path, auth/forbidden, validation, edge cases named in the card.
3. Optionally run the touched files: `docker exec -w /srv televisao-backend php artisan test --compact <paths>`. If they fail, stop and report; do not invent coverage from red tests.

## 3. Gap analysis

From the card requirements (and only those), derive concrete use cases for automated tests. Skim existing change-set tests to decide covered vs missing. Prefer gaps that would fail if the implementation regressed the card. Do not mark a use case covered because production code “looks right”.

Out of scope: unrelated product areas, full-suite inventory of `tests/`, mutation score / Pint / CI, frontend / meta-repo Playwright.

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

1. **No tests to add** — Say so. In the **Cursor chat** only, recommend `~/git/televisao/prompts/mutation-testing.md` as the next paste when backend mutation still applies; otherwise follow the handoff already in progress (`pre-qa.md` on own card, or **Colleague review outcome** when mutation was skipped).
2. **Tests to add** — In the chat report, list each missing test as **title** + **description**. **Also write that same list into the card content** through OlieFlowAi (Brazilian Portuguese; no prompt paths). Do **not** approve/merge and do **not** move the funnel in this paste on the colleague stack — leave 'QA/CR' and continue to `mutation-testing.md` if it still applies; the combined outcome after that stack treats these items like mutation-reported fixes (Corrigir if tests-to-add or mutation fixes remain; Revisado only if colleague passed **and** no tests-to-add **and** mutation clean/skipped). On own-card handoff, still recommend mutation next in chat when backend applies; do not open `pre-qa.md` from this prompt.

Never invent a third exit or funnel path. Shared rules: `~/git/televisao/prompts/workflow-policy.md`.
