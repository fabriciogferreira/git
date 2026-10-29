# Card Correction Workflow

Use this when a card comes back from review.

If MCP (any configured server), requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: **stop this prompt**, report the objective error, and **ask the user to fix the broken tool** before continuing. Do not silently work around it, swap tools to hide the break, or keep implementing. If the failure looks like a wrong assumption in this prompt (bad command or missing step), also say that **this prompt may need updating**. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy — do not call `mcp_auth` and do not ask the user to sign in again for that case only. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

## 1. Objective and Context

The card with the code `{{ code }}` was returned for corrections. Its expected workflow is to move from the logical `changes-requested` stage to `in-progress` before correction work begins, provided it is still in `changes-requested`.

Use the MCP OlieFlowAi to retrieve the card's complete context, including:

- The card description, requirements, and acceptance criteria.
- The reviewer's findings and the reasons the card was returned.
- The pull requests associated with the card.
- The repositories and branches involved.
- The implementation changes that were reviewed.
- Any attached specifications, test results, and relevant comments.
- **Project media** (`get-project-media-tool`): every image, video, and audio on the card that supports the return (screenshots, screencasts, and description-linked attachments).

Treat the reviewer's findings and the card's requirements as the source of truth for the correction work. Do not assume that the reviewer's list is exhaustive; inspect the relevant code to determine the actual causes of the reported issues.

### Card media review (required before the correction plan)

Before creating the correction plan, **review the card's media**. Do not plan only from text comments when the return includes images or videos.

1. `git pull` the meta-repo if needed, then list media via MCP.
2. For each image, video, or audio item that belongs to this card and is part of the return (or is cited by a finding):
   - If `~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md` exists and is non-empty → **Read** it. Do not re-analyze.
   - If that file is **missing** → analyze now: `olie-project-image-analysis` for images, `olie-project-video-conversion` for video (API first; agent-local fallback when vid2agent is unreachable). Write the `.md` under `~/git/olie/cards/{CARD_CODE}/`.
3. Re-analyze or call vid2agent again **only** when the user asks to redo a specific media id (overwrite that file).
4. Use those analyses when diagnosing findings (section 3) and when writing the correction plan. Cite the media id that shows the defect.
5. **Never** post image, video, or audio analysis to project content (`save-media-tool` or any MCP write of that markdown).
6. After writing **new** analysis files, commit and push them on the meta-repo `~/git` when you finish this media pass (or when the user asks), so a later correction reuses them.

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

## 4. Merge Conflicts Returned from Review

**Never** apply this section (or any git write) to `~/git/olie/docs` / `olie-ai/docs`. That repository is out of scope — see **Olie docs repository — never touch** in `~/git/olie/prompts/workflow-policy.md`. If the only conflict return is that docs PR, stop and tell the user; do not start a rebase there.

When the card was returned because of merge/rebase conflicts (or a reviewer finding is specifically about conflicts with the base branch), do **not** resolve the conflicts yourself.

For each affected repository (excluding `olie/docs`):

1. Inspect Git status. If uncommitted changes block a safe rebase, stop and report the blocker.
2. Fetch the latest `develop` from origin and update the local `develop` branch (fast-forward only).
3. Check out the existing card/PR branch that has the conflict. Do not invent a new branch name.
4. Start a rebase of that branch onto the updated `develop` (`git rebase develop` after `develop` is current, or equivalent onto `origin/develop`).
5. Do **not** resolve conflict markers, edit conflicted files to finish the rebase, stage conflicted paths, run `git rebase --continue`, `git rebase --abort`, or `git rebase --skip`. Leave the rebase in progress for the user.
6. Tell the user the rebase has been started on that branch and repository, and that they can resolve the conflicts now.
7. Stop. Do not create a correction plan, change application code, or continue the TDD workflow for that repository until the user finishes the rebase and asks to continue.

When the user reports that the conflicts are resolved (or asks to continue after resolving them):

