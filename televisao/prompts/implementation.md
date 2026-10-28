# Card Development Workflow

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/televisao/prompts/workflow-policy.md`.

### Chat commands

Recognize these user messages in this develop flow (shared table: `~/git/televisao/prompts/workflow-policy.md` → **Chat commands**). Distinct from checklist `next` in §5.

| Command | Do this |
| --- | --- |
| `next prompt` | Run the next recommended prompt file (after this paste finishes: `~/git/televisao/prompts/recommendation.md`). Open that file and execute it; do not wait for another paste. |
| `try again` | Resume or re-run **this** implementation prompt after a stop or a manual fix. Continue from the blocked checklist item when safe. |
| `to correct` | Only after implementation-validation reported **Needs code fixes**: implement those listed failures, then recommend re-running validation. If validation has not failed yet, say so and do not invent a correction list. |

## 1. Context and Objective

Implement the card identified by `{{ code }}`. Its requirements, business rules, dependencies, and implementation context are available through the MCP OlieFlowAi.

Also read every project thread and the latest version of each one, using **Reading the project forum** in `~/git/televisao/prompts/workflow-policy.md`. The card text and those thread texts together are the source of truth for the intended behavior. Before making implementation decisions, inspect the relevant codebase, existing tests, and dependencies to understand the current behavior and identify potential side effects.

### Card media review (required before the plan)

Before the planning phase, **review the card's media**. Spec screenshots, screencasts, and attachments are part of the source of truth — do not plan from text alone when media shows the intended UI or flow.

1. `git pull` the meta-repo if needed, then list media via MCP (`get-project-media-tool`).
2. For each image, video, or audio item that belongs to this card and is part of the specification (or is cited by the description):
   - If `~/git/televisao/cards/{CARD_CODE}/{MEDIA_ID}.md` exists and is non-empty → **Read** it. Do not re-analyze.
   - If that file is **missing** → analyze now: `televisao-project-image-analysis` for images, `televisao-project-video-conversion` for video (API first; agent-local fallback when vid2agent is unreachable). Write the `.md` under `~/git/televisao/cards/{CARD_CODE}/`.
3. Re-analyze or call vid2agent again **only** when the user asks to redo a specific media id (overwrite that file).
4. Use those analyses in the plan and checklist. Cite the media id when a requirement comes from a screenshot or screencast.
5. **Never** post image, video, or audio analysis to project content (`save-media-tool` or any MCP write of that markdown).
6. After writing **new** analysis files, commit and push them on the meta-repo `~/git` when you finish this media pass (or when the user asks).

## 2. Update the Card Stage

Before modifying code, load the card and its live funnel through MCP `olie-flow-ai`. Apply the stage-resolution and move procedure in `~/git/televisao/prompts/workflow-policy.md`.

- If the card is still in `not-started` ('Não Iniciado'), move it to `in-progress` ('Em andamento').
- If the card is already in `in-progress`, continue without moving it again.
- If the card is in another stage, do not move it automatically. Report its current stage and wait for instructions.
- Resolve the card UUID and target `step_id` from MCP / the live funnel. Use `OLIE_MANAGEMENT_TOKEN` for management HTTP auth (not the MCP token). Never hard-code ids or paste tokens.
- Verify that the stage transition succeeded before continuing.
- Do not start a project execution. The Opbed Job page (`/job`) does that (`~/git/televisao/prompts/workflow-policy.md`).

## 3. Git Workflow

Before making any code changes:

1. Identify every repository the card changes and its configured base branch. Use the card when it specifies a base; otherwise use the repository's documented working branch in `~/git/televisao/prompts/project.md`.
2. Check the current Git status in every affected repository. Preserve existing user changes and never overwrite, discard, or silently modify unrelated work.
3. Switch each affected repository to its base branch. If the working tree contains changes that could interfere with switching branches or updating the repository, stop and report the situation before proceeding.
4. Pull the latest changes from each base branch. If an update fails or cannot be completed safely, report the issue and wait for further instructions.
5. Build the branch name with **Card branch name** in `~/git/televisao/prompts/workflow-policy.md`. Do not look for a Branch field in the card.
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

Before implementing the card, inspect the Playwright suites at `~/git/televisao/televisao-front-e2e` and `~/git/televisao/televisao-meet-front-e2e`.

Determine whether the existing tests adequately cover the current behavior and the scenarios affected by the proposed changes.

If the card changes `televisao-front` or `televisao-meet-front`, the checklist must include creating or editing a Playwright spec in the matching meta-repo suite for the frontend behavior the card adds or changes. Extend an existing spec when it already covers that flow; add a spec when it does not. Specs stay in the meta-repo. Run them with **Running Playwright** in `~/git/televisao/prompts/workflow-policy.md` when the stack is up.

If the card adds or edits `televisao-api` tests and `vendor/bin/pest` exists, those files use that Pest, not new PHPUnit classes. When the card edits an existing PHPUnit test file, convert that file with Drift in the same change: `docker exec -w /var/www/html televisao-backend vendor/bin/pest --drift <that-file>`. Do not pass `tests/`. If Drift leaves that file as PHPUnit, finish only that file by hand and say what remained. Leave PHPUnit files the card does not touch. If Pest or Drift is not already installed, stop and report. Do not install them. Run the file with `docker exec -w /var/www/html televisao-backend php artisan test --compact <test-path>`.

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
- Image/video/audio analysis: follow **Card media review** in §1 (skills `televisao-project-image-analysis` / `televisao-project-video-conversion`).
- Add or update tests to cover the intended behavior, relevant edge cases, and regressions.
- When the change touches `televisao-front` or `televisao-meet-front`, create or edit a Playwright spec in the matching meta-repo suite. Run it with **Running Playwright** in `~/git/televisao/prompts/workflow-policy.md` when the environment permits.
- When `vendor/bin/pest` exists, new or edited `televisao-api` tests use that Pest. Convert a PHPUnit test file with Drift (`vendor/bin/pest --drift <that-file>`) only when this card edits it and Drift is already installed.
- Run appropriate tests and verification commands for the current checklist item when the environment permits.
- Clearly distinguish successful checks from checks that failed, were skipped, or could not run.
- Document any verification limitations in the plan.
- When the card has a report, reproduce that problem on the hosted preview in the next section. Local `localhost` does not stand in for that check.

**Do not run 'pint' unless the user explicitly instructs you to do so.** The pre-QA workflow is an explicit exception; follow `~/git/televisao/prompts/workflow-policy.md` when it applies.

### Hosted preview when the card has a report

A report is a problem described on the card, in a project thread, or in attached media. That problem was seen on the hosted preview. Reproduce it there before treating the reported behavior as verified. Implementation and Playwright still run against the local stack in `~/git/televisao/prompts/project.md`.

| Surface | URL |
| --- | --- |
| Dashboard | `https://televisao.dashboard.enterscience.com.br/` |
| Meet | `https://televisao-meet-front.dashboard.enterscience.com.br/meet/enterscience` |

