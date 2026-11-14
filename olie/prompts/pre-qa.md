# Pre-QA/CR Checklist and Pull Request Workflow

Run this **after** `~/git/olie/prompts/implementation-validation.md` has passed (code-only ready). If that pass reported a backend (`api-main`) change, finish the personal stacks first: (1) `~/git/olie/prompts/mutation-testing.md` — every changed `*Test.php` has a `100%` / `equivalent` row in `mutation-ledger.md` (or the user explicitly stopped/skipped mutation); (2) `~/git/olie/prompts/coverage-testing.md` — every changed `app/**/*.php` has a done row in `coverage-ledger.md` (or the user explicitly stopped/skipped coverage; empty `app/` change set counts as done). If mutation still has remaining files, **stop** and tell the user to send `next mutation` or `correct mutations`. If coverage still has remaining files, **stop** and tell the user to send `next coverage` or `correct coverages`. If there was no backend change, come here directly after implementation-validation. Chat commands: `~/git/olie/prompts/workflow-policy.md` → **Chat commands**. This prompt prepares the handoff and, when every applicable check has passed, **moves the card to 'QA/CR'**. Do not run this while expecting a code-only review — that is implementation-validation. Do not run board 'validação' yet — that is `~/git/olie/prompts/validation.md` after colleague QA/CR.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

## 1. Objective

Prepare card `{{ code }}` for colleague 'QA/CR': commits, pull requests, forms, checklist items, and the board move to 'QA/CR' when everything required is verified. Code quality gates here assume implementation-validation already cleared the five code criteria.

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
- [ ] Check for duplicate enums, especially in `api-main`. Reuse existing enums where appropriate instead of introducing redundant definitions.
- [ ] Review the implementation for unnecessary duplication, regressions, edge cases, and inconsistencies with existing project conventions.
- [ ] Verify that the implementation satisfies the card's requirements and does not introduce unrelated changes.

### 2.3. UI Standards and Good Practices

- [ ] Ensure Bootstrap modals and PrimeVue dialogs have fixed width and height. Their dimensions must not vary according to content, although width may adapt to the viewport.
- [ ] Use `useLocalStorage` instead of the native JavaScript `localStorage` API when working with local storage in the relevant frontend code, following the existing project conventions.
- [ ] Verify that the implementation follows the established frontend architecture, component conventions, and error-handling patterns.

### 2.4. Repository-Specific Checks

#### `api-main`

- [ ] Verify that PHPStan checks pass.
- [ ] Run all relevant tests in parallel using the repository's supported test execution method.
- [ ] Review test results and investigate any failures instead of assuming they are unrelated to the changes.
- [ ] Run Pint to format affected PHP changes.
- [ ] If Pint changes files, create a dedicated commit containing only those formatting changes. Do not create an empty formatting commit.

#### Frontend management application

- [ ] Run the lint command:

  `docker container exec -i olie-front-management yarn lint`

- [ ] Resolve lint errors introduced by the changes and rerun lint to verify the result.

#### `olie-fronts`

- [ ] Do not edit `en.json`. English translations are resolved later. New or changed UI keys must be in `pt-br.json` only; do not add or sync English strings in this pass.

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

- [ ] Verify that every involved repository uses exactly the branch name specified in the Olie card content, specifically the 'Branch' field in the repository form or branch generator.
- [ ] Apply the same branch name across all involved repositories, including repositories containing only tests.
- [ ] Do not invent alternative prefixes or suffixes such as `test/`, `fix/`, or `chore/`.
- [ ] If the branch does not exist on a remote repository, create it using the exact required name and the correct base branch for that repository, such as `develop` or `master`.
- [ ] If a branch was created with an incorrect name, correct the branch name locally and remotely and update any associated pull request references as necessary.

Before renaming or deleting a remote branch, verify that it is the incorrect branch associated with this card. Preserve unrelated branches and work. If renaming or deleting the branch could affect other contributors or existing work, stop and request confirmation before performing the destructive operation.

