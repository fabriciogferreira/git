# Card Correction Workflow

Use this when a card comes back from review.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

## 1. Objective and Context

The card with the code `{{ code }}` was returned for corrections. Its expected workflow is to move from the logical `changes-requested` stage to `in-progress` before correction work begins, provided it is still in `changes-requested`.

Use the MCP OlieFlowAi to retrieve the card's complete context, including:

- The card description, requirements, and acceptance criteria.
- The reviewer's findings and the reasons the card was returned.
- The pull requests associated with the card.
- The repositories and branches involved.
- The implementation changes that were reviewed.
- Any attached specifications, test results, and relevant comments.

Treat the reviewer's findings and the card's requirements as the source of truth for the correction work. Do not assume that the reviewer's list is exhaustive; inspect the relevant code to determine the actual causes of the reported issues.

Media already analyzed for this card lives under `~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md` (versioned on the meta-repo). **Read those files first** (after `git pull` if needed). Do not re-analyze image/video/audio or call vid2agent again unless the user asks to redo a specific media id. Never post that analysis to project content.

## 2. Update the Card Stage

Before modifying code, load the card and its live funnel through MCP `olie-flow-ai`. Apply the stage-resolution and move procedure in `~/git/olie/prompts/workflow-policy.md`.

- If the card is still in `changes-requested` ('corrigir ou melhorar'), move it to `in-progress` ('Em progresso').
- If the card is already in `in-progress`, continue without moving it again.
- If the card has already moved to another stage, do not move it automatically. Report its current stage and wait for instructions.
- Resolve the card UUID and target `step_id` from MCP / the live funnel. Use `OLIE_MANAGEMENT_TOKEN` for management HTTP auth (not the MCP token). Never hard-code ids or paste tokens.
- Verify that the stage transition succeeded before continuing.
- Do not start a project execution. The Opbed Job page (`/job`) does that (`~/git/olie/prompts/workflow-policy.md`).

## 3. Analyze the Reviewer's Findings

Before creating the correction plan, inspect the reviewer's feedback and the affected implementation.

For every reported issue:

1. Identify the criterion that failed, if specified by the reviewer.
2. Locate the relevant code in the correct repository and branch.
3. Understand the root cause rather than addressing only the visible symptom.
4. Determine the expected behavior from the card and its specifications.
5. Identify related code paths and edge cases that could exhibit the same defect.
6. Check whether existing tests cover the issue.
7. Determine whether the proposed correction could introduce regressions or affect other repositories.

Review each associated pull request and repository independently. Then inspect the integration between repositories to identify contract mismatches or dependencies.

Do not assume that a reviewer's finding is correct without verifying it. If the finding cannot be reproduced or the evidence suggests that the reviewer's interpretation conflicts with the requirements, document the discrepancy and explain it before choosing a correction.

Do not silently ignore any finding. Every finding must be addressed in the plan as a correction, a verified non-issue with supporting evidence, or an item requiring clarification.

## 4. Repository and Branch Preparation

Identify every repository involved in the card, including:

- `~/git/olie/olie-e2e`
- `~/git/olie/api-main`
- Any additional repository referenced by the card or its pull requests.

For each repository:

1. Inspect the Git status and identify uncommitted changes.
2. Determine the exact branch used by the associated pull request and the branch naming specified in the card.
3. Inspect the relevant commits and compare the branch against the correct base.
4. Switch to the correct existing branch when it is safe to do so.
5. If the branch is missing, determine the correct base and branch name from the card and repository workflow before creating it.

Never discard, overwrite, or silently modify existing user changes. If uncommitted changes prevent a safe branch switch, stop and report the blocker.

Do not create alternative branch names merely because they are more convenient. Preserve the established card-specific branch naming across involved repositories.

Verify the active branch before any code modification. Never apply a correction to the wrong branch.

## 5. Create the Correction Plan

Before implementing any fix, create the plan in the agent's native planning mechanism. If unavailable, use an ignored local card-work directory rather than adding an orchestration document to a product repository. Add repository documentation only when the card itself requires it.

The plan must include:

- Card code and objective.
- The reviewer's findings and the root cause of each issue.
- The relevant repository, branch, files, and code locations.
- The expected behavior and acceptance criteria for each correction.
- Existing test coverage and missing scenarios.
- The proposed test-first implementation steps.
- Dependencies and cross-repository coordination.
- Potential regressions and validation requirements.
- A checklist of small, independently reviewable tasks.
- A section titled 'Issues encountered during development'.

Order the checklist by dependencies. Ensure that prerequisite tests, code changes, and integration checks are planned in the correct sequence.

