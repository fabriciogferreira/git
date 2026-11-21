# Pre-QA/CR Checklist and Pull Request Workflow

Run this **after** `~/git/olie/prompts/pest-parallel.md` has passed when the card changed `api-main` (or after `implementation-validation.md` when there is no backend). If backend changed, finish first: gap analysis, then coverage (`next coverage` / `correct coverages`), then mutation (`next mutation` / `correct mutations`), then Pest parallel. If mutation or coverage still has remaining files, **stop** and tell the user to drain that stack. If Pest parallel is red, **stop** and tell them to fix / `try again` on `pest-parallel.md`. Chat commands: `~/git/olie/prompts/workflow-policy.md` → **Chat commands**. 

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

**Re-run budget:** do not re-run a completed phase (lint/Pint, docs impact, commitlint, PR create/verify, board move) on an unchanged tree “to confirm”. Re-enter a phase only after a fix, a failed check, or a new commit/PR state. Shared rule: **Expensive re-run budget** in `workflow-policy.md`.

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
- [ ] Check the branch diff for temporary or debug comments introduced by this work (`<!--`, `//`, `/*`, `#`, and equivalents). Remove those leftovers; do not strip pre-existing explanatory comments unrelated to this card.
- [ ] Check for duplicate enums, especially in `api-main`. Reuse existing enums where appropriate instead of introducing redundant definitions.
- [ ] Review the implementation for unnecessary duplication, regressions, edge cases, and inconsistencies with existing project conventions.
- [ ] Verify that the implementation satisfies the card's requirements and does not introduce unrelated changes.

### 2.3. UI Standards and Good Practices

- [ ] Ensure Bootstrap modals and PrimeVue dialogs have fixed width and height. Their dimensions must not vary according to content, although width may adapt to the viewport.
- [ ] Use `useLocalStorage` instead of the native JavaScript `localStorage` API when working with local storage in the relevant frontend code, following the existing project conventions.
- [ ] Verify that the implementation follows the established frontend architecture, component conventions, and error-handling patterns.
- [ ] Do not change layout or styling unless the card asks for it. Unrelated visual diffs are a fail for this phase.

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

- [ ] From the card’s `api-main` worktree (host-card) or `~/git/olie/api-main` (WorkVM), for each non-merge SHA in `$BASE_SHA..$HEAD_SHA` (mirror the workflow loop):

  **Host-card** (preferred — pipes the message file; uses `hc-*-app-1`):

  ```bash
  msg=$(mktemp)
  git log -1 --format='%B' "$SHA" > "$msg"
  ~/git/bin/workvm-host-card-captainhook commit-msg "$msg"
  rm -f "$msg"
  ```

  Ensure installs `core.hooksPath` → `lib/host-card-hooks/api-main` on the card worktree so plain `git commit` also goes through that wrapper. Do **not** rely on bare `docker exec olie-api-main` (container name is wrong; `COMMIT_EDITMSG` under `.git/worktrees/` is not mounted).

  **WorkVM fallback** (when `olie-api-main` is the running app):

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

### 4.3. Meta-repo — commit and push from the card worktree

Product clones get card branches and PRs. The **meta-repo** does not: ship its card-related changes on the **live meta branch** (no product-style PR).

This pre-QA pass **must** commit and push meta-repo updates that belong to the card (or to prompt/workflow fixes done in the same chat), when the working tree has any:

- `olie/prompts/` (including `mutation-ledger.md` / `coverage-ledger.md`)
- `olie/cards/{CARD_CODE}/` media analyses
- Private Playwright specs/helpers for the card (resolved `olie-e2e` root — workspace folder on host-card, else `olie/olie-e2e/`; commit them there; do **not** name this suite in product PR bodies or card/Caderno notes — **Private E2E suites**)
- `HISTORICO.md` / `bin/` / `lib/` / other meta-repo docs or tooling touched for the same work

Do **not** open a pull request for the meta-repo. Do **not** invent a card branch on the meta-repo.

**Live branch name:** read `git -C ~/git branch --show-current` (today often `experiment/host-cards-no-vm` on jarvis). Prefer `main` only when that is the checked-out live branch. Do **not** stop solely because the branch is not named `main` while an experiment branch is the active line.

