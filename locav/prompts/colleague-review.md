# Colleague Card Review

Review card {{ code }} while it sits in 'QA/CR'. This is a review of someone else's card, not preparation of your own (pre-QA).

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/locav/prompts/workflow-policy.md`.

## 1. Objective

Decide whether the implementation does what the card requested. Report the result. Do not implement the card.

The card's requirements, acceptance criteria, and the latest version of every project thread are the source of truth. Read the threads with **Reading the project forum** in `~/git/locav/prompts/workflow-policy.md`. A change that works but does not match the card is not a pass.

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
   - If `~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md` exists and is non-empty → **Read** it. Do not re-analyze.
   - If that file is **missing** → analyze now: `locav-project-image-analysis` for images, `locav-project-video-conversion` for video (API first; agent-local fallback when vid2agent is unreachable). Write the `.md` under `~/git/locav/cards/{CARD_CODE}/`.
3. Re-analyze or call vid2agent again **only** when the user asks to redo a specific media id (overwrite that file).
4. Use those analyses when checking acceptance criteria. Cite the media id in the report when evidence comes from media.
5. **Never** post image, video, or audio analysis to project content.
6. After writing **new** analysis files, commit and push them on the meta-repo `~/git` when you finish this media pass (or when the user asks).

## 3. What you may change

Do not edit product repositories. That includes `LocavApi` and `locav-front`.

Cypress lives inside `locav-front` (`cypress/e2e`) on the company remote. The **author** must create or edit those specs on their card branch. During this review, do **not** add or change Cypress (or any other product files) yourself. If frontend coverage is missing, that is a failed review — report the gap; do not open a PR on their behalf.

Do not commit product code, secrets, or `.env` files. Do not open a pull request on a company repository.

You may update the card content through OlieFlowAi to record the findings of this review; that is not a product edit and does not replace the author's own product fix. Card notes must follow **Card content vs chat (private prompts)** in `~/git/locav/prompts/workflow-policy.md` — never recommend prompt paths there.

## 4. Branches to test

On each company repository the card touches:

1. Find the branch the author created.
2. Check it out so you can run the feature.
3. If that branch does not exist yet, create the name from **Card branch name** in `~/git/locav/prompts/workflow-policy.md`, from the repository base in `~/git/locav/prompts/project.md` (`preview`).
4. Do not rename their branch and do not commit on it.

Leave unrelated local changes untouched. If a checkout would overwrite them, stop and report the blocker.

## 5. What to verify

- The behavior matches the card, including the edge cases the card states.
- The pull request contains that behavior and does not smuggle unrelated changes.
- Light and dark theme text contrast both hold on the screens the card changes.

If `locav-front` changed, the author's branch must create or edit Cypress specs under `cypress/e2e` for the requested frontend behavior. Missing coverage is a failed review, unless you state which case could not be automated and why. Do not add the specs yourself; they belong on that branch.

If `LocavApi` tests were added or edited, those files are Pest 4. A new PHPUnit test class, or a PHPUnit file the card edited and left as PHPUnit, is a failed review. Untouched PHPUnit files are not a defect. Do not convert them yourself.

## 6. Out of scope

- Do not fix the author's code.
- The outcome moves the card: a failed review moves it to the live funnel step 'Corrigir'; a passed review marks the card's pull requests as approved, merges them when all passed, and changes the card status in the funnel to 'Revisado'. Report the result; the user (or a later workday paste) decides the next stage beyond that.
- Do not treat a local-only success as the production check. That check is 'Revisão em Produção'.
- Do not search for related improvements in this pass. This is a review only.

## 7. Report

- Card {{ code }}.
- Assigned owner(s) from the card ('atribuído a').
- Repositories and branches reviewed.
- Whether the implementation matches the card, with the requirement that failed or passed.
- Pull request outcome: which PRs were approved, which were merged, and which were not approved (when a PR failed or had comments).
- Contrast result for light and dark themes.
- If `locav-front` changed, whether the branch created or edited Cypress specs under `cypress/e2e` for that behavior, or which case could not be automated and why.
- If `LocavApi` tests changed, whether new or edited files are Pest 4, or which edited file is still PHPUnit.
- Checks that did not run, and why.

A failed requirement is a failed review. Do not call the card ready for 'Validação' while one remains open.

## 8. Outcome

Close the review with **one of two paths**. Do not invent a third.

1. **Failed / findings to fix** — If the review has comments about what should be fixed, write them into the card content through OlieFlowAi (findings only; no prompt paths — see **Card content vs chat** in `workflow-policy.md`). In chat, the author then fixes via `~/git/locav/prompts/correction.md`. Keep the card in the live funnel step 'Corrigir'.

2. **Passed** — Mark the card's pull requests as approved through GitHub MCP (`pull_request_review_write`, event `APPROVE`) for each PR that passed. If only some PRs passed, mark only those approved; if none passed, mark the card as 'request changes'. If all the card's PRs were approved, merge all of them (`merge_pull_request`).

3. **Test / backend follow-up** — If the change set touched `LocavApi` and/or `locav-front`, after this review recommend in the **Cursor chat** only `~/git/locav/prompts/test-gap-analysis.md` as the next paste. If `LocavApi` also changed, follow with `mutation-testing.md` (personal stack: one changed test file per paste, `next mutation` while the ledger has files left, then `next prompt` → `pre-qa.md`). Do **not** put those paths on the card. Write gap findings and mutation fixes into the card content (findings only); loop the colleague review after the author fixes when either reports work for the author.

4. **Funnel status** — When the outcome is approval, change the card status in the funnel to 'Revisado': MCP `index-project-funnels-tool` (board funnel → `funnel_status[]` by name) then `edit-project-tool` with `funnel_status`; never hard-code the status id. Do not use HTTP `get-available-steps` when MCP works. If the live funnel has no 'Revisado' status, move the card to the live step that carries the outcome with the move procedure in `~/git/locav/prompts/workflow-policy.md`.
