# Card Development Workflow

## 1. Context and Objective

Implement the card identified by `{{ code }}`. Its requirements, business rules, dependencies, and implementation context are available through the MCP OlieFlowAi.

Use the card's content as the source of truth for the intended behavior. Before making implementation decisions, inspect the relevant codebase, existing tests, and dependencies to understand the current behavior and identify potential side effects.

## 2. Git Workflow

Before making any code changes:

1. Check the current Git status. Preserve existing user changes and never overwrite, discard, or silently modify unrelated work.
2. Switch to the 'develop' branch. If the working tree contains changes that could interfere with switching branches or updating the repository, stop and report the situation before proceeding.
3. Pull the latest changes from 'develop'. If the update fails or cannot be completed safely, report the issue and wait for further instructions.
4. Read the card's content to identify the required branch name.
5. Create and switch to the card-specific branch based on the updated 'develop' branch.
6. Verify that the active branch is correct before proceeding.

Do not implement the card on 'develop'.

## 3. Planning Phase

Before implementing anything, analyze the card requirements and create a concrete implementation plan.

### 3.1. Codebase Investigation

Inspect the relevant application code, architecture, business rules, dependencies, and existing tests.

Identify and document:

- The code responsible for the current behavior.
- Existing code that could interfere with, override, or otherwise affect the behavior being implemented or modified.
- Dependencies, indirect effects, and potential regressions.
- Relevant edge cases, error scenarios, and integration points.
- Existing tests and gaps in test coverage.

Document the findings that are relevant to implementation and testing. Do not modify unrelated code merely to simplify the implementation.

### 3.2. Test Coverage

Before implementing the card, inspect the E2E test suite located at `~/git/projects/olie/olie-e2e`.

Determine whether the existing tests adequately cover the current behavior and the scenarios affected by the proposed changes.

If tests are missing or coverage is insufficient, add `create tests for the behavior` as an explicit item in the implementation checklist.

Do not assume that the absence of an obvious test means no relevant tests exist. Search the existing test suite and inspect related scenarios before identifying gaps.

### 3.3. Plan Documentation

Create a Markdown document in `/docs` containing the implementation plan.

The document must include:

- Card code and a concise description of the objective.
- Relevant requirements and acceptance criteria.
- Findings from the codebase investigation.
- Existing behavior that could interfere with the intended behavior.
- Test coverage assessment and identified gaps.
- An ordered implementation checklist.
- Potential risks, dependencies, and regression scenarios.
- A section titled 'Issues encountered during development'.

The checklist must contain small, independently reviewable tasks, ordered by dependency. Include testing, documentation, and verification tasks where applicable.

Do not begin implementation until the plan is documented and presented for review.

## 4. Step-by-Step Implementation

Implementation must be incremental and controlled by the user's explicit command.

After presenting the plan:

1. Wait for the user to send 'next'.
2. When 'next' is received, implement only the next incomplete checklist item.
3. Mark an item as complete only after its requirements have been implemented and the relevant verification has succeeded.
4. Update the plan document whenever progress, findings, or implementation details change.
5. Report what changed, which files were affected, what verification was performed, and any remaining concerns.
6. Stop and wait for the next 'next' command before proceeding to another checklist item.

If a task reveals new requirements, unexpected dependencies, significant risks, or a need to change the plan, document the findings and present the proposed adjustment before proceeding with work that depends on that adjustment.

Do not skip checklist items, combine multiple independent items into one step, or implement subsequent items without authorization.

If an issue blocks the current item, explain the blocker and wait for instructions when resolving it requires a decision or action beyond the existing plan.

## 5. Development Issue Tracking

Maintain the section titled 'Issues encountered during development' in the plan document throughout the implementation.

Record problems discovered during investigation, implementation, and testing, including:

- Unexpected existing behavior.
- Bugs or inconsistencies in related code.
- Missing or unreliable test coverage.
- Environmental or configuration problems.
- Failed commands, tests, or verification steps.
- Relevant workarounds and unresolved risks.

For each issue, describe the observed problem, its impact, its status, and the resolution or proposed next action when known.

Do not silently omit failed checks or describe an issue as resolved without verification.

## 6. Mandatory E2E CAPTCHA Configuration

**This configuration is mandatory when running Playwright E2E tests that require CAPTCHA authentication through `api-main`.**

To allow Playwright to log in, use the Google test secret in `~/git/olie/api-main/.env`. It accepts any token, including the E2E stub.

Set the following local environment variable:

`RECAPTCHA_SECRET=6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe`

Follow these requirements strictly:

1. Before changing the variable, preserve the original secret as a commented-out entry in the same `.env` file so it can be restored later.
2. Modify only the local `.env` configuration to enable the test secret. Do not modify PHP code or application logic to disable CAPTCHA.
3. After changing the configuration, run:

   `docker exec olie-api-main php artisan config:clear`

4. Verify that the configuration change has taken effect before relying on it for E2E testing.
5. Keep this configuration local. Never commit or push the test secret, the original secret, or any `.env` file.
6. Do not open a pull request containing this configuration or its secrets.
7. These restrictions apply even if the user requests a commit or pull request for the rest of the work.

If the environment or container is unavailable, report the blocker rather than introducing a code-level CAPTCHA bypass.

## 7. Code Quality and Validation

Follow the project's existing architecture, conventions, and established patterns. Prefer the smallest change that correctly satisfies the card's requirements.

- Avoid unrelated refactoring and unnecessary changes.
- Preserve existing behavior unless the card explicitly requires changing it.
- Add or update tests to cover the intended behavior, relevant edge cases, and regressions.
- Run appropriate tests and verification commands for the current checklist item when the environment permits.
- Clearly distinguish successful checks from checks that failed, were skipped, or could not run.
- Document any verification limitations in the plan.

**Do not run 'pint' unless the user explicitly instructs you to do so.** This restriction applies throughout the workflow, including final cleanup and verification.

## 8. Completion Criteria

The card is complete only when all applicable checklist items have been completed and verified, including:

- The implementation satisfies the card's requirements and acceptance criteria.
- Relevant tests have been created or updated, and coverage gaps have been addressed as planned.
- Required tests and verification checks have been run, with any remaining limitations explicitly reported.
- Relevant documentation and the implementation checklist are up to date.
- The 'Issues encountered during development' section accurately reflects resolved and unresolved issues.
- No unrelated user changes have been overwritten or included unintentionally.
- No prohibited CAPTCHA configuration or secrets have been committed, pushed, or included in a pull request.

When all checklist items are complete, provide a concise final report covering the implementation, changed files, tests and verification results, unresolved issues, and any remaining manual actions.

Do not commit, push, or open a pull request unless explicitly requested and permitted by the applicable restrictions above.