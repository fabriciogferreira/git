# Production Review

Use this for a card in the logical `production-review` stage.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

## Objective

Verify the card's acceptance criteria in production. A local or staging result is not evidence of production behavior.

## Before testing

1. Load card `{{ code }}` through OlieFlowAi and read its acceptance criteria, deployed pull requests or release, and any production prerequisites.
2. Identify the production URL, permitted account or data, and observable success and error paths. Stop and report any missing prerequisite rather than guessing or using customer credentials.
3. Do not expose credentials, tokens, personal data, or private production records in the report.

## Verify

1. Test the primary acceptance path in production.
2. Test the relevant error or edge path when the card specifies one or production-safe data makes it possible.
3. Record concise evidence: URL or feature area, action, expected result, and observed result. Redact sensitive values.
4. Compare the deployed behavior to the card, not merely to local behavior.

## Result

- **Pass:** Report each verified acceptance criterion and the production evidence. Do not move the card automatically.
- **Fail:** Report the failed criterion, reproducible production-safe steps, expected and actual result, impact, and the deployed branch or release when known. Do not implement a fix during this review.
- **Blocked:** Report the missing access, data, deployment, or other prerequisite and its impact. Do not claim the production review passed.

## Done when

The report identifies card `{{ code }}`, the production area tested, the result for every applicable acceptance criterion, and any follow-up owner or action. It clearly distinguishes pass, fail, and blocked checks.
