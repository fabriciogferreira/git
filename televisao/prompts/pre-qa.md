# Pre-QA/CR Checklist and Pull Request Workflow

Run this **after** `~/git/televisao/prompts/pest-parallel.md` when `televisao-api` changed, or after `implementation-validation.md` when there is no backend. Own-card backend order: gap → coverage → mutation → Pest parallel → this prompt. Chat commands: `~/git/televisao/prompts/workflow-policy.md` → **Chat commands**. 

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/televisao/prompts/workflow-policy.md`.

**Re-run budget:** do not re-run a completed phase on an unchanged tree “to confirm”. Re-enter a phase only after a fix, a failed check, or a new commit/PR state. Shared rule: **Expensive re-run budget** in `workflow-policy.md`.

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
- [ ] Check the branch diff for temporary or debug comments introduced by this work (`<!--`, `//`, `/*`, `#`, and equivalents). Remove those leftovers; do not strip pre-existing explanatory comments unrelated to this card.
- [ ] Check for duplicate enums, especially in `televisao-api`. Reuse existing enums where appropriate instead of introducing redundant definitions.
- [ ] Review the implementation for unnecessary duplication, regressions, edge cases, and inconsistencies with existing project conventions.
- [ ] Verify that the implementation satisfies the card's requirements and does not introduce unrelated changes.

### 2.3. UI Standards and Good Practices

- [ ] Prefer components the front already uses over ad-hoc dialogs or forms.
- [ ] Verify that the implementation follows the established frontend architecture, component conventions, and error-handling patterns.
- [ ] Do not change layout or styling unless the card asks for it. Unrelated visual diffs are a fail for this phase.

### 2.4. Repository-Specific Checks

#### `televisao-api`

- [ ] Run the tests this card touched: `docker exec -w /srv televisao-backend php artisan test --compact` with those paths. When Pest is installed, new or edited `televisao-api` tests use that Pest. A PHPUnit file this card edited was converted with Drift (`vendor/bin/pest --drift <that-file>`) in the same change. Untouched PHPUnit files stay as they are. If Pest or Drift is not installed, do not add them; run the existing runner and say so.
- [ ] Review test results and investigate any failures instead of assuming they are unrelated to the changes.
- [ ] Run Pint to format affected PHP changes (`docker exec televisao-backend ./vendor/bin/pint` or the project equivalent).
- [ ] If Pint changes files, create a dedicated commit containing only those formatting changes. Do not create an empty formatting commit.
- [ ] If this card changed API inputs/outputs (or Scribe annotations), run `php artisan scribe:generate --force -n` in the API container (**Scribe** in `~/git/televisao/prompts/workflow-policy.md`). Confirm the regenerated docs include the changed endpoints.
- [ ] If Scribe changed tracked generated files (`.scribe/`, `resources/views/scribe/`, `public/vendor/scribe/`, …), create a dedicated commit containing only those generated paths. Do not create an empty Scribe commit. Do not mix them with feature, test, or Pint commits.

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

If any API input or output changes, the card requires an API documentation update via Scribe (source annotations + `scribe:generate`). See **Scribe** in `~/git/televisao/prompts/workflow-policy.md`.

Do not assume that a change is internal merely because it involves an existing endpoint. Evaluate its externally observable behavior.

If documentation was required: annotate the controller/FormRequests, run `scribe:generate`, and keep the dedicated Scribe commit (Phase 1 / Phase 3). Record on the card only when the regenerate or that commit is still missing — do not leave “docs still needed” after a successful generate+commit. Do not claim documentation is done unless generate ran and the dedicated commit (when files changed) exists.

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
- [ ] Verify that the dedicated Scribe commit (when required) contains only Scribe-generated paths.
- [ ] Ensure functional changes, test changes, formatting changes, and Scribe-generated docs are separated appropriately for review.
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

