# Card Correction Workflow

Use this when a card comes back from review.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/televisao/prompts/workflow-policy.md`.

### Host card environment (required first)

Before media review, stage moves, or git work, run **Host card environment** in `~/git/televisao/prompts/workflow-policy.md`:

```bash
~/git/bin/workvm-host-card ensure --project televisao --code '{{ code }}'
```

Idempotent across days. Do **not** destroy when correction ends — only on `finish card` or board `done`.

## 1. Objective and Context

The card with the code `{{ code }}` was returned for corrections. Its expected workflow is to move from the logical `changes-requested` stage to `in-progress` before correction work begins, provided it is still in `changes-requested`.

Use the MCP OlieFlowAi to retrieve the card's complete context, including:

- The card description, requirements, and acceptance criteria.
- The reviewer's findings and the reasons the card was returned.
- The pull requests associated with the card.
- The repositories and branches involved.
- The implementation changes that were reviewed.
- Any attached specifications, test results, and relevant comments.
- **Project media** (`get-project-media-tool`): every image, video, and audio on the card that supports the return (screenshots, screencasts, and description-linked attachments).

Also read every project thread and the latest version of each one, using **Reading the project notebook** in `~/git/televisao/prompts/workflow-policy.md`. Treat the reviewer's findings, the card's requirements, and those thread texts as the source of truth for the correction work. Do not assume that the reviewer's list is exhaustive; inspect the relevant code to determine the actual causes of the reported issues.

While reading the card / findings (and again before locking the correction plan): apply **Deferred decisions on the card** in `~/git/televisao/prompts/workflow-policy.md`. If a fix path is still deferred — including alternatives joined by **ou** / **or** — **stop**, list the options, ask the user what to choose, and **end each question with your recommendation + why**. Before recommending, also read the **parent** and **children** cards (content + Caderno) when they exist. Do not apply the recommendation until they confirm.

### Card media review (required before the correction plan)

Before creating the correction plan, **review the card's media**. Do not plan only from text comments when the return includes images or videos.

1. `git pull` the meta-repo if needed, then list media via MCP.
2. For each image, video, or audio item that belongs to this card and is part of the return (or is cited by a finding):
   - If `~/git/televisao/cards/{CARD_CODE}/{MEDIA_ID}.md` exists and is non-empty → **Read** it. Do not re-analyze.
   - If that file is **missing** → analyze now: `televisao-project-image-analysis` for images, `televisao-project-video-conversion` for video (API first; agent-local fallback when vid2agent is unreachable). Write the `.md` under `~/git/televisao/cards/{CARD_CODE}/`.
3. Re-analyze or call vid2agent again **only** when the user asks to redo a specific media id (overwrite that file).
4. Use those analyses when diagnosing findings and when writing the correction plan. Cite the media id that shows the defect.
5. **Never** post image, video, or audio analysis to project content (`save-media-tool` or any MCP write of that markdown).
6. After writing **new** analysis files, commit and push them on the meta-repo `~/git` when you finish this media pass (or when the user asks), so a later correction reuses them.

### Hosted preview when the card has a report

A report is a problem described on the card, in a project thread, or in attached media. A card already in production sometimes returns for correction, and the person who tested it usually attaches that media. The problem was seen on the hosted preview. Log in and reproduce it there before treating the finding as verified. Corrections and Playwright still run against the local stack in `~/git/televisao/prompts/project.md`.

| Surface | URL |
| --- | --- |
| Dashboard | `https://televisao.dashboard.enterscience.com.br/` |
| Meet | `https://televisao-meet-front.dashboard.enterscience.com.br/meet/enterscience` |

| Account | Password |
| --- | --- |
| `admin@enterscience.com.br` | `Juca@1234` |
| `superadmin@televisao.com` | `123123` |

Use these accounts only. Leave the passwords out of the plan, the final report, commits, and pull requests.

## 2. Update the Card Stage

Before modifying code, load the card and its live funnel through MCP `olie-flow-ai`. Apply the stage-resolution and move procedure in `~/git/televisao/prompts/workflow-policy.md`.

