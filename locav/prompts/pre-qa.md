# Pre-QA/CR Checklist and Pull Request Workflow

Run this **after** `~/git/locav/prompts/implementation-validation.md` has passed (code-only ready) and **before** the card moves to 'QA/CR'. Do not run this while expecting a code-only review — that is implementation-validation. Do not run board 'Validação' yet — that is `~/git/locav/prompts/validation.md` after colleague QA/CR.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Shared detail: `~/git/locav/prompts/workflow-policy.md`.

## 1. Objective

Prepare card `{{ code }}` for colleague 'QA/CR': commits, pull requests, forms, and checklist items. Code quality gates here assume implementation-validation already cleared the five code criteria.

Inspect all relevant changes across the involved repositories. Use the card's requirements and acceptance criteria as the source of truth.

Follow the checklist in order. Do not proceed to the next phase until all applicable checks in the current phase have passed.

Do not mark a check as complete unless the corresponding action has been performed and its result verified. If a check cannot be completed, document the reason and stop before proceeding to any dependent phase.

## 2. Phase 1 — Code Quality and Production Readiness

### 2.1. User Experience

- [ ] Verify that every request initiated by the user provides appropriate feedback, such as a loading indicator, progress state, or clear success/error feedback.
- [ ] Verify that duplicate submissions are prevented while a request is in progress. Consider button disabling, Enter key submission, repeated clicks, and other applicable submission paths.
- [ ] Verify that success and failure states are handled appropriately and that users are not left waiting without feedback.

### 2.2. Code Quality

- [ ] Check for `console` statements in the code. Remove unintended debugging statements and retain only those explicitly justified by the project's logging conventions.
- [ ] Check for duplicate enums, especially in `LocavApi`. Reuse existing enums where appropriate instead of introducing redundant definitions.
- [ ] Review the implementation for unnecessary duplication, regressions, edge cases, and inconsistencies with existing project conventions.
- [ ] Verify that the implementation satisfies the card's requirements and does not introduce unrelated changes.

### 2.3. UI Standards and Good Practices

- [ ] Prefer existing Radix / shadcn-style components in `locav-front` over ad-hoc dialogs or forms.
- [ ] Verify that the implementation follows the established frontend architecture, component conventions, and error-handling patterns.

### 2.4. Repository-Specific Checks

#### `LocavApi`

- [ ] Run all relevant tests using `docker exec locav-backend` (PHPUnit / Paratest as the repo supports).
- [ ] Review test results and investigate any failures instead of assuming they are unrelated to the changes.
- [ ] Run Pint to format affected PHP changes (`docker exec locav-backend ./vendor/bin/pint` or the project equivalent).
- [ ] If Pint changes files, create a dedicated commit containing only those formatting changes. Do not create an empty formatting commit.

#### `locav-front`

- [ ] Run lint: `docker exec locav-frontend bun run lint` (or the equivalent Bun command in that container).
- [ ] Resolve lint errors introduced by the changes and rerun lint to verify the result.

#### All involved repositories

- [ ] Identify every repository affected by the card, including repositories containing only tests or supporting changes.
- [ ] Run the relevant quality checks for each affected repository.
- [ ] Ensure changes are consistent across repositories and that no required repository has been overlooked.

## 3. Phase 2 — API Documentation Impact

- [ ] Determine whether the changes modify API inputs or outputs.

API inputs include, but are not limited to:

- Request data, parameters, or validation rules.
- Routes, route parameters, or route types.
- Request headers or other externally supplied data.

API outputs include, but are not limited to:

- Response data or structure.
- HTTP response status codes.
- Other externally observable response behavior.

If any API input or output changes, mark card `{{ code }}` as requiring an API documentation update.

Do not assume that a change is internal merely because it involves an existing endpoint. Evaluate its externally observable behavior.

If API documentation is required, record this explicitly in the card and report the documentation update that remains necessary. Do not claim the documentation has been updated unless it actually has been.

## 4. Phase 3 — Commit and Branch Validation

**Proceed to this phase only after all applicable checks in Phases 1 and 2 have passed.**

### 4.1. Branch Naming

- [ ] Verify that every involved repository uses exactly the branch name specified in the card content, specifically the 'Branch' field in the repository form or branch generator.
- [ ] Apply the same branch name across all involved repositories, including repositories containing only tests.
- [ ] Do not invent alternative prefixes or suffixes such as `test/`, `fix/`, or `chore/`.
- [ ] If the branch does not exist on a remote repository, create it using the exact required name and the correct base branch for that repository, such as `develop` or `master`.
- [ ] If a branch was created with an incorrect name, correct the branch name locally and remotely and update any associated pull request references as necessary.

