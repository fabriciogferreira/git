# Production Review

Use this for a card in the logical `production-review` stage.

If MCP, requests, shell, Docker, or other tooling this prompt assumes 
will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/olie/prompts/workflow-policy.md`. A reCAPTCHA challenge during login is the handoff in **Before testing**, not this stop.

## Objective

Verify the card's acceptance criteria in production. A local or staging result is not evidence of production behavior.

## Before testing

1. Load card `{{ code }}` through OlieFlowAi and read its acceptance criteria, deployed pull requests or release, and any production prerequisites.
2. Production is the **gui1** frame. Open **https://gui1.olie.ai/auth/login** and sign in with email `fgoncalves@olie.ai` and password `@olie123`. Do not begin checks until that login succeeds. Identify the observable success and error paths for the card. Stop and report any missing prerequisite rather than guessing or using another account. Do not use `https://esolie.olie.ai`, `*.olie.localhost`, or other hosts as production evidence.
3. If the login shows a reCAPTCHA challenge, stop at once. Do not select images, do not press verify, and do not wait on it. Unlock the browser if it is locked, leave that tab open on the challenge, and ask the user to solve it. Continue only after they confirm and the login has reached the app. Solving the challenge is not part of this review. The handoff is expected: it is not a tooling failure and it does not make the review blocked.
4. Do not repeat the login password, tokens, personal data, or private production records in the report.

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

## Done when

The report identifies card `{{ code }}`, the production area tested, the result for every applicable acceptance criterion, whether a move was proposed, the user's yes/no answer, and whether the stage change ran. It clearly distinguishes pass, fail, and blocked checks.