### 4.2. Commit Validation

Vague “follows convention” is not enough. OS-556 returned from Validação because CI failed **Lint commit messages** while product lint was green. Every commit on the card branch that will land in a PR must pass the **same** local validator the repository’s GitHub Action runs. Do this **before** Phase 4 (`gh pr create` / push that updates an open PR).

#### Hard rules (all product repos)

- Header shape: `<type>(<optional-scope>): <description>` (Conventional Commits).
- Types in English lowercase (`feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `build`, `perf`, `style`, `revert`, … — match that repo’s allow-list).
- Description in English; **subject must not end with a full stop / period** (`.`). This is `subject-full-stop` in olie-fronts commitlint and `descriptionEndMark: ""` in api-main CaptainHook.
- No Cursor / AI co-author trailers (`Co-Authored-By`, “Generated with”, session links, or variants).
- Merge commits may be skipped by CI; do not invent merge commits to bypass lint.
- Dedicated Pint formatting commit (api-main): formatting only; no empty formatting commit.
- Separate functional, test, and formatting commits when that helps review.
- No secrets, `.env`, or accidental generated files in the history.

#### Run the repo’s CI-equivalent linter on the PR range

Identify `BASE` (usually `origin/develop`) and `HEAD` of the card branch. Lint **every** non-merge commit in `BASE..HEAD` (or the PR base/head SHAs once the PR exists).

**`olie-fronts`** — CI job **Lint commit messages** in `.github/workflows/ci.yml` (`yarn commitlint --from <base> --to <head> --verbose`). Local hook: `.husky/commit-msg` → `yarn commitlint --edit`. Config: `commitlint.config.js` extends `@commitlint/config-conventional` (body/footer line length disabled; header rules still apply — including **no trailing `.` on the subject**).

- [ ] From the monorepo root inside the front container (same pattern as Phase 1 lint):

  ```bash
  docker container exec -i olie-front-management yarn commitlint \
    --from "$BASE_SHA" --to "$HEAD_SHA" --verbose
  ```

  If git history is missing in the container, run the equivalent on the host: `./node_modules/.bin/commitlint --from "$BASE_SHA" --to "$HEAD_SHA" --verbose` from `~/git/olie/olie-fronts`.

- [ ] Exit code must be **0**. On failure: fix the message (amend only when safe / authorized; otherwise `git rebase` and reword — request confirmation if the branch is shared), then re-run until green. Do **not** open or update the PR as “ready” while this fails.

**`api-main`** — CI workflow `.github/workflows/conventional-commits.yml` runs `vendor/bin/captainhook hook:commit-msg` per commit (same as local commit-msg via `captainhook.json` → `Ramsey\CaptainHook\ValidateConventionalCommit`, including empty `descriptionEndMark` — subject must not end with `.`).

- [ ] From `~/git/olie/api-main`, for each non-merge SHA in `$BASE_SHA..$HEAD_SHA` (mirror the workflow loop):

  ```bash
  msg=$(mktemp)
  git log -1 --format='%B' "$SHA" > "$msg"
  docker exec -i olie-api-main bash -c 'cat > /tmp/commit-msg && vendor/bin/captainhook hook:commit-msg /tmp/commit-msg' < "$msg"
  rm -f "$msg"
  ```

- [ ] Exit code must be **0** for every SHA. Fix and re-validate before Phase 4.

**Other product repos** with a commit-msg CI job or husky/CaptainHook config: run that tool the same way. If a repo has no commit linter, still apply the hard rules above and say so in the report.

#### After push / open PR

- [ ] Confirm the GitHub check that lints commits is **success** for the PR head (olie-fronts: **Lint commit messages**; api-main: **Conventional Commits** / `lint-commits`). Product **Lint** / PHPStan green is not a substitute.
- [ ] Ensure commit messages are written in English.
- [ ] Ensure no commit lists Cursor as a co-author.
- [ ] Verify that the dedicated Pint formatting commit contains only formatting changes.
- [ ] Ensure functional changes, test changes, and formatting changes are separated appropriately for review.
- [ ] Review the final commit history and verify that no unrelated changes, secrets, environment files, or accidental generated files are included.

Do not rewrite or discard existing commits without evaluating their impact. If correcting the history would affect shared branches or other contributors, request confirmation first.

Do not mark Phase 3 complete if local commitlint/CaptainHook failed or the PR’s commit-lint check is red/pending with a known message violation. Stop, fix, re-verify.

### 4.3. Meta-repo (`~/git`) — commit and push on `main`

Product clones get card branches and PRs. The **meta-repo** does not: ship its card-related changes straight to `main`.

This pre-QA pass **must** commit and push meta-repo updates that belong to the card (or to prompt/workflow fixes done in the same chat), when the working tree has any:

- `olie/prompts/` (including `mutation-ledger.md`)
- `olie/cards/{CARD_CODE}/` media analyses
- `olie/olie-e2e/` specs or helpers added for the card (commit them here; do **not** name this suite in product PR bodies or card/Caderno notes — **Private E2E suites**)
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

**Create and configure every pull request with GitHub CLI (`gh`)**. This is the documented exception to **Tool preference** (MCP → `gh` → curl) in `~/git/olie/prompts/workflow-policy.md`: pre-QA **create/edit** uses `gh` first (MCP App form deferral blocks create/update; weak assignee/label support on write). If `gh` is missing, unauthenticated, or errors, **stop and report** (prompt-health); do not silently switch to the browser UI. GitHub MCP is optional fallback for **writes** only when `gh` cannot run and the user explicitly authorizes it.

**Read vs write on GitHub in this phase** (same rule as **GitHub reads vs writes** in `workflow-policy.md`):

- **Before create — discovery via GitHub MCP only:** who is logged in (`get_me`), recent PRs / label patterns (`list_pull_requests` / `search_pull_requests` / `get_label`), collaborator or user lookups to map card 'Assigned to' → GitHub login. Do **not** run shell `gh auth status`, `gh pr list`, or `gh api user` just to gather that information (Auto-review will prompt; MCP reads are the allowed path).
- **`gh` for the write:** `git push` (when the branch must land remotely) and `gh pr create` / `gh pr edit` for assignee, reviewers, and label. An Auto-review approval on those writes is expected and correct.
- After create, prefer GitHub MCP to **verify** the PR (`pull_request_read` / equivalent). Use `gh pr view` only if MCP cannot confirm existence/base/head.

Push the source branch first when needed so `gh` can open the PR against a remote head.

```bash
gh pr create --repo <owner>/<repo> --base <base> --head <branch> \
  --title "<English title>" --body "$(cat <<'EOF'
...
EOF
)" \
  --assignee <github-login> \
  --reviewer <login1>,<login2> \
  --label <label>