1. Verify the rebase is finished in each affected repository (`git status` shows a clean working tree on the card/PR branch, with no rebase in progress). If the rebase is still paused on conflicts or the working tree is dirty for an unrelated reason, stop and report the blocker.
2. Force-push that branch to its existing remote tracking branch (`git push --force-with-lease`). The rebase rewrites history, so a normal push is refused; `--force-with-lease` updates the PR branch without a blind `--force` if someone else pushed in the meantime.
3. Confirm the remote branch and open PR reflect the rebased tip. Do not open a new PR or rename the branch.
4. Only then resume the rest of this workflow (correction plan / non-conflict findings) if the user asked to continue beyond the conflict return.

If the return also lists non-conflict findings, still stop after starting the rebase(s). Those findings wait until the user resumes after resolving conflicts (and after the force-push above).

If the rebase starts and completes with no conflicts, force-push the rebased branch with `--force-with-lease` as above, report that outcome, and wait for instructions before continuing other correction work.

## 5. Repository and Branch Preparation

Identify every repository involved in the card, including:

- `~/git/olie/olie-e2e`
- `~/git/olie/api-main`
- Any additional repository referenced by the card or its pull requests.

Exclude `~/git/olie/docs` (`olie-ai/docs`) always — never checkout, rebase, or edit it for a card.

For each repository:

1. Inspect the Git status and identify uncommitted changes.
2. Determine the exact branch used by the associated pull request and the branch naming specified in the card.
3. Inspect the relevant commits and compare the branch against the correct base.
4. Switch to the correct existing branch when it is safe to do so.
5. If the branch is missing, determine the correct base and branch name from the card and repository workflow before creating it.

Never discard, overwrite, or silently modify existing user changes. If uncommitted changes prevent a safe branch switch, stop and report the blocker.

Do not create alternative branch names merely because they are more convenient. Preserve the established card-specific branch naming across involved repositories.

Verify the active branch before any code modification. Never apply a correction to the wrong branch.

## 6. Create the Correction Plan

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

## 7. TDD Workflow

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

## 8. Temporary E2E CAPTCHA Configuration

Playwright stubs `grecaptcha` with a fake token. `api-main` skips `RecaptchaValidate` only when `APP_ENV=testing`. This VM is `local`, so the real `RECAPTCHA_SECRET` answers `Token inválido` and the spec never reaches the password step.

Do not stub the management API to get past that. Do not change PHP. Use Google's public test secret in the local `.env` only. `siteverify` then accepts any token, the same window `APP_ENV=testing` already has.

`RECAPTCHA_SECRET=6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe`

1. Confirm `~/git/olie/api-main/.env` is gitignored.
2. If the value is not already the test secret, copy the file to `~/.config/workvm/api-main.env.recaptcha-backup` (`chmod 600`) before the first change. Do not put the original secret in the repo, in a comment, or in the chat.
3. Set `RECAPTCHA_SECRET` to the test secret.
4. Run `docker exec olie-api-main php artisan config:clear`. `POST /api/management/login/identify` with the stub token and `Origin: http://devframe.olie.localhost` must return `method: password`, not `invalid_token`.
5. Leave the test secret in place while e2e on this VM needs a real login. Restore that backup and run `config:clear` again when that work is finished or the user asks. Delete the backup after a successful restore. If the restore fails, say the test secret may still be active.
6. Never commit, push, or quote `.env` or the backup.

If the container or `.env` is missing, stop and report that. Do not add a code bypass.

## 9. Incremental Execution

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

## 10. Development Issue Tracking

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

## 11. Completion Criteria

When the return was only for merge conflicts, the first stop is complete when the rebase onto `develop` has been started in each affected repository, conflicts were left unresolved for the user, and the user was told they can resolve them now. Do not claim conflict resolution as done at that stop. After the user resolves the conflicts, this pass is complete when the rebase is finished and each rebased card/PR branch has been force-pushed with `--force-with-lease`.

Otherwise, the correction work is complete only when:

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

When the full correction on this paste is done (not the conflict-only first stop in §4), the next paste is `~/git/olie/prompts/implementation-validation.md` (code-only). Say that clearly in the completion report so `next prompt` can run it. Do not run `~/git/olie/prompts/pre-qa.md` or board `~/git/olie/prompts/validation.md` yet — those come after implementation-validation (and after the mutation stack when `api-main` changed: finish with `next mutation`, then `pre-qa.md`).