Each item should describe one concrete task and have a clear completion condition.

Present the plan to the user before implementing any corrections.

## 6. TDD Workflow

Apply Test-Driven Development to the corrections, using the relevant tests in `~/git/olie/olie-e2e` and `~/git/olie/api-main`, as well as tests in any other affected repositories.

For each correction, follow this sequence:

1. **Red — Write the test:** Create or update a test that reproduces the reviewer's reported issue or verifies the missing expected behavior. The test should fail for the intended reason before the fix.
2. **Green — Implement the minimum fix:** Write only the code necessary to make the new or updated test pass.
3. **Verify:** Run the relevant test and confirm that it passes. Where appropriate, run related regression tests.
4. **Refactor:** Improve the implementation while preserving behavior and keeping the tests passing.
5. **Recheck:** Run the relevant tests again and verify that the correction does not introduce regressions.
6. **Document:** Update the plan, checklist, and issue log with the actual result.

### Testing rules

- Prefer tests that verify observable behavior rather than internal implementation details.
- Use real integration or E2E coverage when the defect involves interaction between components or repositories.
- Add regression tests for confirmed bugs.
- Keep tests focused on the specific defect and relevant edge cases.
- Do not weaken assertions or alter expected behavior merely to make tests pass.
- Do not claim a test passed if it was not executed successfully.
- If a test fails for an unrelated environmental reason, document the evidence and distinguish that failure from the correction's result.
- Do not modify production code before writing the relevant regression test, unless a documented technical limitation makes the test-first sequence impossible. If that happens, explain the limitation and request authorization before deviating from TDD.
- Do not edit `en.json` while correcting. English translations are resolved later. Fix or add user-facing keys in `pt-br.json` only.

## 7. Temporary E2E CAPTCHA Configuration

Use this only when a Playwright E2E scenario must authenticate through `api-main`.

The Google test secret is:

`RECAPTCHA_SECRET=6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe`

Follow these requirements strictly:

1. Confirm that `~/git/olie/api-main/.env` is ignored and create a permission-restricted backup outside the repository before changing it.
2. Replace the local `RECAPTCHA_SECRET` value with the test secret. Do not retain the original secret as a comment or in any repository file.
3. Do not modify PHP code or application logic to bypass CAPTCHA.
4. Run `docker exec olie-api-main php artisan config:clear` and verify the configuration change before relying on it.
5. Restore the exact `.env` backup and run `config:clear` again immediately after the E2E run, even if the test fails.
6. Delete the backup after restoration. If restoration fails, report that the test configuration may still be active.
7. Never commit, push, log, or include `.env` content or secrets in a pull request.

If the environment or container is unavailable, report the blocker rather than introducing a code-level CAPTCHA bypass.

## 8. Incremental Execution

After presenting the plan, use controlled mode only when the user requests step-by-step approval or the correction spans multiple repositories or high-risk changes.

In controlled mode, wait for the user to send 'next' and then:

1. Select the next incomplete checklist item whose dependencies have been satisfied.
2. Implement only that item.
3. Follow the TDD sequence whenever the item involves a code correction.
4. Run the relevant verification.
5. Update the plan and mark the item complete only after its completion conditions have been verified.
6. Report the changes, affected files, test results, and any remaining concerns.
7. Stop and wait for the next 'next' command.

Outside controlled mode, perform the same checklist in dependency order and report after each meaningful verification boundary.

Do not implement multiple independent checklist items in one step. Do not skip ahead to later items without authorization.

If an issue reveals a new dependency, a different root cause, or a necessary change to the plan, document it and present the proposed adjustment before continuing with work that depends on it.

If a blocker requires a decision, additional permissions, or a potentially destructive action, stop and request instructions.

## 9. Development Issue Tracking

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

## 10. Completion Criteria

The correction work is complete only when:

- Every reviewer finding has been addressed or explicitly resolved with supporting evidence.
- All applicable checklist items have been completed and verified.
- Regression tests cover the corrected behavior.
- Relevant tests have been executed, with any limitations documented.
- Cross-repository integration has been checked where applicable.
- The implementation plan and issue log are up to date.
- No unrelated user changes have been overwritten.
- No prohibited CAPTCHA configuration or secrets have been committed, pushed, or included in a pull request.

At completion, provide a concise report containing:

- The issues corrected.
- The files and repositories changed.
- The tests created or updated and their results.
- Any unresolved issues or verification limitations.
- Any remaining manual actions.

Do not commit, push, or open a pull request unless explicitly requested and permitted by the applicable security restrictions.
