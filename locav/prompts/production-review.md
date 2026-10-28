# Production Review

Use this for a card in the logical `production-review` stage.

If MCP, requests, shell, Docker, or other tooling this prompt assumes 
will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/locav/prompts/workflow-policy.md`.

## Objective

Verify the card's acceptance criteria in production. A local or staging result is not evidence of production behavior.

## Before testing

1. Load card `{{ code }}` through OlieFlowAi and read its acceptance criteria, deployed pull requests or release, and any production prerequisites.
2. **Review the card's media** before production checks so acceptance criteria and expected UI are clear. Prefer analyses already under `~/git/locav/cards/{CARD_CODE}/` from implementation or correction; analyze any that are still missing:
   1. `git pull` the meta-repo if needed, then list media via MCP (`get-project-media-tool`).
   2. For each image, video, or audio that defines expected production behavior:
      - If `~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md` exists and is non-empty → **Read** it. Do not re-analyze.
      - If that file is **missing** → analyze now: `locav-project-image-analysis` / `locav-project-video-conversion` (API first; agent-local fallback when vid2agent is unreachable). Write the `.md` under `~/git/locav/cards/{CARD_CODE}/`.
   3. Re-analyze **only** when the user asks to redo a specific media id.
   4. Cite media ids in the report when they define the criterion you verified.
   5. **Never** post analysis to project content. Commit/push new analysis files on the meta-repo when you finish this media pass (or when the user asks).
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