**Create and configure every pull request with GitHub CLI (`gh`)**. This is the documented exception to **Tool preference** (MCP → `gh` → curl) in `~/git/televisao/prompts/workflow-policy.md`: pre-QA create uses `gh` first (GitHub MCP App form deferral; weak assignee/label support). If `gh` is missing, unauthenticated, or errors, **stop and report** (prompt-health); do not silently switch to the browser. See `~/git/olie/prompts/pre-qa.md` Phase 4 for the `gh pr create` / `gh pr edit` pattern.

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
- [ ] Do **not** mention `televisao-*-e2e`, meta-repo Playwright paths, or “e2e added in the meta-repo” in the PR title/body (private suite — **Running Playwright** in `workflow-policy.md`).
- [ ] After every required PR exists, `gh pr edit` each body so **PR(s) relacionados** has the other PR URL. If this card changes only one repository, mark **Não se aplica**.
- [ ] Verify that the pull request exists (`gh pr view`), targets the correct base branch, contains the intended commits, and the body still has the template headings, the card link, and the related PR URL when one exists.
- [ ] After those PRs are verified, write **Pull Request (front)** and **Pull Request (back)** with `set-form-answers-tool`, using **Code review form** in `~/git/televisao/prompts/workflow-policy.md`. Read the fields back and confirm the stored URLs.
- [ ] If this card also opened PRs for repositories without a matching form field (e.g. `televisao-meet-front`, `televisao-meet-core`), append those URLs to the project content per **PRs without a form field** in `~/git/televisao/prompts/workflow-policy.md`.

Do not assume that a pull request was created successfully merely because a creation action was attempted. Verify its existence and configuration through `gh pr view`.

If a **Revisor(es)** name does not match exactly one collaborator, do not add that reviewer (**Code review form** in `~/git/televisao/prompts/workflow-policy.md`). If an assignee, label, or other required setting is unavailable, report the limitation rather than silently omitting it.

## 6. Phase 5 — Card Lifecycle Update

**Proceed only after the required pull request or pull requests have been created and verified, and all applicable checks in Phases 1–4 have passed.**

### 5.0. Prior review feedback closed (return to 'QA/CR')

When this card is returning to 'QA/CR' after a review bounce (correction / `CHANGES_REQUESTED`), close the GitHub feedback loop **here** — **after** `implementation-validation` (and gap → coverage → mutation → Pest parallel when the API changed), and **before** the board move. Do **not** Resolve or audit during `correction.md`; that paste only drafts the checklist. Shared rules: **Closing PR review feedback** in `~/git/televisao/prompts/workflow-policy.md` (and `correction.md` §8b).

- [ ] Tip that will be audited is committed and pushed (SHAs in the audit must exist on the remote PR head).
- [ ] For each associated open PR: load inline **threads** and **reviews** (`get_review_comments` + `get_reviews`). Do not treat empty threads as “no feedback” if a review body still lists blockers. Prefer the draft checklist from the correction report when present.
- [ ] Every fully addressed inline thread is marked **Resolved** on GitHub.
- [ ] Every fully addressed **review body** (no Resolve button) has a public **audit comment** on that PR that lists each point as done / deferred / non-issue with commit evidence. Do **not** dismiss the review to fake closure.
- [ ] If a blocker from the latest `CHANGES_REQUESTED` is still open, **stop** — do not move to 'QA/CR'.

Skip this subsection only when there was no prior PR review feedback to close (first handoff to 'QA/CR' with no `CHANGES_REQUESTED` / open threads).

- [ ] Open card `{{ code }}` through the MCP OlieFlowAi.
- [ ] If the API documentation impact check determined that an update is required, verify Scribe was regenerated and the dedicated Scribe commit exists when generated files changed; only mark the card as still needing docs when that work remains incomplete.
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
- The results of PHPStan, tests, lint, Pint, and Scribe, as applicable.
- The identifier of the dedicated Pint commit (or that Pint made no changes).
- The identifier of the dedicated Scribe commit (or that Scribe was not required / made no tracked changes).
- The commit convention and branch-name validation results.
- Meta-repo: commit hash(es) on `main`, whether `origin/main` was updated, or that there was nothing to commit.
- The pull request URLs and their verified configuration, including the filled template body and the **Pull Request (front)** and **Pull Request (back)** values read back from the card.
- Whether an API documentation update was required and whether Scribe regenerate + dedicated commit completed.
- Whether the card was moved to 'QA/CR' and the verified stage after the move.
- Whether prior PR review threads were Resolved and/or review-body audit comments were posted (or that §5.0 was skipped because there was no prior review feedback).
- Any unresolved issues, skipped checks, or outstanding actions.

Clearly distinguish completed actions from pending work. Do not claim that the card is fully ready for QA/CR if any mandatory check remains unresolved or the stage move did not succeed.

### Evidence table (required)

After the final report above, post the **Implementation** (or **{N}º Correção** when this pre-QA returns a card from Corrigir) evidence table into the **card content** via `save-media-tool` per **Evidence table on project content** in `~/git/televisao/prompts/workflow-policy.md` (never description, Caderno, or PR). Use Front/Back rows only for surfaces touched; mutation/coverage/all-test % on diff `A..B` excluding Pint and dedicated Scribe commits. E2E row: `verificado localmente` only — never name private Playwright suites.
