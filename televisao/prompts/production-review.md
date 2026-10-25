# Production Review

Use this for a card in the logical `production-review` stage.

If MCP, requests, shell, Docker, or other tooling this prompt assumes 
will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/televisao/prompts/workflow-policy.md`.

## Objective

Verify the card's acceptance criteria on the hosted preview below. A local result is not evidence of that behavior.

## Hosted preview

| Surface | URL |
| --- | --- |
| Dashboard | `https://televisao.dashboard.enterscience.com.br/` |
| Meet | `https://televisao-meet-front.dashboard.enterscience.com.br/meet/enterscience` |

| Account | Password |
| --- | --- |
| `admin@enterscience.com.br` | `Juca@1234` |
| `superadmin@televisao.com` | `123123` |

## Before testing

1. Load card `{{ code }}` through OlieFlowAi and read its acceptance criteria, deployed pull requests or release, and any production prerequisites.
2. Test on the hosts and accounts above. Observable success and error paths come from the card. Stop and report a missing prerequisite. Do not guess another host and do not use customer credentials.
3. Do not repeat passwords, tokens, personal data, or private records in the report. Name the account as admin or superadmin when the evidence needs it.

## Verify

1. Test the primary acceptance path on the hosted preview.
2. Test the relevant error or edge path when the card specifies one or production-safe data makes it possible.
3. Record concise evidence: URL or feature area, action, expected result, and observed result. Redact sensitive values.
4. Compare the deployed behavior to the card, not merely to local behavior.

## Result

Report the verdict first. **Do not move the card yet.**

- **Pass:** Report each verified acceptance criterion and the production evidence. Proposed next stage: `done` ('Concluído').
- **Fail:** Report the failed criterion, reproducible production-safe steps, expected and actual result, impact, and the deployed branch or release when known. Do not implement a fix during this review. Proposed next stage: `changes-requested` ('Corrigir').
- **Blocked:** Report the missing access, data, deployment, or other prerequisite and its impact. Do not claim the production review passed. Do not propose a stage move until the block is cleared or the user decides.

### Ask before moving

After a **Pass** or **Fail** report, ask the user a single **yes/no** question, for example:

- Pass: `Move card {{ code }} to 'Concluído'? (yes/no)`
- Fail: `Move card {{ code }} to 'Corrigir'? (yes/no)`

Move **only** if the user answers yes (or an unambiguous equivalent). If the user answers no, leave the card where it is and stop.

When yes: resolve the live step id by display name via MCP / `~/git/televisao/prompts/workflow-policy.md` (**Moving a card on the board**). Never hard-code step ids. Verify the transition succeeded.

## Done when

The report identifies card `{{ code }}`, the production area tested, the result for every applicable acceptance criterion, whether a move was proposed, the user's yes/no answer, and whether the stage change ran. It clearly distinguishes pass, fail, and blocked checks.