| Account | Password |
| --- | --- |
| `admin@enterscience.com.br` | `Juca@1234` |
| `superadmin@televisao.com` | `123123` |

Use these accounts only. Leave the passwords out of the plan, the final report, commits, and pull requests.

## 8. Completion Criteria

The card is complete only when all applicable checklist items have been completed and verified, including:

- The implementation satisfies the card's requirements and acceptance criteria.
- Relevant tests have been created or updated, and coverage gaps have been addressed as planned.
- If `televisao-front` or `televisao-meet-front` changed, a Playwright spec in the matching meta-repo suite was created or edited for that frontend behavior.
- If `televisao-api` tests were added or edited and Pest is installed, they use that Pest. A PHPUnit file this card edited was converted with Drift in the same change.
- Required tests and verification checks have been run, with any remaining limitations explicitly reported.
- When the card has a report, that problem was reproduced on the hosted preview.
- Relevant documentation and the implementation checklist are up to date.
- The 'Issues encountered during development' section accurately reflects resolved and unresolved issues.
- No unrelated user changes have been overwritten or included unintentionally.
- No secrets or `.env` content have been committed, pushed, or included in a pull request.

When all checklist items are complete, provide a concise final report covering the implementation, changed files, tests and verification results, unresolved issues, and any remaining manual actions.

Do not commit, push, or open a pull request unless explicitly requested and permitted by the applicable restrictions above.

When implementation work on this paste is done, the next recommended prompt is `~/git/televisao/prompts/recommendation.md` (related improvements only; do not implement them in that paste). The user may send `next prompt` to run it without pasting. After recommendation, the handoff continues with `implementation-validation.md` (code-only). Do not run `~/git/televisao/prompts/pre-qa.md` or board `~/git/televisao/prompts/validation.md` yet.