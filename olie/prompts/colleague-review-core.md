# Colleague review — core (miolo)

Review card {{ code }} while it sits in 'QA/CR'. This is the **review body** only: decide pass/fail, e2e when needed, write fail findings. Do **not** apply the funnel move, approve, or recommend sequential next pastes — the dispatcher `~/git/olie/prompts/colleague-review.md` owns those.

Launched by that dispatcher (often in parallel with `test-gap-analysis.md` / `mutation-testing.md`). If the user pastes this file alone, still do the review body, then tell them to paste `colleague-review.md` for the combined outcome.

If MCP (any configured server), requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: **stop this prompt**, report the objective error, and **ask the user to fix the broken tool** before continuing. Do not silently work around it, swap tools to hide the break, or keep reviewing. If the failure looks like a wrong assumption in this prompt (bad command or missing step), also say that **this prompt may need updating**. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy — do not call `mcp_auth` and do not ask the user to sign in again for that case only. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

## 1. Objective

Decide whether the implementation does what the card requested. Report the result. Do not implement the card.

The card's requirements and acceptance criteria are the source of truth. A change that works but does not match the card is not a pass.

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
   - If `~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md` exists and is non-empty → **Read** it. Do not re-analyze.
   - If that file is **missing** → analyze now: `olie-project-image-analysis` for images, `olie-project-video-conversion` for video (API first; agent-local fallback when vid2agent is unreachable). Write the `.md` under `~/git/olie/cards/{CARD_CODE}/`.
3. Re-analyze or call vid2agent again **only** when the user asks to redo a specific media id (overwrite that file).
4. Use those analyses when checking acceptance criteria. Cite the media id in the report when evidence comes from media.
5. **Never** post image, video, or audio analysis to project content.
6. After writing **new** analysis files, commit and push them on the meta-repo `~/git` when you finish this media pass (or when the user asks). You may also commit e2e changes as already allowed in §3.

## 3. What you may change

Do not edit product repositories. That includes `olie-fronts`, `api-main`, `backoffice`, `landing`, `docker-workspace`, and `websocket`.

You may change only `~/git/olie/olie-e2e`. That tree is not part of the company remotes.

- If the author changed `olie-fronts`, add end-to-end tests there for the frontend behavior the card requested.
- If those tests already exist and a requested point is uncovered, add the missing tests.
- Do not rewrite tests that already cover the card.

For `~/git/`, do not create a card branch. Commit and push the e2e changes (and new card media analyses under `olie/cards/`) directly to 'main'.

Never stage, commit, or push a prompt file under `~/git/*/prompts/` where `{{ code }}` (or any other `{{ … }}` paste placeholder) was replaced by a real card code. Those placeholders stay in the repo; only the chat paste uses the card code. If a prompt is dirty with a substituted code, restore it (`git checkout -- path`) before the commit — do not include that change in the push. See **Prompt templates** in `workflow-policy.md`.

Do not commit product code, secrets, or `.env` files. Do not open a pull request on a company repository.

You may update the card content through OlieFlowAi to record the findings of this review; that is not a product edit and does not replace the author's own product fix. Card notes must follow **Card content vs chat (private prompts)** and **Private E2E suites** in `~/git/olie/prompts/workflow-policy.md` — never recommend prompt paths there; never cite `olie-e2e` / meta-repo Playwright; never mention WorkVM / Card VM / sandboxes / dispatcher / ledger (describe missing product behavior only).

## 4. Branches to test

Prefer the branch already checked out by the dispatcher. If you must check out yourself:

1. Find the branch the author created on each company repository the card touches.
2. Check it out so you can run the feature.
3. If that branch does not exist yet, create it from the repository's base (`develop` or `master`, as that repository uses).
4. Do not rename their branch and do not commit on it.

Leave unrelated local changes untouched. If a checkout would overwrite them, stop and report the blocker.

## 5. Temporary E2E CAPTCHA

Follow **Temporary E2E CAPTCHA** in `~/git/olie/prompts/implementation.md` §7. Short form: Google's public **test secret** in local `api-main` `.env` + optional **test site key** in `packages/management/.env.development.local` for browser login. Do not stub the management API. Do not comment out or delete `RecaptchaValidate` / front `getToken()` code. Never commit those env overrides.

## 6. What to verify

- The behavior matches the card, including the edge cases the card states.
- When the change charges a card or depends on payment authorization, pay with the numbers in **Payment test cards** in `~/git/olie/prompts/workflow-policy.md`. Do not use a real card. Cover the outcomes the card requires (success, unauthorized, processing then success, processing then failure).
- The pull request contains that behavior and does not smuggle unrelated changes.
- Light and dark theme text contrast both hold on the screens the card changes.
- Do not edit `en.json`, and do not fail the review for missing or outdated English strings there. English translations are resolved later. A new key in 'pt-br.json' without a matching 'en.json' entry is not a defect.

If `olie-fronts` changed, the e2e tests in section 3 cover the requested frontend behavior, or you say which case could not be automated and why.

## 7. Out of scope

- Do not fix the author's code.
- Do **not** move the card to 'Corrigir' or 'Validação' / approve — the dispatcher applies **Colleague review outcome** after all parallel gates finish.
- Do not treat a local-only success as the production check. That check is 'Revisão de Produção'.
- Do not search for related improvements in this pass. This is a review only.
- Do not run `test-gap-analysis.md` or `mutation-testing.md` from here when the dispatcher already launched them.

## 8. Return to the dispatcher

- Card {{ code }}.
- Assigned owner(s) from the card ('atribuído a').
- Repositories and branches reviewed.
- **Colleague verdict:** Pass or Fail, with the requirement that failed or passed.
- Contrast result for light and dark themes.
- E2E tests added or extended, and the 'main' commit if one was pushed — or which case could not be automated and why.
- Payment / CAPTCHA checks when relevant (ok / N/A / blocked).
- Checks that did not run, and why.

If fail: write the findings into the card content through OlieFlowAi (findings only; no prompt paths — see **Card content vs chat** in `workflow-policy.md`). Do **not** approve PRs on a fail.

A failed requirement is a failed colleague review. Return that verdict to the dispatcher; do not call the card ready for 'Validação' yourself.