**Host-card:** the workspace folder **`git/`** is a **detached** meta worktree (so many cards can open without each checking out the live branch — Git allows one branch checkout per repo). Edit, commit, and push **there**. Rule: `host-card-meta-repo-path.mdc`.

1. Note the live branch name from `~/git` (do **not** `checkout` that branch in the card worktree while `~/git` holds it).
2. In the card `git/` worktree: `git fetch origin`. Rebase/ff the detached tip onto `origin/<live-branch>` if behind; on divergence or non-ff, stop and report (prompt-health).
3. Stage only paths that belong to this work. Exclude secrets, `.env`, WorkVM stubs (`mcp.workvm-user`, skip-worktree noise), and unrelated dirty files. If unrelated dirt blocks a clean commit, stop and report rather than mixing it in.
4. Commit in the **worktree** (English message, no Cursor/AI co-author; card code when applicable).
5. `git push origin HEAD:<live-branch>` (refspec — no branch checkout required).
6. Fast-forward the live checkout for runtime: `git -C ~/git pull --ff-only`. That is sync only — do **not** copy dirty files into `~/git` to commit.

**Classic WorkVM** (workspace root is bare `~/git`, no card worktree): commit and `git push origin HEAD` on that checkout as before.

Checklist:

- [ ] Resolve writable meta root (host-card → workspace `git/`; else `~/git`).
- [ ] Note live branch via `git -C ~/git branch --show-current` (host-card) or `git branch --show-current` (classic).
- [ ] Fetch; ff onto `origin/<live-branch>` before committing when behind. Stop on divergence.
- [ ] Stage only paths that belong to this work.
- [ ] Commit in that root; on host-card push with `git push origin HEAD:<live-branch>`.
- [ ] `git -C ~/git pull --ff-only` after a host-card push so live HEAD matches remote.
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

### 5.0. Prior review feedback closed (return to 'QA/CR')

When this card is returning to 'QA/CR' after a review bounce (correction / `CHANGES_REQUESTED`), close the GitHub feedback loop **here** — **after** `implementation-validation` (and gap → coverage → mutation → Pest parallel when `api-main` changed), and **before** the board move. Do **not** Resolve or audit during `correction.md`; that paste only drafts the checklist. Shared rules: **Closing PR review feedback** in `~/git/olie/prompts/workflow-policy.md` (and `correction.md` §10b).

- [ ] Tip that will be audited is committed and pushed (SHAs in the audit must exist on the remote PR head).
- [ ] For each associated open PR: load inline **threads** and **reviews** (`get_review_comments` + `get_reviews`). Do not treat empty threads as “no feedback” if a review body still lists blockers. Prefer the draft checklist from the correction report when present.
- [ ] Every fully addressed inline thread is marked **Resolved** on GitHub.
- [ ] Every fully addressed **review body** (no Resolve button) has a public **audit comment** on that PR that lists each point as done / deferred / non-issue with commit evidence. Do **not** dismiss the review to fake closure.
- [ ] If a blocker from the latest `CHANGES_REQUESTED` is still open, **stop** — do not move to 'QA/CR'.

Skip this subsection only when there was no prior PR review feedback to close (first handoff to 'QA/CR' with no `CHANGES_REQUESTED` / open threads).

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
- Whether prior PR review threads were Resolved and/or review-body audit comments were posted (or that §5.0 was skipped because there was no prior review feedback).
- Any unresolved issues, skipped checks, or outstanding actions.

Clearly distinguish completed actions from pending work. Do not claim that the card is fully ready for QA/CR if any mandatory check remains unresolved or the stage move did not succeed.

### Evidence table (required)

After the final report above, upsert the **Implementation** (or **{N}º Correção** when this pre-QA returns a card from Corrigir) evidence table into the project description per **Evidence table on project content** in `~/git/olie/prompts/workflow-policy.md`. Use Front/Back rows only for surfaces touched (including UX rows **contraste** / **feedback** / **comportamento** when UI was touched — no axe gate); mutation/coverage/all-test % on diff `A..B` excluding the Pint commit. When front JS/TS/Vue was touched, include the **JS → TypeScript** and **Options API → Composition API** tables (omit any table that would be empty) in that same policy section.
