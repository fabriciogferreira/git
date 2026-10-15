# Production Review

Use this for a card in the logical `production-review` stage.

If MCP, requests, shell, Docker, or other tooling this prompt assumes 
will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Shared detail: `~/git/locav/prompts/workflow-policy.md`.

## Objective

Verify the card's acceptance criteria in production. A local or staging result is not evidence of production behavior.

## Before testing

1. Load card `{{ code }}` through OlieFlowAi and read its acceptance criteria, deployed pull requests or release, and any production prerequisites.
2. Start a project execution on the live 'Revisão em Produção' funnel step for this card (see **Starting a project execution** in `~/git/locav/prompts/workflow-policy.md`). That records that you are reviewing in production. Resolve UUID and `funnel_step_id` from MCP; use `OLIE_FLOW_AI_TOKEN`. Do not begin production checks until execution has started successfully.
3. Identify the production URL, permitted account or data, and observable success and error paths. Stop and report any missing prerequisite rather than guessing or using customer credentials.
4. Do not expose credentials, tokens, personal data, or private production records in the report.

## Verify

1. Test the primary acceptance path in production.
2. Test the relevant error or edge path when the card specifies one or production-safe data makes it possible.
3. Record concise evidence: URL or feature area, action, expected result, and observed result. Redact sensitive values.
4. Compare the deployed behavior to the card, not merely to local behavior.

## Result

Report the verdict first. **Do not move the card yet.**

- **Pass:** Report each verified acceptance criterion and the production evidence. Proposed next stage: `done` ('Concluído').
- **Fail:** Report the failed criterion, reproducible production-safe steps, expected and actual result, impact, and the deployed branch or release when known. Do not implement a fix during this review. Proposed next stage: `changes-requested` ('Corrigir' / 'Corrigir').
- **Blocked:** Report the missing access, data, deployment, or other prerequisite and its impact. Do not claim the production review passed. Do not propose a stage move until the block is cleared or the user decides.

### Ask before moving

After a **Pass** or **Fail** report, ask the user a single **yes/no** question, for example:

- Pass: `Move card {{ code }} to 'Concluído'? (yes/no)`
- Fail: `Move card {{ code }} to 'Corrigir'? (yes/no)`

Move **only** if the user answers yes (or an unambiguous equivalent). If the user answers no, leave the card where it is and stop.

When yes: resolve the live step id by display name via MCP / `~/git/locav/prompts/workflow-policy.md` (**Moving a card on the board**). Never hard-code step ids. Verify the transition succeeded.

## Done when

The report identifies card `{{ code }}`, the production area tested, the result for every applicable acceptance criterion, whether a move was proposed, the user's yes/no answer, and whether the stage change ran. It clearly distinguishes pass, fail, and blocked checks.
