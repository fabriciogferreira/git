# Card Correction Workflow

Use this when a card comes back from review.

If MCP (any configured server), requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: **stop this prompt**, report the objective error, and offer **`resolva` / `documente` / `resolva permanentemente`** (see **Chat commands** / **Tooling failures** in `workflow-policy.md`) and wait. Do not silently work around it, swap tools to hide the break, or keep implementing. If the failure looks like a wrong assumption in this prompt (bad command or missing step), also say that **this prompt may need updating**. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy — do not call `mcp_auth` and do not ask the user to sign in again for that case only. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

### Host card environment (required first)

Before media review, stage moves, or git work, run **Host card environment** in `~/git/olie/prompts/workflow-policy.md`:

```bash
~/git/bin/workvm-host-card ensure --project olie --code '{{ code }}'
```

Idempotent across days. Do **not** destroy when correction ends — the card is still alive. Destroy only on `finish card` or board `done`.

## 1. Objective and Context

The card with the code `{{ code }}` was returned for corrections. Its expected workflow is to move from the logical `changes-requested` stage to `in-progress` before correction work begins, provided it is still in `changes-requested`.

Use the MCP OlieFlowAi to retrieve the card's complete context, including:

- The card description, requirements, and acceptance criteria.
- The reviewer's findings and the reasons the card was returned.
- The pull requests associated with the card.
- The repositories and branches involved.
- The implementation changes that were reviewed.
- Any attached specifications, test results, and relevant comments.
- **Project media** (`get-project-media-tool` with **`filter: "default"`**): every image, video, audio, user message, **and** system log on the card that supports the return (including funnel-move logs). See **Project media** in `workflow-policy.md`.

Also read every project thread and the latest version of each one, using **Reading the project notebook** in `~/git/olie/prompts/workflow-policy.md`. Treat the reviewer's findings, the card's requirements, and those thread texts as the source of truth for the correction work. Do not assume that the reviewer's list is exhaustive; inspect the relevant code to determine the actual causes of the reported issues.

While reading the card / findings (and again before locking the correction plan): apply **Deferred decisions on the card** in `~/git/olie/prompts/workflow-policy.md`. If a fix path is still deferred — including alternatives joined by **ou** / **or** — **stop**, list the options, ask the user what to choose, and **end each question with your recommendation + why**. Before recommending, also read the **parent** and **children** cards (content + Caderno) when they exist. Do not apply the recommendation until they confirm.

### Card media review (required before the correction plan)

Before creating the correction plan, **review the card's media**. Do not plan only from text comments when the return includes images or videos.

1. `git pull` the meta-repo if needed, then list media via MCP `get-project-media-tool` with **`filter: "default"`** (required; never omit / never `content` alone).
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

**Pull request review feedback (required before the plan).** Resolve the card's associated PR URLs (code-review form fields and any PR URLs in the project content — **Code review form** / **Closing PR review feedback** in `~/git/olie/prompts/workflow-policy.md`). For **each** of those PRs, load **both**:

1. **Inline conversation threads** — GitHub MCP `pull_request_read` method `get_review_comments` (or `gh` / GraphQL `reviewThreads` when MCP is unavailable — **Tool preference**).
2. **Review bodies** — GitHub MCP `pull_request_read` method `get_reviews` (or equivalent). Treat actionable points in `CHANGES_REQUESTED` and substantive `COMMENTED` review **bodies** as findings even when there are **zero** inline threads. A review that lists blockers only in the summary body is still a source of truth (GitHub has no Resolve button on that body).

Do this even when the card content / return text already lists findings: PR threads and review bodies often carry line-level or blocker detail the card text omits.

- If a PR has review comments, unresolved threads, **or** actionable review-body points, treat every actionable item as a finding for analysis and for the correction plan (same triage as card/forum findings).
- If a PR has neither threads nor actionable review-body points, say so in the plan and continue with card/forum findings only.
- Do not build or present the plan until those PRs have been checked for **threads and reviews**.
- Do not conclude “no PR feedback” from empty `get_review_comments` alone.

