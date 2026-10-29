# Colleague Card Review

Review card {{ code }} while it sits in 'QA/CR'. This is a review of someone else's card, not preparation of your own (pre-QA).

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

For `~/git/`, do not create a card branch. Commit and push the e2e changes directly to 'main'.

Do not commit product code, secrets, or `.env` files. Do not open a pull request on a company repository.

## 4. Branches to test

On each company repository the card touches:

1. Find the branch the author created.
2. Check it out so you can run the feature.
3. If that branch does not exist yet, create it from the repository's base (`develop` or `master`, as that repository uses).
4. Do not rename their branch and do not commit on it.

Leave unrelated local changes untouched. If a checkout would overwrite them, stop and report the blocker.

## 5. Temporary E2E CAPTCHA

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

## 6. What to verify

- The behavior matches the card, including the edge cases the card states.
- When the change charges a card or depends on payment authorization, pay with the numbers in **Payment test cards** in `~/git/olie/prompts/workflow-policy.md`. Do not use a real card. Cover the outcomes the card requires (success, unauthorized, processing then success, processing then failure).
- The pull request contains that behavior and does not smuggle unrelated changes.
- Light and dark theme text contrast both hold on the screens the card changes.
- Do not edit `en.json`, and do not fail the review for missing or outdated English strings there. English translations are resolved later. A new key in 'pt-br.json' without a matching 'en.json' entry is not a defect.

If `olie-fronts` changed, the e2e tests in section 3 cover the requested frontend behavior, or you say which case could not be automated and why.

## 7. Out of scope

- Do not fix the author's code.
- Do not move the card. Report the result; the user (or a later workday paste) decides the next stage.
- Do not treat a local-only success as the production check. That check is 'Revisão de Produção'.
- Do not search for related improvements in this pass. This is a review only.

## 8. Report

- Card {{ code }}.
- Repositories and branches reviewed.
- Whether the implementation matches the card, with the requirement that failed or passed.
- Contrast result for light and dark themes.
- E2E tests added or extended, and the 'main' commit if one was pushed.
- Checks that did not run, and why.

A failed requirement is a failed review. Do not call the card ready for 'validação' while one remains open.