Before renaming or deleting a remote branch, verify that it is the incorrect branch associated with this card. Preserve unrelated branches and work. If renaming or deleting the branch could affect other contributors or existing work, stop and request confirmation before performing the destructive operation.

### 4.2. Commit Validation

- [ ] Verify that all commits follow the commit convention adopted by each repository.
- [ ] Ensure commit messages are written in English.
- [ ] Ensure no commit lists Cursor as a co-author.
- [ ] Verify that the dedicated Pint formatting commit contains only formatting changes.
- [ ] Ensure functional changes, test changes, and formatting changes are separated appropriately for review.
- [ ] Review the final commit history and verify that no unrelated changes, secrets, environment files, or accidental generated files are included.

Do not rewrite or discard existing commits without evaluating their impact. If correcting the history would affect shared branches or other contributors, request confirmation first.

## 5. Phase 4 — Pull Request Creation

**Proceed only after all applicable checks in Phases 1–3 have passed.**

**Create and configure every pull request with GitHub CLI (`gh`)**. Prefer `gh` over the GitHub MCP (form deferral; weak assignee/label support). If `gh` is missing, unauthenticated, or errors, **stop and report** (prompt-health); do not silently switch to the browser. See `~/git/olie/prompts/pre-qa.md` Phase 4 for the `gh pr create` / `gh pr edit` pattern.

Push the source branch first when needed so `gh` can open the PR against a remote head.

For every required pull request:

- [ ] Create the PR via `gh pr create` with title and body in English, as required by `~/git/locav/prompts/workflow-policy.md`.
- [ ] Use the correct source branch and target branch for the repository.
- [ ] Verify that the source branch uses exactly the branch name specified in the card.
- [ ] Set Assignees to the person identified in the 'Assigned to' field of card `{{ code }}` (`gh --assignee` / `--add-assignee`).
- [ ] Set Reviewers to all available reviewers except the person identified in the 'Assigned to' field (`gh --reviewer` / `--add-reviewer`).
- [ ] Select the label that most closely matches the source branch name prefix (`gh --label` / `--add-label`).

Example: for `feature/teste-123`, select the label closest to `feature`.

- [ ] Provide a clear title and description summarizing the purpose of the changes, the relevant card, and the verification performed.
- [ ] Link the pull request to the card when supported by the repository workflow.
- [ ] Verify that the pull request exists (`gh pr view`), targets the correct base branch, and contains the intended commits.

Do not assume that a pull request was created successfully merely because a creation action was attempted. Verify its existence and configuration through `gh pr view`.

If a required reviewer, assignee, label, or other setting is unavailable, report the limitation rather than silently omitting the requirement.

## 6. Phase 5 — Card Lifecycle Update

**Proceed only after the required pull request or pull requests have been created and verified.**

- [ ] Open card `{{ code }}` through the MCP OlieFlowAi.
- [ ] Check off the funnel checklist item 'Pull request created' via management HTTP `toggle-funnel-checklist` (see `~/git/olie/prompts/workflow-policy.md` — shared policy). Use `${OLIE_MANAGEMENT_TOKEN}` and the live `step_checklist_id`; never paste a Bearer token.
- [ ] If the API documentation impact check determined that an update is required, ensure the card is marked accordingly.
- [ ] Verify that the card reflects the actual pull request status and any remaining documentation requirements.

Do not mark 'Pull request created' as complete before the relevant pull request has been verified.

Do not move the card to QA/CR automatically unless explicitly instructed to do so. Completing this checklist and updating the checklist item does not, by itself, authorize a stage transition.

## 7. Failure Handling and Reporting

If any check fails:

1. Identify the failing check and the affected repository.
2. Explain the observed problem and its impact.
3. Record the issue and the required corrective action.
4. Resolve the issue when it falls within the authorized scope of the current task.
5. Rerun the relevant checks and verify that they pass.
6. Do not proceed to a dependent phase until the issue is resolved.

Do not conceal failures, skip mandatory checks, or report unverified results as successful.

If an action requires additional permissions, involves a potentially destructive operation, or depends on a decision not covered by this prompt, stop and request the necessary authorization.

## 8. Final Report

After completing the applicable workflow, provide a concise report containing:

- The repositories checked.
- The results of PHPStan, tests, lint, and Pint, as applicable.
- The identifier of the dedicated Pint commit.
- The commit convention and branch-name validation results.
- The pull request URLs and their verified configuration.
- Whether an API documentation update is required.
- The status of the 'Pull request created' checklist item.
- Any unresolved issues, skipped checks, or outstanding actions.

Clearly distinguish completed actions from pending work. Do not claim that the card is fully ready for QA/CR if any mandatory check remains unresolved.