- If the card is still in `changes-requested` ('Corrigir'), move it to `in-progress` ('Em andamento').
- If the card is already in `in-progress`, continue without moving it again.
- If the card has already moved to another stage, do not move it automatically. Report its current stage and wait for instructions.
- Resolve the card UUID and target `step_id` from MCP / the live funnel. Use `OLIE_MANAGEMENT_TOKEN` for management HTTP auth (not the MCP token). Never hard-code ids or paste tokens.
- Verify that the stage transition succeeded before continuing.
- Do not start a project execution. The Opbed Job page (`/job`) does that (`~/git/televisao/prompts/workflow-policy.md`).

## 3. Analyze the Reviewer's Findings

Before creating the correction plan, inspect the reviewer's feedback and the affected implementation.

**Pull request review feedback (required before the plan).** Resolve the card's associated PR URLs (code-review form **Pull Request (front)** / **Pull Request (back)** and any PR URLs in the project content — **Code review form** / **Closing PR review feedback** in `~/git/televisao/prompts/workflow-policy.md`). For **each** of those PRs, load **both**:

1. **Inline conversation threads** — GitHub MCP `pull_request_read` method `get_review_comments` (or `gh` / GraphQL `reviewThreads` when MCP is unavailable — **Tool preference**).
2. **Review bodies** — GitHub MCP `pull_request_read` method `get_reviews` (or equivalent). Treat actionable points in `CHANGES_REQUESTED` and substantive `COMMENTED` review **bodies** as findings even when there are **zero** inline threads. A review that lists blockers only in the summary body is still a source of truth (GitHub has no Resolve button on that body).

Do this even when the card content / return text already lists findings: PR threads and review bodies often carry line-level or blocker detail the card text omits.

- If a PR has review comments, unresolved threads, **or** actionable review-body points, treat every actionable item as a finding for analysis and for the correction plan (same triage as card/forum findings).
- If a PR has neither threads nor actionable review-body points, say so in the plan and continue with card/forum findings only.
- Do not build or present the plan until those PRs have been checked for **threads and reviews**.
- Do not conclude “no PR feedback” from empty `get_review_comments` alone.

For every reported issue (card, forum/notebook, **PR review thread, and PR review body**):

1. Identify the criterion that failed, if specified by the reviewer.
2. Locate the relevant code in the correct repository and branch.
3. Understand the root cause rather than addressing only the visible symptom.
4. Determine the expected behavior from the card and its specifications.
5. Identify related code paths and edge cases that could exhibit the same defect.
6. Check whether existing tests cover the issue.
7. Determine whether the proposed correction could introduce regressions or affect other repositories.

Review each associated pull request and repository independently. Then inspect the integration between repositories to identify contract mismatches or dependencies.

When the finding is a report, reproduce it on the hosted preview in section 1. Local `localhost` does not stand in for that check.

Do not assume that a reviewer's finding is correct without verifying it. If the finding cannot be reproduced or the evidence suggests that the reviewer's interpretation conflicts with the requirements, document the discrepancy and explain it before choosing a correction.

Do not silently ignore any finding. Every finding must be addressed in the plan as a correction, a verified non-issue with supporting evidence, or an item requiring clarification.

## 4. Repository and Branch Preparation

Identify every repository involved in the card, including:

- `~/git/televisao/televisao-api`
- `~/git/televisao/televisao-front`
- `~/git/televisao/televisao-meet-front`
- `~/git/televisao/televisao-meet-core`
- Any additional repository referenced by the card or its pull requests.

For each repository:

1. Inspect the Git status and identify uncommitted changes.
2. Determine the exact branch used by the associated pull request. The Televisão name is the one built in **Card branch name** in `~/git/televisao/prompts/workflow-policy.md`, not a Branch field on the card.
3. Inspect the relevant commits and compare the branch against the correct base.
4. Switch to the correct existing branch when it is safe to do so.
5. If the branch is missing, create it with the name from **Card branch name** in `~/git/televisao/prompts/workflow-policy.md`, from that repository's base branch in `~/git/televisao/prompts/project.md`.