For every reported issue (card, forum/notebook, **PR review thread, and PR review body**):

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
2. **Do not force-push yet.** Resume the rest of this workflow on the local rebased branch first: correction plan, non-conflict findings, TDD, and local verification. Pushing before that check is wrong — you would publish an unverified tip and only then discover what still fails.
3. When this correction pass is otherwise complete (findings addressed or documented as verified non-issue / out-of-scope, relevant tests run, working tree clean aside from intentional uncommitted work the user owns), **then** force-push each rebased card/PR branch (`git push --force-with-lease`). The rebase rewrites history, so a normal push is refused; `--force-with-lease` updates the PR branch without a blind `--force` if someone else pushed in the meantime. **Force-push is the last remote write of this correction pass** — after local verification, not before.
4. Confirm the remote branch and open PR reflect the rebased tip. Do not open a new PR or rename the branch.

If the return also lists non-conflict findings, still stop after starting the rebase(s). Those findings wait until the user resumes after resolving conflicts; they are handled **before** the force-push in step 3.

If the rebase starts and completes with no conflicts: report that outcome, continue the correction plan / verification on the local tip, and force-push with `--force-with-lease` only at the end of this pass (same rule as step 3). Do not push an unverified rebased tip “just to unblock the PR”.

If the return was **only** conflicts (no other findings): after the rebase is verified finished, still run the minimal local check that the conflict resolution did not leave the tree broken (at least status clean + the tests/paths touched by conflict resolution when applicable), **then** force-push as the last step.

## 5. Repository and Branch Preparation

Identify every repository involved in the card, including:

- Private Playwright suite (resolve per **Private E2E suites** / path resolution in `workflow-policy.md`: workspace `olie-e2e` on host-card, else `~/git/olie/olie-e2e`)
- `api-main` (workspace folder / worktree on host-card, else `~/git/olie/api-main`)
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

**Plan mode first (Cursor):** Before creating or presenting the correction plan/checklist, switch the chat to **Plan** mode (`SwitchMode` → `plan`). Investigate read-only and build the plan **while still in Plan mode**. Do not stay in Agent mode and “just write a checklist” in chat — that invites premature coding. Leave Plan mode only when the user sends `next` (or explicitly asks to implement / waives controlled mode). If `SwitchMode` is unavailable, still present the plan and stop; do not start coding.

Before implementing any fix, create the plan in the agent's native planning mechanism (e.g. Cursor `CreatePlan`) while in Plan mode. If unavailable, use an ignored local card-work directory rather than adding an orchestration document to a product repository. Add repository documentation only when the card itself requires it.

The plan must include:

- Card code and objective.
- Which associated PRs were checked for review **threads** and **review bodies**, and whether each had unresolved threads and/or actionable `CHANGES_REQUESTED`/`COMMENTED` body points (list by repo + PR number + short subject).
- The reviewer's findings (**including every actionable PR review comment and every actionable review-body point**) and the root cause of each issue. Do not drop a PR comment or body blocker from triage because it was labeled nit/suggestion/padrão — classify it (in-scope / simple / out-of-scope) like any other finding.
- The relevant repository, branch, files, and code locations.
- The expected behavior and acceptance criteria for each correction.
- Existing test coverage and missing scenarios.
- The proposed test-first implementation steps.
- Dependencies and cross-repository coordination.
- Potential regressions and validation requirements.
- A checklist of small, independently reviewable tasks.
- A section titled 'Issues encountered during development'.

**Scope triage (every finding and every extra defect you discover):** classify each item before it enters the checklist:

- **In-scope** — clearly part of the return / the card's acceptance criteria → fix in this pass.
- **Simple** — outside the original ask but a small, local fix with no product decision → fix in this pass and note it.
- **Out-of-scope** — needs a product decision, a larger change, or a separate delivery → do **not** fix here; propose a new card (or ask the user) instead.

