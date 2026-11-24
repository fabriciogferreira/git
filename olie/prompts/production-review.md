# Production Review

Use this for a card in the logical `production-review` stage.

If MCP (any configured server), requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: **stop this prompt**, report the objective error, and offer **`resolva` / `documente` / `resolva permanentemente`** (see **Chat commands** / **Tooling failures** in `workflow-policy.md`) and wait. Do not silently work around it, swap tools to hide the break, or keep reviewing. If the failure looks like a wrong assumption in this prompt (bad command or missing step), also say that **this prompt may need updating**. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy — do not call `mcp_auth` and do not ask the user to sign in again for that case only. Shared detail: `~/git/olie/prompts/workflow-policy.md`. A reCAPTCHA challenge during login is the handoff in **Before testing**, not this stop.

## Objective

Verify the card's acceptance criteria in production. A local or staging result is not evidence of production behavior.

## Before testing

0. **Host card environment** — `~/git/bin/workvm-host-card ensure --project olie --code '{{ code }}'` (**Host card environment** in `~/git/olie/prompts/workflow-policy.md`). Resume across days. Local stack is for notes/media/workspace; **production evidence** remains gui1 (below), not localhost.
1. Load card `{{ code }}` through OlieFlowAi and read its acceptance criteria, deployed pull requests or release, and any production prerequisites. Also read every project thread and the latest version of each one (**Reading the project notebook** in `~/git/olie/prompts/workflow-policy.md`). Acceptance criteria also come from those notebook page texts.
2. **Review the card's media** before production checks so acceptance criteria and expected UI are clear. Prefer analyses already under `~/git/olie/cards/{CARD_CODE}/` from implementation or correction; analyze any that are still missing:
   1. `git pull` the meta-repo if needed, then list media via MCP `get-project-media-tool` with **`filter: "default"`** (required — see **Project media** in `workflow-policy.md`; do not use the tool default `content`).
   2. For each image, video, or audio that defines expected production behavior:
      - If `~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md` exists and is non-empty → **Read** it. Do not re-analyze.
      - If that file is **missing** → analyze now: `olie-project-image-analysis` / `olie-project-video-conversion` (API first; agent-local fallback when vid2agent is unreachable). Write the `.md` under `~/git/olie/cards/{CARD_CODE}/`.
   3. Re-analyze **only** when the user asks to redo a specific media id.
   4. Cite media ids in the report when they define the criterion you verified.
   5. **Never** post analysis to project content. Leave new analysis files on disk only during this media pass — do **not** commit or push here. Commit/push them in this prompt’s closing meta-repo step (develop uses `pre-qa.md` §4.3).
3. Production is the **gui1** frame. Open **https://gui1.olie.ai/auth/login** and sign in with email `fgoncalves@olie.ai` and password `@olie123`. Do not begin checks until that login succeeds. Identify the observable success and error paths for the card. Stop and report any missing prerequisite rather than guessing or inventing credentials. Do not use `https://esolie.olie.ai`, `*.olie.localhost`, or other hosts as production evidence.
4. When the card needs a **second live collaborator session** (e.g. deactivate someone and prove their API / realtime access dies), use the disposable gui1 account email `ofzvnvxbeabwykltiw@vtmpj.com` and password `ofzvnvxbeabwykltiw@vtmpj.com2`. Keep the primary account as admin; open that second account in another tab or browser profile. Prefer this account over deactivating real teammates. Reactivate it before you finish if you deactivated it.
5. If the login shows a reCAPTCHA challenge, stop at once. Do not select images, do not press verify, and do not wait on it. Unlock the browser if it is locked, leave that tab open on the challenge, and ask the user to solve it. Continue only after they confirm and the login has reached the app. Solving the challenge is not part of this review. The handoff is expected: it is not a tooling failure and it does not make the review blocked.
6. Do not repeat the login password, tokens, personal data, or private production records in the report.

**Re-run budget:** after Pass/Fail/Blocked for the current production deploy in this chat, do not re-smoke the same paths “to confirm” unless deploy/data changed or the user asks to retry a failed/blocked check. Shared rule: **Expensive re-run budget** in `workflow-policy.md`.

## Verify

1. Test the primary acceptance path in the gui1 frame at https://gui1.olie.ai, after the login above (navigate from the page login opens to the feature the card changed).
2. Test the relevant error or edge path when the card specifies one or production-safe data makes it possible.
3. When the acceptance path charges a card, pay with the numbers in **Payment test cards** in `~/git/olie/prompts/workflow-policy.md`. Do not use a real card. Record which number you used and the order and transaction state you observed. Cover the outcomes the card requires.
4. Record concise evidence: production URL or feature area, action, expected result, and observed result. Redact sensitive values.
5. Compare the deployed behavior to the card, not merely to local behavior.

## Result

Report the verdict first. **Do not move the card yet.**

- **Pass:** Report each verified acceptance criterion and the production evidence. Proposed next stage: `done` ('concluído').
- **Fail:** Report the failed criterion, reproducible production-safe steps, expected and actual result, impact, and the deployed branch or release when known. Do not implement a fix during this review. Proposed next stage: `changes-requested` ('corrigir' / 'corrigir ou melhorar').
- **Blocked:** Report the missing access, data, deployment, or other prerequisite and its impact. Do not claim the production review passed. Do not propose a stage move until the block is cleared or the user decides.

### Ask before moving

After a **Pass** or **Fail** report, ask the user a single **yes/no** question, for example:

- Pass: `Move card {{ code }} to 'concluído'? (yes/no)`
- Fail: `Move card {{ code }} to 'corrigir'? (yes/no)`

Move **only** if the user answers yes (or an unambiguous equivalent). If the user answers no, leave the card where it is and stop.

When yes: resolve the live step id by display name via MCP / `~/git/olie/prompts/workflow-policy.md` (**Moving a card on the board**). Never hard-code step ids. Verify the transition succeeded.

**After a successful move to `done` ('concluído'):** run host-card teardown — `~/git/bin/workvm-host-card destroy --project olie --code '{{ code }}'`, then stop the **main** project compose (`docker compose -f ~/git/olie/docker-compose.yml down` — **Destroy** in `workflow-policy.md`). Do **not** destroy on Fail → Corrigir, on Blocked, or when the user answers no to the move.

## Done when

The report identifies card `{{ code }}`, the production area tested, the result for every applicable acceptance criterion, whether a move was proposed, the user's yes/no answer, whether the stage change ran, and whether host-card `destroy` ran after `done`. It clearly distinguishes pass, fail, and blocked checks.

**Evidence table (required):** after the Pass/Fail/Blocked report, post `### Evidência — {N}º Revisão produção` into the **card content** via `save-media-tool` per **Evidence table on project content** in `~/git/olie/prompts/workflow-policy.md` (production smoke / deploy rows; `n/a` where a develop-only check does not apply; never description, Caderno, or PR).

**Meta-repo close (media analyses):** if this review wrote new files under `olie/cards/{CARD_CODE}/`, commit and push them on the meta-repo **before** `destroy` / before ending the paste (host-card worktree; same rules as `pre-qa.md` §4.3). See **Card media analyses** in `workflow-policy.md`.