Never discard, overwrite, or silently modify existing user changes. If uncommitted changes prevent a safe branch switch, stop and report the blocker.

Do not create alternative branch names merely because they are more convenient. Preserve the established card-specific branch naming across involved repositories.

Verify the active branch before any code modification. Never apply a correction to the wrong branch.

## 5. Create the Correction Plan

**Plan mode first (Cursor):** Before creating or presenting the correction plan/checklist, switch the chat to **Plan** mode (`SwitchMode` → `plan`). Investigate read-only and build the plan **while still in Plan mode**. Do not stay in Agent mode and “just write a checklist” in chat — that invites premature coding. Leave Plan mode only when the user sends `next` (or explicitly asks to implement / waives controlled mode). If `SwitchMode` is unavailable, still present the plan and stop; do not start coding.

Before implementing any fix, create the plan in the agent's native planning mechanism (e.g. Cursor `CreatePlan`) while in Plan mode. If unavailable, use an ignored local card-work directory rather than adding an orchestration document to a product repository. Add repository documentation only when the card itself requires it.

The plan must include:

- Card code and objective.
- Which associated PRs were checked for review **threads** and **review bodies**, and whether each had unresolved threads and/or actionable `CHANGES_REQUESTED`/`COMMENTED` body points (list by repo + PR number + short subject).
- The reviewer's findings (**including every actionable PR review comment and every actionable review-body point**) and the root cause of each issue. Do not drop a PR comment or body blocker from triage because it was labeled nit/suggestion/padrão — classify it (in-scope / simple / out-of-scope) like any other finding.
- The relevant repository, branch, files, and code locations.
- The expected behavior and acceptance criteria for each correction.
- Existing test coverage and missing scenarios.
- The proposed test-first implementation steps.
- Dependencies and cross-repository coordination.
- Potential regressions and validation requirements.
- A checklist of small, independently reviewable tasks.
- A section titled 'Issues encountered during development'.

**Scope triage (every finding and every extra defect you discover):** classify each item before it enters the checklist:

- **In-scope** — clearly part of the return / the card's acceptance criteria → fix in this pass.
- **Simple** — outside the original ask but a small, local fix with no product decision → fix in this pass and note it.
- **Out-of-scope** — needs a product decision, a larger change, or a separate delivery → do **not** fix here; propose a new card (or ask the user) instead.

