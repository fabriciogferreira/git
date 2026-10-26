# Colleague Card Review

Review card {{ code }} while it sits in 'QA/CR'. This is a review of someone else's card, not preparation of your own (pre-QA).

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

## 1. Objective

Decide whether the implementation does what the card requested. Report the result. Do not implement the card.

The card's requirements and acceptance criteria are the source of truth. A change that works but does not match the card is not a pass.

## 2. Context

Load the card through `mcp olie-flow-ai`. Read:

- The description, requirements, and acceptance criteria.
- The repositories and branches the author changed.
- The pull requests and the commits on those branches.
- Comments, attachments, and test notes.

Do not review from the card title alone.

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
