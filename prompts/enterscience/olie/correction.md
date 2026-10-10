# Card Correction Workflow

Use this when a card comes back from review. The workday order stays in `workflow.md`. Do not repeat `implementation.md` except where this file names a step that lives only there.

## 1. Objective and Context

The card with the code `'{{ code }}'` was returned for corrections. Its expected workflow is to move from the stage named 'Corrigir' to the stage named 'Em progresso' before correction work begins, provided it is still in 'Corrigir'.

Use the MCP OlieFlowAi to retrieve the card's complete context, including:

- The card description, requirements, and acceptance criteria.
- The reviewer's findings and the reasons the card was returned.
- The pull requests associated with the card.
- The repositories and branches involved.
- The implementation changes that were reviewed.
- Any attached specifications, test results, and relevant comments.

Treat the reviewer's findings and the card's requirements as the source of truth for the correction work. Do not assume that the reviewer's list is exhaustive; inspect the relevant code to determine the actual causes of the reported issues.

## 2. Update the Card Stage

Before modifying code, check the card's current stage through the MCP OlieFlowAi.

- If the card is still in the stage named 'Corrigir', move it to the stage named 'Em progresso'.
- If the card has already moved to another stage, do not move it automatically. Report its current stage and wait for instructions.
- Verify that the stage transition succeeded before continuing.

### API fallback

If a Bearer token has been provided and the card ID and project ID can be retrieved through the MCP OlieFlowAi, the following API request may be used to perform the transition when necessary.

Use the actual project ID in place of `{project id}` and the actual card ID to verify that the operation targets the correct card.

```bash
curl --fail-with-body --silent --show-error \
  --url 'https://api.olie.ai/api/management/projects/{project id}/project-executions' \
  -H 'accept: application/json, text/plain, */*' \
  -H 'content-type: application/json' \
  -H 'authorization: Bearer {{ token }}' \
  --data-raw '{"funnel_step_id":1450}'
```

Before executing the request:

1. Verify that the endpoint and `funnel_step_id` correspond to the intended project and the stage named 'Em progresso'.
2. Verify the card's current stage and identify the correct execution record or ID required by the API.
3. Confirm that the request will update the intended card rather than create a new execution or modify another card.
4. Use the request only if the endpoint's behavior and required parameters have been verified.

Do not execute the request if its target or semantics are uncertain. Prefer the MCP OlieFlowAi operation when it supports the required stage transition.

Never expose the Bearer token in logs, reports, commits, or pull requests. Do not retrieve or invent credentials if a token was not provided.

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

- `~/git/projects/olie/olie-e2e`
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

Before implementing any fix, create a Markdown plan in `/docs`.

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

Apply Test-Driven Development to the corrections, using the relevant tests in `~/git/projects/olie/olie-e2e` and `~/git/olie/api-main`, as well as tests in any other affected repositories.

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

## 7. Mandatory E2E CAPTCHA Configuration

When running Playwright E2E tests that require CAPTCHA authentication through `api-main`, use the Google test secret in `~/git/olie/api-main/.env`.

It accepts any token, including the E2E stub.

Set the following local environment variable:

`RECAPTCHA_SECRET=6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe`

Follow these requirements strictly:

1. Preserve the original secret as a commented-out entry in the same `.env` file so it can be restored later.
2. Change only the local `.env` configuration. Never modify PHP code or application logic to disable CAPTCHA.
3. After making the change, run:

   `docker exec olie-api-main php artisan config:clear`

4. Verify that the configuration change has taken effect before relying on it for E2E testing.
5. Keep the change strictly local. Never commit or push the test secret, the original secret, or any `.env` file.
6. Do not open a pull request containing this configuration or its secrets.
7. These restrictions remain in effect even if the user requests a commit or pull request for the rest of the work.

If the environment or container is unavailable, report the blocker instead of introducing a code-level CAPTCHA bypass.

## 8. Incremental Execution

After presenting the plan, wait for the user to send 'next'.

Each time the user sends 'next':

1. Select the next incomplete checklist item whose dependencies have been satisfied.
2. Implement only that item.
3. Follow the TDD sequence whenever the item involves a code correction.
4. Run the relevant verification.
5. Update the plan and mark the item complete only after its completion conditions have been verified.
6. Report the changes, affected files, test results, and any remaining concerns.
7. Stop and wait for the next 'next' command.

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
