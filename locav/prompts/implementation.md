# Card Development Workflow

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/locav/prompts/workflow-policy.md`.

## 1. Context and Objective

Implement the card identified by `{{ code }}`. Its requirements, business rules, dependencies, and implementation context are available through the MCP OlieFlowAi.

Also read every project thread and the latest version of each one, using **Reading the project forum** in `~/git/locav/prompts/workflow-policy.md`. The card text and those thread texts together are the source of truth for the intended behavior. Before making implementation decisions, inspect the relevant codebase, existing tests, and dependencies to understand the current behavior and identify potential side effects.

## 2. Update the Card Stage

Before modifying code, load the card and its live funnel through MCP `olie-flow-ai`. Apply the stage-resolution and move procedure in `~/git/locav/prompts/workflow-policy.md`.

- If the card is still in `not-started` ('Não iniciado'), move it to `in-progress` ('Em andamento').
- If the card is already in `in-progress`, continue without moving it again.
- If the card is in another stage, do not move it automatically. Report its current stage and wait for instructions.
- Resolve the card UUID and target `step_id` from MCP / the live funnel. Use `OLIE_MANAGEMENT_TOKEN` for management HTTP auth (not the MCP token). Never hard-code ids or paste tokens.
- Verify that the stage transition succeeded before continuing.
- Do not start a project execution. The Opbed Job page (`/job`) does that (`~/git/locav/prompts/workflow-policy.md`).

## 3. Git Workflow

Before making any code changes:

1. Identify every repository the card changes and its configured base branch. Use the card when it specifies a base; otherwise use the repository's documented working branch in `~/git/locav/prompts/project.md`.
2. Check the current Git status in every affected repository. Preserve existing user changes and never overwrite, discard, or silently modify unrelated work.
3. Switch each affected repository to its base branch. If the working tree contains changes that could interfere with switching branches or updating the repository, stop and report the situation before proceeding.
4. Pull the latest changes from each base branch. If an update fails or cannot be completed safely, report the issue and wait for further instructions.
5. Build the branch name with **Card branch name** in `~/git/locav/prompts/workflow-policy.md`. Do not look for a Branch field in the card.
6. Create and switch to that branch from the updated base in every repository the card changes. Use the same name in each repository.
7. Verify every active branch before proceeding.

Do not implement the card on a base branch.

## 4. Planning Phase

Before implementing anything, analyze the card requirements and create a concrete implementation plan.

### 4.1. Codebase Investigation

Inspect the relevant application code, architecture, business rules, dependencies, and existing tests.

Identify and document:

- The code responsible for the current behavior.
- Existing code that could interfere with, override, or otherwise affect the behavior being implemented or modified.
- Dependencies, indirect effects, and potential regressions.
- Relevant edge cases, error scenarios, and integration points.
- Existing tests and gaps in test coverage.

Document the findings that are relevant to implementation and testing. Do not modify unrelated code merely to simplify the implementation.

### 4.2. Test Coverage

Before implementing the card, inspect the Cypress E2E suite at `~/git/locav/locav-front/cypress`.

Determine whether the existing tests adequately cover the current behavior and the scenarios affected by the proposed changes.

If the card changes `locav-front`, the checklist must include creating or editing Cypress specs under `cypress/e2e` for the frontend behavior the card adds or changes. Extend an existing spec when it already covers that flow; add a spec when it does not. The specs belong on the same `locav-front` branch as the UI change. Run them with **Running Cypress** in `~/git/locav/prompts/workflow-policy.md` when the stack is up.

If the card adds or edits `LocavApi` tests, those files are Pest 4, not new PHPUnit classes. When the card edits an existing PHPUnit test file, convert that file with Drift in the same change: `docker exec -w /var/www/html locav-backend vendor/bin/pest --drift <that-file>`. If the plugin is missing, `composer require pestphp/pest-plugin-drift:^4.1 --dev --no-interaction` in that container. Do not install Drift 5. Do not pass `tests/`. If Drift leaves that file as PHPUnit, finish only that file by hand and say what remained. Leave PHPUnit files the card does not touch. Pest 5 needs PHP 8.4. Do not bump PHP or PHPUnit to install it now. When the PHP version is raised, try Pest 5. Run the file with `docker exec -w /var/www/html locav-backend php artisan test --compact <test-path>`.

If tests are missing or coverage is insufficient in other repositories, add `create tests for the behavior` as an explicit item in the implementation checklist.

Do not assume that the absence of an obvious test means no relevant tests exist. Search the existing test suite and inspect related scenarios before identifying gaps.

### 4.3. Plan Documentation

Create the implementation plan in the agent's native planning mechanism. If that mechanism is unavailable, use an ignored local card-work directory rather than adding an orchestration document to a product repository. Add repository documentation only when the card itself requires it.

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

## 5. Step-by-Step Implementation

Implementation must be incremental. Use controlled mode only when the user requests step-by-step approval or the card spans multiple repositories or high-risk changes.

After presenting the plan:

1. In controlled mode, wait for the user to send 'next' and implement only the next incomplete checklist item.
2. Otherwise, implement the checklist in dependency order, reporting after each meaningful verification boundary.
3. Mark an item as complete only after its requirements have been implemented and the relevant verification has succeeded.
4. Update the plan whenever progress, findings, or implementation details change.
5. Report what changed, which files were affected, what verification was performed, and any remaining concerns.
6. In controlled mode, stop and wait for the next 'next' command before proceeding to another checklist item.

If a task reveals new requirements, unexpected dependencies, significant risks, or a need to change the plan, document the findings and present the proposed adjustment before proceeding with work that depends on that adjustment.

Do not skip checklist items, combine multiple independent items into one step, or implement subsequent items without authorization.

If an issue blocks the current item, explain the blocker and wait for instructions when resolving it requires a decision or action beyond the existing plan.

## 6. Development Issue Tracking

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


## 7. Code Quality and Validation

Follow the project's existing architecture, conventions, and established patterns. Prefer the smallest change that correctly satisfies the card's requirements.

- Avoid unrelated refactoring and unnecessary changes.
- Preserve existing behavior unless the card explicitly requires changing it.
- Image/video/audio analysis: follow `locav-project-image-analysis` / `locav-project-video-conversion`. Store at `~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md`; reuse if the file exists; **commit/push on meta-repo `~/git`**; never post to project content.
- Add or update tests to cover the intended behavior, relevant edge cases, and regressions.
- When the change touches `locav-front`, create or edit Cypress specs under `cypress/e2e` for that frontend behavior, on the same branch. Run them with **Running Cypress** in `~/git/locav/prompts/workflow-policy.md` when the environment permits.
- New or edited `LocavApi` tests are Pest 4. Convert a PHPUnit test file with Drift (`vendor/bin/pest --drift <that-file>`) only when this card edits it.
- Run appropriate tests and verification commands for the current checklist item when the environment permits.
- Clearly distinguish successful checks from checks that failed, were skipped, or could not run.
- Document any verification limitations in the plan.

**Do not run 'pint' unless the user explicitly instructs you to do so.** The pre-QA workflow is an explicit exception; follow `~/git/locav/prompts/workflow-policy.md` when it applies.

## 8. Completion Criteria

The card is complete only when all applicable checklist items have been completed and verified, including:

- The implementation satisfies the card's requirements and acceptance criteria.
- Relevant tests have been created or updated, and coverage gaps have been addressed as planned.
- If `locav-front` changed, Cypress specs under `cypress/e2e` were created or edited for that frontend behavior on the same branch.
- If `LocavApi` tests were added or edited, they are Pest 4. A PHPUnit file this card edited was converted with Drift in the same change.
- Required tests and verification checks have been run, with any remaining limitations explicitly reported.
- Relevant documentation and the implementation checklist are up to date.
- The 'Issues encountered during development' section accurately reflects resolved and unresolved issues.
- No unrelated user changes have been overwritten or included unintentionally.
- No secrets or `.env` content have been committed, pushed, or included in a pull request.

When all checklist items are complete, provide a concise final report covering the implementation, changed files, tests and verification results, unresolved issues, and any remaining manual actions.

Do not commit, push, or open a pull request unless explicitly requested and permitted by the applicable restrictions above.

When implementation work on this paste is done, the next paste is `~/git/locav/prompts/implementation-validation.md` (code-only). Do not run `~/git/locav/prompts/pre-qa.md` or board `~/git/locav/prompts/validation.md` yet.