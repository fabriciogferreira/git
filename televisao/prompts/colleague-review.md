# Colleague Card Review

Review card {{ code }} while it sits in 'QA/CR'. This is a review of someone else's card, not preparation of your own (pre-QA).

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/televisao/prompts/workflow-policy.md`.

## 1. Objective

Decide whether the implementation does what the card requested. Report the result. Do not implement the card.

The card's requirements, acceptance criteria, and the latest version of every project thread are the source of truth. Read the threads with **Reading the project forum** in `~/git/televisao/prompts/workflow-policy.md`. A change that works but does not match the card is not a pass.

## 2. Context

Load the card through `mcp olie-flow-ai`. Read:

- The description, requirements, and acceptance criteria.
- The repositories and branches the author changed.
- The pull requests and the commits on those branches.
- Comments, attachments, and test notes.
- **Project media** (`get-project-media-tool`): screenshots, screencasts, and other image/video/audio that define expected behavior or show a defect.

Do not review from the card title alone.

### Card media review (required before the verdict)

Before deciding pass or fail, **review the card's media**. Do not judge from text alone when images or videos show the expected or broken behavior.

1. `git pull` the meta-repo if needed, then list media via MCP.
2. For each image, video, or audio item that belongs to this card and supports the requirements or a finding:
   - If `~/git/televisao/cards/{CARD_CODE}/{MEDIA_ID}.md` exists and is non-empty → **Read** it. Do not re-analyze.
   - If that file is **missing** → analyze now: `televisao-project-image-analysis` for images, `televisao-project-video-conversion` for video (API first; agent-local fallback when vid2agent is unreachable). Write the `.md` under `~/git/televisao/cards/{CARD_CODE}/`.
3. Re-analyze or call vid2agent again **only** when the user asks to redo a specific media id (overwrite that file).
4. Use those analyses when checking acceptance criteria. Cite the media id in the report when evidence comes from media.
5. **Never** post image, video, or audio analysis to project content.
6. After writing **new** analysis files, commit and push them on the meta-repo `~/git` when you finish this media pass (or when the user asks). You may also commit e2e changes as already allowed in §3.

## 3. What you may change

Do not edit product repositories. That includes `televisao-api`, `televisao-front`, `televisao-meet-front`, and `televisao-meet-core`.

You may change only the meta-repo Playwright suites. Those trees are not part of the company remotes and are not cloned for other developers' WorkVMs:

- `~/git/televisao/televisao-front-e2e` when the author changed `televisao-front`
- `~/git/televisao/televisao-meet-front-e2e` when the author changed `televisao-meet-front`

If the author changed that front, **add** end-to-end tests there for the frontend behavior the card requested. If those tests already exist and a requested point is uncovered, add the missing tests. Do not rewrite tests that already cover the card. Do **not** fail the review because the author's company branch lacks e2e — they cannot push those suites.

For `~/git/`, do not create a card branch. Commit and push the e2e changes directly to 'main'.

Do not commit product code, secrets, or `.env` files. Do not open a pull request on a company repository.

You may update the card content through OlieFlowAi to record the findings of this review; that is not a product edit and does not replace the author's own product fix.

## 4. Branches to test

On each company repository the card touches:

1. Find the branch the author created.
2. Check it out so you can run the feature.
3. If that branch does not exist yet, create the name from **Card branch name** in `~/git/televisao/prompts/workflow-policy.md`, from the repository base in `~/git/televisao/prompts/project.md` (`preview`).
4. Do not rename their branch and do not commit on it.

Leave unrelated local changes untouched. If a checkout would overwrite them, stop and report the blocker.

## 5. What to verify

- The behavior matches the card, including the edge cases the card states.
- The pull request contains that behavior and does not smuggle unrelated changes.
- Light and dark theme text contrast both hold on the screens the card changes.

If `televisao-front` or `televisao-meet-front` changed, the e2e tests in section 3 cover the requested frontend behavior, or you say which case could not be automated and why.

If `televisao-api` tests were added or edited and Pest is installed, those files use that Pest. A new PHPUnit test class, or a PHPUnit file the card edited and left as PHPUnit while Pest is installed, is a failed review. Untouched PHPUnit files are not a defect. Do not convert them yourself. If Pest is not installed, do not fail the review for PHPUnit tests.

## 6. Out of scope

- Do not fix the author's code.
- Do **not** move the card to 'Corrigir' or 'Revisado' in this paste when the change set touched `televisao-api` — finish mutation first (see **Outcome** and **Colleague review outcome** in `~/git/televisao/prompts/workflow-policy.md`).
- Do not treat a local-only success as the production check. That check is 'Revisão de produção'.
- Do not search for related improvements in this pass. This is a review only.

## 7. Report

- Card {{ code }}.
- Assigned owner(s) from the card ('atribuído a').
- Repositories and branches reviewed.
- Whether the implementation matches the card, with the requirement that failed or passed.
- Pull request outcome deferred when backend mutation is still required (see Outcome); otherwise which PRs were approved, merged, or not approved.
- Contrast result for light and dark themes.
- E2E tests added or extended in the meta-repo suite, and the 'main' commit if one was pushed — or which case could not be automated and why.
- If `televisao-api` tests changed and Pest is installed, whether new or edited files use that Pest, or which edited file is still PHPUnit.
- Checks that did not run, and why.

A failed requirement is a failed colleague review. Do not call the card ready for 'Validação' while one remains open.

## 8. Outcome

Follow **Colleague review outcome** in `~/git/televisao/prompts/workflow-policy.md`. Do not invent a third path.

1. **Record the colleague verdict** — Pass or fail. If fail, write the findings into the card content through OlieFlowAi (the author later fixes via `~/git/televisao/prompts/correction.md`). Do **not** approve or merge PRs on a fail.

2. **Backend still required** — If the change set touched `~/git/televisao/televisao-api`, leave the card in 'QA/CR'. Recommend `~/git/televisao/prompts/mutation-testing.md` as the next paste (`next prompt`). Do **not** move to 'Corrigir' and do **not** mark 'Revisado' / approve / merge yet. The combined funnel move happens only after that mutation stack finishes (or the user explicitly skips it).

3. **No backend (mutation skipped)** — Apply the funnel move now:
   - Fail → live step 'Corrigir'.
   - Pass → approve each passed PR (`pull_request_review_write`, event `APPROVE`); if all the card's PRs were approved, merge them (`merge_pull_request`); set funnel status 'Revisado' (resolve by display name via OlieFlowAi / `edit-project-tool` with `funnel_status`; never hard-code the status id). If there is no 'Revisado' status, use the move procedure in `~/git/televisao/prompts/workflow-policy.md`.

4. **After mutation (same card)** — When mutation finishes in a later paste, that prompt applies the combined rule: move to 'Corrigir' only if the colleague review failed **or** mutation reported fixes to write; approve / merge / 'Revisado' only if both passed.