Count **new** findings discovered during this correction (defects you found that were not in the reviewer's return). If that count is greater than **3**, stop before expanding the plan: report the list, explain why so many extras appeared (weak card tasks, incomplete first implementation, or review noise), and wait for instructions instead of absorbing unbounded scope.

Order the checklist by dependencies. Ensure that prerequisite tests, code changes, and integration checks are planned in the correct sequence.

Each item should describe one concrete task and have a clear completion condition.

Present the plan to the user before implementing any corrections.

## 5b. Re-run budget

Verify only what this correction changed. Do **not** re-run the whole unrelated suite or re-open gap/coverage/mutation stacks “for safety” unless the return explicitly requires it or the user asks. Shared rule: **Expensive re-run budget** in `~/git/televisao/prompts/workflow-policy.md`.

## 6. TDD Workflow

Apply Test-Driven Development to the corrections, using the relevant tests in `~/git/televisao/televisao-api` and Playwright under `~/git/televisao/televisao-front-e2e` or `~/git/televisao/televisao-meet-front-e2e`, as well as tests in any other affected repositories.

For each correction, follow this sequence:

1. **Red — Write the test:** Create or update a test that reproduces the reviewer's reported issue or verifies the missing expected behavior. The test should fail for the intended reason before the fix.
2. **Green — Implement the minimum fix:** Write only the code necessary to make the new or updated test pass.
3. **Verify:** Run the relevant test and confirm that it passes. Where appropriate, run related regression tests.
4. **Refactor:** Improve the implementation while preserving behavior and keeping the tests passing.
5. **Recheck:** Run the relevant tests again and verify that the correction does not introduce regressions.
6. **Document:** Update the plan, checklist, and issue log with the actual result.

### Testing rules

- Prefer tests that verify observable behavior rather than internal implementation details.
- When a correction changes `televisao-front` or `televisao-meet-front`, the red step is a Playwright spec (new or edited) in the matching meta-repo suite. Run it with **Running Playwright** in `~/git/televisao/prompts/workflow-policy.md`.
- When a correction adds or edits a `televisao-api` test and `vendor/bin/pest` exists, that file uses that Pest. If the red step edits an existing PHPUnit test file, convert that file with Drift in the same change: `docker exec -w /srv televisao-backend vendor/bin/pest --drift <that-file>`. Do not pass `tests/`. If Drift leaves that file as PHPUnit, finish only that file by hand and say what remained. Leave untouched PHPUnit files. If Pest or Drift is not already installed, stop and report. Do not install them. Run it with `docker exec -w /srv televisao-backend php artisan test --compact <test-path>`.
- Use real integration or E2E coverage when the defect involves interaction between components or repositories.
- Add regression tests for confirmed bugs.
- Keep tests focused on the specific defect and relevant edge cases.
- Do not weaken assertions or alter expected behavior merely to make tests pass.
- Do not claim a test passed if it was not executed successfully.
- If a test fails for an unrelated environmental reason, document the evidence and distinguish that failure from the correction's result.
- Do not modify production code before writing the relevant regression test, unless a documented technical limitation makes the test-first sequence impossible. If that happens, explain the limitation and request authorization before deviating from TDD.


## 7. Incremental Execution

**Default after the plan:** stop. Do **not** start coding, scaffolding, or tests until the user sends **`next`**. Present the checklist clearly in chat so they can follow item by item.

Correction runs in **controlled mode by default**: one checklist item per `next`. Only skip controlled mode when the user explicitly asks to run the whole checklist without stopping (e.g. “implement everything”, “sem next”, “go”).

In controlled mode, wait for the user to send `next` and then:

1. Select the next incomplete checklist item whose dependencies have been satisfied.
2. Implement only that item.
3. Follow the TDD sequence whenever the item involves a code correction.
4. Run the relevant verification.
5. Update the plan and mark the item complete only after its completion conditions have been verified.
6. Report the changes, affected files, test results, and any remaining concerns.
7. Stop and wait for the next `next` command.

If the user explicitly waived controlled mode, perform the same checklist in dependency order and report after each meaningful verification boundary.

Do not implement multiple independent checklist items in one step. Do not skip ahead to later items without authorization.

If an issue reveals a new dependency, a different root cause, or a necessary change to the plan, document it and present the proposed adjustment before continuing with work that depends on it.

If a blocker requires a decision, additional permissions, or a potentially destructive action, stop and request instructions.

## 8. Development Issue Tracking

Maintain the section titled 'Issues encountered during development' in the plan document throughout the correction process.

Record relevant problems, including:

- Findings that differ from the reviewer's initial diagnosis.
- Unexpected behavior discovered while writing regression tests.
- Existing tests that fail for unrelated reasons.
- Environment or configuration problems.
- Missing dependencies or unavailable services.
- Additional regressions or related defects discovered during implementation.

For each issue, describe the evidence, impact, status, and resolution or next action.

Do not silently dismiss review findings or mark unresolved problems as completed.

## 8b. GitHub PR review feedback — prepare only (do not close yet)

There are **two shapes** of feedback (see **Closing PR review feedback** in `~/git/televisao/prompts/workflow-policy.md`). During **this** correction paste you only **prepare** the close — you do **not** publish it.

**Hard ban until after validations:** do **not** mark review threads **Resolved**, do **not** post the review-body **audit comment**, and do **not** treat **commit / push / “mark resolved”** as the end of this paste. Those steps claim the finding is closed on GitHub; that must wait until `recommendation.md` (when applicable) → `implementation-validation.md` (and backend gates when the API changed) has passed. Public close + push of the validated tip belongs to `pre-qa.md` §5.0.

### During this correction paste

1. Fix every actionable thread and review-body point (or document verified non-issue / out-of-scope).
2. Keep a **draft audit checklist** in the chat completion report so pre-qa can post it without rediscovering the review.
3. Leave threads **unresolved** on GitHub. Leave the review body without an audit comment.
4. Do **not** commit or push unless the user explicitly asks for an intermediate save — and even then do **not** post Resolve/audit as if the return were closed.

### After validations (`pre-qa.md` §5.0)

- **A) Inline threads** — Resolve each fully addressed thread.
- **B) Review bodies** — post **one** PR audit comment with commit SHAs on the **pushed** tip. Do **not** dismiss the review to fake closure.