```

For an already-open PR: `gh pr edit <n> --add-assignee … --add-reviewer … --add-label …`.

For every required pull request:

- [ ] Resolve assignee GitHub login(s), reviewer logins, and the label name via **GitHub MCP** (and the card's 'Assigned to' field) before calling `gh`.
- [ ] Create the PR via `gh pr create` with title and body in English, as required by `~/git/olie/prompts/workflow-policy.md`.
- [ ] Use the correct source branch and target branch for the repository.
- [ ] Verify that the source branch uses exactly the branch name specified in the card.
- [ ] Set Assignees to the person identified in the 'Assigned to' field of card `{{ code }}` (`gh --assignee` / `--add-assignee`).
- [ ] Set Reviewers to all available reviewers except the person identified in the 'Assigned to' field (`gh --reviewer` / `--add-reviewer`).
- [ ] Select the label that most closely matches the source branch name prefix (`gh --label` / `--add-label`).

Example: for `feature/teste-123`, select the label closest to `feature`.

- [ ] Provide a clear title and description summarizing the purpose of the changes, the relevant card, and the verification performed.
- [ ] Do **not** mention `olie-e2e`, meta-repo Playwright paths, or “e2e added in the meta-repo” in the PR title/body (private suite — **Private E2E suites** in `workflow-policy.md`). Verification may say the behavior was checked locally without naming that suite.
- [ ] Link the pull request to the card when supported by the repository workflow.
- [ ] Verify that the pull request exists (prefer GitHub MCP; else `gh pr view`), targets the correct base branch, and contains the intended commits.

Do not assume that a pull request was created successfully merely because a creation action was attempted. Verify its existence and configuration through MCP or `gh pr view` (JSON or web URL).

If a required reviewer, assignee, label, or other setting is unavailable, report the limitation rather than silently omitting the requirement.

## 6. Phase 5 — Card Lifecycle Update

**Proceed only after the required pull request or pull requests have been created and verified, and all applicable checks in Phases 1–4 have passed.**

- [ ] Open card `{{ code }}` through the MCP OlieFlowAi.
- [ ] Check off the funnel checklist item **Pull Request criado** / **Pull request created** via management HTTP `toggle-funnel-checklist`. Resolve `step_checklist_id` from the project payload (`get-project-details-tool` → `funnels[].steps[].checklists[]` on the QA/CR step; if MCP omits that array, one `GET /api/management/projects/{uuid}` — see **Toggling a funnel-step checklist item** in `~/git/olie/prompts/workflow-policy.md`). Use `${OLIE_MANAGEMENT_TOKEN}`, the card UUID, and that id — never paste a Bearer token. Confirm `{"response":true}`.
- [ ] Resolve **incoming restrictions** for the destination 'QA/CR' step **before** moving. In particular, answer the step form that asks whether api-main Postman documentation must be updated (`Sim` / `Não`) from the Phase 2 determination — use `get-model-dynamic-forms-tool` / `get-form-answers-tool` then `set-form-answers-tool` (see **Moving a card on the board** in `~/git/olie/prompts/workflow-policy.md`). Do not call the move while a required destination-step field is still empty.
- [ ] If the API documentation impact check determined that an update is required, ensure the card is marked accordingly.
- [ ] Verify that the card reflects the actual pull request status and any remaining documentation requirements.
- [ ] Record every verified PR URL on the card per **Pull request links on the card** in `~/git/olie/prompts/workflow-policy.md`: matching form fields when they exist; otherwise append unmatched PR URLs to the project content (do not invent fields).
- [ ] Move the card to the live funnel step whose display name matches 'QA/CR' (logical `quality-review`), using the stage-resolution and move procedure in `~/git/olie/prompts/workflow-policy.md` (prefer MCP `move-project-to-funnel-step-tool`; HTTP fallback with `${OLIE_MANAGEMENT_TOKEN}`). Resolve the step id from the live funnel — never hard-code it.
- [ ] Verify the card's current stage is 'QA/CR' after the move.

Do not mark 'Pull request created' as complete before the relevant pull request has been verified.

Do not move to 'QA/CR' if any mandatory check from Phases 1–4 (or earlier items in this phase) failed, was skipped, or remains unresolved. If the move fails with `incoming_restrictions` (or equivalent), fill the required destination-step answers and retry once; if it still fails for another reason, stop and report (prompt-health). Do not claim the handoff is complete until the verified stage is 'QA/CR'.

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
- The commit convention and branch-name validation results (include the local commitlint / CaptainHook command exit codes and the PR commit-lint check conclusion).
- Meta-repo: commit hash(es) on `main`, whether `origin/main` was updated, or that there was nothing to commit.
- The pull request URLs and their verified configuration.
- Whether an API documentation update is required.
- The status of the 'Pull request created' checklist item.
- Whether the card was moved to 'QA/CR' and the verified stage after the move.
- Any unresolved issues, skipped checks, or outstanding actions.

Clearly distinguish completed actions from pending work. Do not claim that the card is fully ready for QA/CR if any mandatory check remains unresolved or the stage move did not succeed.
