# Test gap analysis

Review card {{ code }}. Compare the card’s requirements with the tests already written for this change set.

This prompt has **exactly two exits** (own-card chat commands in the table below):

1. **No tests to add** → suggest **`next prompt`** (mutation when backend applies).
2. **Tests to add** → suggest **`to correct`** (implement the missing tests), then **`try again`** (re-run this gap analysis). Write the list into the card content (Brazilian Portuguese) through OlieFlowAi. Titles and descriptions only — no prompt paths (**Card content vs chat** in `~/git/olie/prompts/workflow-policy.md`).

Do **not** invent a third exit. Do **not** implement the missing tests in this paste unless the user already sent `to correct` (or otherwise asks). Do not run mutation testing here.

### Chat commands

Same phrases as in `~/git/olie/prompts/workflow-policy.md` (**Chat commands**):

| Command | Do this |
| --- | --- |
| `next prompt` | After **No tests to add** (own-card), run the next recommended file (`mutation-testing.md`, or `pre-qa.md` when mutation does not apply) without waiting for a paste. |
| `try again` | Re-run **this** gap analysis (e.g. after `to correct` added the missing tests). |
| `to correct` | After **Tests to add**: implement every missing test from this pass’s list, then stop and recommend `try again` (re-run this gap analysis). Do not implement during the analysis pass itself unless the user already sent `to correct`. |

Three entry points:

1. **Own card (develop handoff)** — after `~/git/olie/prompts/implementation-validation.md` passes and the change set touched `~/git/olie/api-main`. After a clean gap pass, next is `mutation-testing.md` (then `pre-qa.md`) via `next prompt`. If there is no backend change, skip this prompt. On this path, run **before** `mutation-testing.md` when that step applies (sequential).
2. **Colleague card in 'QA/CR' via dispatcher** — launched **in parallel** by `~/git/olie/prompts/colleague-review.md` together with `colleague-review-core.md` and `mutation-testing.md` when the change set touched `api-main`. **Dispatcher mode:** do **not** suggest `next prompt` / `to correct` for a sequential handoff; return the exit result to the dispatcher; leave funnel moves to it. Gaps reported here still count as “fixes for the author” in **Colleague review outcome** (`~/git/olie/prompts/workflow-policy.md`).
3. **Colleague card pasted alone** — if the user pastes this file without the dispatcher, behave as before for the analysis body, then tell them to use `colleague-review.md` so the combined outcome runs.

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
3. Optionally run touched files **only when this paste is alone** (own-card / gap pasted without a parallel mutation gate): prefer `~/git/bin/workvm-sandbox` `--project olie --profile tests`, or `docker exec olie-api-main php artisan test --compact <paths>` if no sandbox. If they fail, stop and report. **Dispatcher mode (parallel with mutation):** do **not** run Pest on the Card VM — coverage judgment is static from the change-set tests + card requirements only.

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

1. **No tests to add** — Say so.
   - **Dispatcher mode (colleague):** return this exit to `colleague-review.md`; do **not** suggest `next prompt` / `to correct` or move the funnel (mutation is already parallel; the dispatcher applies **Colleague review outcome**).
   - **Own-card:** in the **Cursor chat** only, name `~/git/olie/prompts/mutation-testing.md` as next when backend mutation still applies (else `pre-qa.md`), and tell the user to send **`next prompt`**.
   - **Alone on colleague stack:** tell the user to paste `colleague-review.md` for the combined outcome (no `next prompt` / `to correct` here).
2. **Tests to add** — In the chat report, list each missing test as **title** + **description**. **Also write that same list into the card content** through OlieFlowAi (Brazilian Portuguese; no prompt paths). Do **not** approve and do **not** move the funnel in this paste.
   - **Dispatcher mode:** return the list to the dispatcher; the combined outcome treats these items like mutation-reported fixes. Do **not** suggest `to correct` / `next prompt` for a sequential handoff.
   - **Own-card:** tell the user to send **`to correct`** to implement every missing test from this list, then **`try again`** to re-run this gap analysis. Do **not** recommend mutation or `pre-qa.md` until a later gap pass exits **No tests to add**.
   - **Alone on colleague stack:** tell the user to paste `colleague-review.md` for the combined outcome.

Never invent a third exit or funnel path. Shared rules: `~/git/olie/prompts/workflow-policy.md`.