Count **new** findings discovered during this correction (defects you found that were not in the reviewer's return). If that count is greater than **3**, stop before expanding the plan: report the list, explain why so many extras appeared (weak card tasks, incomplete first implementation, or review noise), and wait for instructions instead of absorbing unbounded scope.

Order the checklist by dependencies. Ensure that prerequisite tests, code changes, and integration checks are planned in the correct sequence.

Each item should describe one concrete task and have a clear completion condition.

Present the plan to the user before implementing any corrections.

## 6b. Re-run budget

Verify only what this correction changed (regression tests for the findings + the touched paths). Do **not** re-run the whole unrelated Pest suite or re-open gap/coverage/mutation stacks “for safety” unless the return explicitly requires it or the user asks. Shared rule: **Expensive re-run budget** in `~/git/olie/prompts/workflow-policy.md`.

## 7. TDD Workflow

Apply Test-Driven Development to the corrections, using the relevant tests in the resolved private Playwright suite and in `api-main`, as well as tests in any other affected repositories. Keep `olie-e2e` private: use the resolved in-workspace root (never `~/git/olie/olie-e2e` when that path is outside the open workspace); never cite paths or “meta-repo e2e” in card content, Caderno, company repos, or PR bodies (**Private E2E suites** in `workflow-policy.md`).

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

Follow **Temporary E2E CAPTCHA** in `~/git/olie/prompts/implementation.md` §7 (same steps as this correction flow). Short form: Google's public **test secret** in local `api-main` `.env` + optional **test site key** in `packages/management/.env.development.local` for browser login. Do not stub the management API. Do not comment out or delete `RecaptchaValidate` / front `getToken()` code. Never commit those env overrides.

## 9. Incremental Execution

**Default after the plan:** stop. Do **not** start coding, scaffolding, or tests until the user sends **`next`**. Present the checklist clearly in chat so they can follow item by item.

Correction runs in **controlled mode by default**: one checklist item per `next`. Only skip controlled mode when the user explicitly asks to run the whole checklist without stopping (e.g. “implement everything”, “sem next”, “go”).

In controlled mode, wait for the user to send `next` and then:

1. Select the next incomplete checklist item whose dependencies have been satisfied.
2. Implement only that item.
3. Follow the TDD sequence whenever the item involves a code correction.
4. Run the relevant verification.
5. Update the plan and mark the item complete only after its completion conditions have been verified.
6. Report the changes, affected files, test results, and any remaining concerns.
7. Stop and wait for the next `next` command.

If the user explicitly waived controlled mode, perform the same checklist in dependency order and report after each meaningful verification boundary.

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

## 10b. GitHub PR review feedback — prepare only (do not close yet)

There are **two shapes** of feedback (see **Closing PR review feedback** in `~/git/olie/prompts/workflow-policy.md`). During **this** correction paste you only **prepare** the close — you do **not** publish it.

**Hard ban until after validations:** do **not** mark review threads **Resolved**, do **not** post the review-body **audit comment**, and do **not** treat **commit / push / “mark resolved”** as the end of this paste. Those steps claim the finding is closed on GitHub; that must wait until `implementation-validation.md` (and, when `api-main` changed, gap → coverage → mutation → `pest-parallel`) has passed. Public close + push of the validated tip belongs to `pre-qa.md` §5.0.

### During this correction paste

1. Fix every actionable thread and review-body point (or document verified non-issue / out-of-scope).
2. Keep a **draft audit checklist** in the chat completion report (same shape as below) so pre-qa can post it without rediscovering the review.
3. Leave threads **unresolved** on GitHub. Leave the review body without an audit comment.
4. Do **not** commit or push unless the user explicitly asks for an intermediate save — and even then do **not** post Resolve/audit as if the return were closed.

### After validations (`pre-qa.md` §5.0)

- **A) Inline threads** — Resolve each fully addressed thread (`resolveReviewThread` / MCP). Prefer GitHub MCP; else `gh api graphql`. **Tool preference** in `workflow-policy.md`.
- **B) Review bodies** — post **one** PR issue comment that audits the review point-by-point; cite commit SHAs on the **pushed** tip; `@reviewer` + review date. Do **not** dismiss the review to fake closure.