Suggested audit shape (pt-BR is fine when the review was in pt-BR):

```markdown
## Endereçado ao review de @login (YYYY-MM-DD)

1. ✅ <ponto> — <como> (`abc1234`)
2. ✅ <ponto> — <como> (`def5678`)
3. ⬜ <não bloqueante> — adiado / fora de escopo (<motivo>)
```

Card/forum text findings without a GitHub thread or review body are unchanged — there is nothing to Resolve or audit-comment on GitHub.

In the completion report, list: threads Resolved (repo + PR + short subject); any threads left open with why; and every **audit comment** posted for a review body (PR URL + comment URL or date).

## 9. Completion Criteria

The correction work is complete only when:

- Every reviewer finding has been addressed or explicitly resolved with supporting evidence.
- Every associated GitHub PR review **thread** whose points were fully fixed (or verified non-issue / agreed out-of-scope) has been marked **Resolved** (§8b A). Threads still open only when a point remains unfinished — and those are listed in the report.
- Every associated GitHub PR **review body** with actionable points that this pass closed has a public **audit comment** on that PR (§8b B). Missing audit comments after a completed correction are a miss.
- When the card has a report, that problem was reproduced on the hosted preview.
- All applicable checklist items have been completed and verified.
- Regression tests cover the corrected behavior.
- Relevant tests have been executed, with any limitations documented.
- Cross-repository integration has been checked where applicable.
- The implementation plan and issue log are up to date.
- No unrelated user changes have been overwritten.
- No secrets or `.env` content have been committed, pushed, or included in a pull request.

At completion, provide a concise report containing:

- The issues corrected.
- Scope triage summary: in-scope / simple / out-of-scope (and any suggested new cards).
- How many **new** findings (not in the reviewer's return) were discovered; if that count was greater than 3 and work stopped, say so explicitly.
- The files and repositories changed.
- The tests created or updated and their results.
- Which GitHub PR review threads were marked Resolved, any left open with reason, and which review-body audit comments were posted (PR + link/date).
- Any unresolved issues or verification limitations.
- Any remaining manual actions.

Do not commit, push, or open a pull request unless explicitly requested and permitted by the applicable security restrictions.

When a correction changes API inputs/outputs, update Scribe **source** annotations and run `php artisan scribe:generate --force -n` in the API container before considering the docs done. Keep generated paths ready for a dedicated Scribe commit at pre-QA (same separation as Pint) — **Scribe** in `~/git/televisao/prompts/workflow-policy.md`. Do not invent OpenAPI/Blade by hand.

When correction work on this paste is done, the next paste is `~/git/televisao/prompts/recommendation.md` (related improvements only; do not implement them in that paste). After that paste, run `~/git/televisao/prompts/implementation-validation.md` (code-only). Do not run `~/git/televisao/prompts/pre-qa.md` or board `~/git/televisao/prompts/validation.md` yet.

**Evidence table:** post `### Evidência — {N}º Correção` into the **card content** via `save-media-tool` per **Evidence table on project content** in `~/git/televisao/prompts/workflow-policy.md` (rows for what this paste verified; `n/a` / `não rodado` where pre-QA has not run yet; never description, Caderno, or PR). The following **`pre-qa.md`** posts again with the **same** heading and Pint/phpstan/% filled in.
