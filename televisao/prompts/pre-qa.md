# Pre-QA/CR Checklist and Pull Request Workflow

Run this **after** `~/git/televisao/prompts/implementation-validation.md` has passed (code-only ready). If that pass reported a backend (`televisao-api`) change, run `~/git/televisao/prompts/mutation-testing.md` first (personal stack); then this prompt (`next prompt` is enough). If there was no backend change, come here directly after implementation-validation. Chat commands: `~/git/televisao/prompts/workflow-policy.md` → **Chat commands**. This prompt prepares the handoff and, when every applicable check has passed, **moves the card to 'QA/CR'**. Do not run this while expecting a code-only review — that is implementation-validation. Do not run board 'Validação' yet — that is `~/git/televisao/prompts/validation.md` after colleague QA/CR.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/televisao/prompts/workflow-policy.md`.

## 1. Objective

Prepare card `{{ code }}` for colleague 'QA/CR': commits, pull requests, forms, and the board move to 'QA/CR' when everything required is verified. Code quality gates here assume implementation-validation already cleared the five code criteria.

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
- [ ] Check for duplicate enums, especially in `televisao-api`. Reuse existing enums where appropriate instead of introducing redundant definitions.
- [ ] Review the implementation for unnecessary duplication, regressions, edge cases, and inconsistencies with existing project conventions.
- [ ] Verify that the implementation satisfies the card's requirements and does not introduce unrelated changes.

### 2.3. UI Standards and Good Practices

- [ ] Prefer components the front already uses over ad-hoc dialogs or forms.
- [ ] Verify that the implementation follows the established frontend architecture, component conventions, and error-handling patterns.

### 2.4. Repository-Specific Checks

#### `televisao-api`

- [ ] Run the tests this card touched: `docker exec -w /var/www/html televisao-backend php artisan test --compact` with those paths. When Pest is installed, new or edited `televisao-api` tests use that Pest. A PHPUnit file this card edited was converted with Drift (`vendor/bin/pest --drift <that-file>`) in the same change. Untouched PHPUnit files stay as they are. If Pest or Drift is not installed, do not add them; run the existing runner and say so.
- [ ] Review test results and investigate any failures instead of assuming they are unrelated to the changes.
- [ ] Run Pint to format affected PHP changes (`docker exec televisao-backend ./vendor/bin/pint` or the project equivalent).
- [ ] If Pint changes files, create a dedicated commit containing only those formatting changes. Do not create an empty formatting commit.

#### `televisao-front` and `televisao-meet-front`

- [ ] Run the lint script that repository already has. Do not assume Bun or a container named `televisao-frontend`. If the command is unknown, stop and report.
- [ ] Resolve lint errors introduced by the changes and rerun lint to verify the result.
- [ ] A Playwright spec in the matching meta-repo suite (`televisao-front-e2e` or `televisao-meet-front-e2e`) was created or edited for the frontend behavior this card changes. Extend an existing spec when it already covers that flow.
- [ ] Run the affected specs with **Running Playwright** in `~/git/televisao/prompts/workflow-policy.md`. Investigate failures instead of treating them as unrelated.

#### `televisao-meet-core`

- [ ] Run the checks that repository already has for the files this card changed. If none are documented, say so. Do not invent a runner.

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

- [ ] Verify that every involved repository uses the branch name built in **Card branch name** in `~/git/televisao/prompts/workflow-policy.md`. Televisão does not store that name in a Branch field on the card.
- [ ] Apply that same built name across all involved repositories, including repositories containing only tests.
- [ ] Do not invent alternative prefixes or suffixes such as `test/`, `fix/`, or `chore/`.
- [ ] If the branch does not exist on a remote repository, create it with the built name from the repository base in `~/git/televisao/prompts/project.md` (`preview`).
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

### 4.3. Meta-repo (`~/git`) — commit and push on `main`

Product clones get card branches and PRs. The **meta-repo** does not: ship its card-related changes straight to `main`.

This pre-QA pass **must** commit and push meta-repo updates that belong to the card (or to prompt/workflow fixes done in the same chat), when the working tree has any:

- `televisao/prompts/` (including `mutation-ledger.md`)
- `televisao/cards/{CARD_CODE}/` media analyses
- `televisao/televisao-front-e2e/` / `televisao/televisao-meet-front-e2e/` specs or helpers added for the card
- `HISTORICO.md` / other meta-repo docs touched for the same work

Do **not** open a pull request for `~/git`. Do **not** invent a card branch on the meta-repo.

Checklist:

- [ ] `cd ~/git` and confirm the current branch is `main` (or the meta-repo’s default). If not, stop and report.
- [ ] `git pull --ff-only` (or fetch + ff-only merge) so local `main` matches `origin/main` before committing. On divergence or non-ff, stop and report (prompt-health).
- [ ] Stage only paths that belong to this work. Exclude secrets, `.env`, WorkVM stubs (`mcp.workvm-user`, skip-worktree noise), and unrelated dirty files. If unrelated dirt blocks a clean commit, stop and report rather than mixing it in.
- [ ] Create one or more English commits (no Cursor/AI co-author). Message says why (card code when applicable).
- [ ] `git push origin HEAD` to update remote `main`. Verify with `git status` that the branch is not ahead/behind after the push.
- [ ] If there is nothing to commit for the meta-repo, say so explicitly in the final report.

If commit or push fails, stop before Phase 4 product PRs when the meta-repo change is required for the card (e.g. e2e or media analysis). Prompt-only / ledger updates should still be pushed when possible; if push fails, report and do not claim meta-repo is synced.

## 5. Phase 4 — Pull Request Creation

**Proceed only after all applicable checks in Phases 1–3 have passed.**

**Create and configure every pull request with GitHub CLI (`gh`)**. Prefer `gh` over the GitHub MCP (form deferral; weak assignee/label support). If `gh` is missing, unauthenticated, or errors, **stop and report** (prompt-health); do not silently switch to the browser. See `~/git/olie/prompts/pre-qa.md` Phase 4 for the `gh pr create` / `gh pr edit` pattern.

Push the source branch first when needed so `gh` can open the PR against a remote head.

For every required pull request:

- [ ] Create the PR via `gh pr create` with an English title and a body that is the filled `.github/pull_request_template.md` of that repository (**Pull request body** in `~/git/televisao/prompts/workflow-policy.md`).
- [ ] Use the correct source branch and target branch for the repository.
- [ ] Verify that the source branch is the name built in **Card branch name** in `~/git/televisao/prompts/workflow-policy.md`.
- [ ] Set Assignees to the person identified in the 'Assigned to' field of card `{{ code }}` (`gh --assignee` / `--add-assignee`).
- [ ] Set Reviewers to the people in the **Revisor(es)** answer, using **Code review form** in `~/git/televisao/prompts/workflow-policy.md` (`gh --reviewer` / `--add-reviewer`).
- [ ] Select the label that most closely matches the source branch name prefix (`gh --label` / `--add-label`).

Example: for `feature/teste-123`, select the label closest to `feature`.

- [ ] Fill every section of that template: card link, related PRs, technical description, open points, and the checklists. Check a box only when that item was done.
- [ ] After every required PR exists, `gh pr edit` each body so **PR(s) relacionados** has the other PR URL. If this card changes only one repository, mark **Não se aplica**.
- [ ] Verify that the pull request exists (`gh pr view`), targets the correct base branch, contains the intended commits, and the body still has the template headings, the card link, and the related PR URL when one exists.
- [ ] After those PRs are verified, write **Pull Request (front)** and **Pull Request (back)** with `set-form-answers-tool`, using **Code review form** in `~/git/televisao/prompts/workflow-policy.md`. Read the fields back and confirm the stored URLs.

Do not assume that a pull request was created successfully merely because a creation action was attempted. Verify its existence and configuration through `gh pr view`.

If a **Revisor(es)** name does not match exactly one collaborator, do not add that reviewer (**Code review form** in `~/git/televisao/prompts/workflow-policy.md`). If an assignee, label, or other required setting is unavailable, report the limitation rather than silently omitting it.

## 6. Phase 5 — Card Lifecycle Update

**Proceed only after the required pull request or pull requests have been created and verified, and all applicable checks in Phases 1–4 have passed.**

- [ ] Open card `{{ code }}` through the MCP OlieFlowAi.
- [ ] If the API documentation impact check determined that an update is required, ensure the card is marked accordingly.
- [ ] Verify that the card reflects the actual pull request status and any remaining documentation requirements.
- [ ] Move the card to the live funnel step whose display name matches 'QA/CR' (logical `quality-review`), using `~/git/televisao/prompts/workflow-policy.md` (prefer MCP move; HTTP fallback with `${OLIE_MANAGEMENT_TOKEN}`). Resolve the step id from the live funnel — never hard-code it.
- [ ] Verify the card's current stage is 'QA/CR' after the move.

The Televisão funnel has no step checklists. 'Pull request created' exists only on the Olie funnel. Do not call `toggle-funnel-checklist` for a Televisão card.

Do not move to 'QA/CR' if any mandatory check from Phases 1–4 (or earlier items in this phase) failed, was skipped, or remains unresolved. If the move fails, stop and report (prompt-health); do not claim the handoff is complete.

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

- The repositories checked (product clones and meta-repo).
- The results of PHPStan, tests, lint, and Pint, as applicable.
- The identifier of the dedicated Pint commit.
- The commit convention and branch-name validation results.
- Meta-repo: commit hash(es) on `main`, whether `origin/main` was updated, or that there was nothing to commit.
- The pull request URLs and their verified configuration, including the filled template body and the **Pull Request (front)** and **Pull Request (back)** values read back from the card.
- Whether an API documentation update is required.
- Whether the card was moved to 'QA/CR' and the verified stage after the move.
- Any unresolved issues, skipped checks, or outstanding actions.

Clearly distinguish completed actions from pending work. Do not claim that the card is fully ready for QA/CR if any mandatory check remains unresolved or the stage move did not succeed.