Suggested audit shape (language may match the review — pt-BR is fine when the review was in pt-BR):

```markdown
## Endereçado ao review de @login (YYYY-MM-DD)

1. ✅ <ponto> — <como> (`abc1234`)
2. ✅ <ponto> — <como> (`def5678`)
3. ⬜ <não bloqueante> — adiado / fora de escopo (<motivo>)
```

Card/forum text findings without a GitHub thread or review body are unchanged — there is nothing to Resolve or audit-comment on GitHub.

In the completion report, list: threads Resolved (repo + PR + short subject); any threads left open with why; and every **audit comment** posted for a review body (PR URL + comment URL or date).

## 11. Completion Criteria

When the return was only for merge conflicts, the first stop is complete when the rebase onto `develop` has been started in each affected repository, conflicts were left unresolved for the user, and the user was told they can resolve them now. Do not claim conflict resolution as done at that stop. After the user resolves the conflicts, this pass is complete when the rebase is finished, the minimal local verification for that conflict-only return has run (§4), **and then** each rebased card/PR branch has been force-pushed with `--force-with-lease` (force-push last).

Otherwise, the correction work is complete only when:

- Every reviewer finding has been addressed or explicitly resolved with supporting evidence.
- Every associated GitHub PR review **thread** whose points were fully fixed (or verified non-issue / agreed out-of-scope) has been marked **Resolved** (§10b A). Threads still open only when a point remains unfinished — and those are listed in the report.
- Every associated GitHub PR **review body** with actionable points that this pass closed has a public **audit comment** on that PR (§10b B). Missing audit comments after a completed correction are a miss.
- All applicable checklist items have been completed and verified.
- Regression tests cover the corrected behavior.
- Relevant tests have been executed, with any limitations documented.
- Cross-repository integration has been checked where applicable.
- The implementation plan and issue log are up to date.
- No unrelated user changes have been overwritten.
- No prohibited CAPTCHA configuration or secrets have been committed, pushed, or included in a pull request.
- If this pass included a rebase onto the base branch: the force-push (`--force-with-lease`) ran **after** the verification above, not before.

At completion, provide a concise report containing:

- The issues corrected.
- Scope triage summary: in-scope / simple / out-of-scope (and any suggested new cards).
- How many **new** findings (not in the reviewer's return) were discovered; if that count was greater than 3 and work stopped, say so explicitly.
- The files and repositories changed.
- The tests created or updated and their results.
- Which GitHub PR review threads were marked Resolved, any left open with reason, and which review-body audit comments were posted (PR + link/date).
- Any unresolved issues or verification limitations.
- Any remaining manual actions.

Do not commit, push, or open a pull request unless explicitly requested and permitted by the applicable security restrictions.

**Do not recommend commit / push / PR** at the end of this paste — not even as a “when you are ready” hint. Product commits belong to **`pre-qa.md`** after the rest of the develop handoff has run. In the completion report, recommend only the **next prompt**.

When the full correction on this paste is done (not the conflict-only first stop in §4), the next paste is `~/git/olie/prompts/implementation-validation.md` (code-only). Say that clearly in the completion report so `next prompt` can run it. Do not run `~/git/olie/prompts/pre-qa.md` or board `~/git/olie/prompts/validation.md` yet — those come after implementation-validation (and when `api-main` changed: gap → coverage → mutation → Pest parallel → `pre-qa.md`).

**Evidence table:** post `### Evidência — {N}º Correção` into the **card content** via `save-media-tool` per **Evidence table on project content** in `~/git/olie/prompts/workflow-policy.md` (rows for what this paste verified; `n/a` / `não rodado` where pre-QA has not run yet; never description, Caderno, or PR). The following **`pre-qa.md`** posts again with the **same** heading and Pint/phpstan/% filled in. When front JS/TS/Vue was touched, include the **JS → TypeScript** and **Options API → Composition API** tables when they have rows.
