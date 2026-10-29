# Workday

Use this at the start of the day, and again whenever the current card is no longer the next action. Text inside single quotes is a board label or a field name. Do not rename it.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/locav/prompts/workflow-policy.md`.

This paste is **only the workday order**. Do not invent a full implementation or review workflow here. When a stage needs execution, open the matching file under `~/git/locav/prompts/` (or wait for the user to paste it).

Resolve the live board labels and IDs through OlieFlowAi as described in `~/git/locav/prompts/workflow-policy.md`. The labels below are examples, not a substitute for the live funnel.

## Order

1. Review colleagues' cards in 'QA/CR'.
2. Review cards in 'Revisão em Produção'.
3. Only then develop: continue a card already in progress, or take the next card from 'Não iniciado'.

Do not start development while a card is waiting in step 1 or step 2.

## Board

| Stage | Who acts | What happens |
| --- | --- | --- |
| 'Não iniciado' | Tech lead places the card. You take it when it is your turn to develop. | The field 'atribuído a' says who must solve it. |
| 'Em andamento' | You | Execute the card. |
| 'QA/CR' | A teammate, or you when the card is a colleague's | Quality review before a tech lead sees it. On pass: PRs approved/merged and the card status becomes 'Revisado'; on fail: card to 'Corrigir'. |
| `changes-requested` (normally 'Corrigir') | The person who owns the card | The review failed. Fix it. |
| 'Validação' | Tech lead | Approve or send it back. Use `~/git/locav/prompts/validation.md`. |
| 'Revisão em Produção' | You, once the change is in production | Confirm production behavior. Local success is not enough. After the report, ask yes/no before moving to 'Concluído' (pass) or 'Corrigir' (fail). |
| 'Concluído' | — | Production review passed and the user allowed the move. |

## 1. Colleague QA/CR

Review cards sitting in 'QA/CR' that belong to colleagues. Use `~/git/locav/prompts/colleague-review.md`. Do not open a pull request on a company repository for them.

For each colleague card in 'QA/CR', run the colleague review flow:

1. Start the review on the card's pull requests.
2. Run `~/git/locav/prompts/colleague-review.md`.
3. If the review has comments about what should be fixed, update the card content with them (the card goes to 'Corrigir').
4. Run `~/git/locav/prompts/test-gap-analysis.md` when `LocavApi` and/or `locav-front` changed. Write missing use cases into the card when reported.
5. Run `~/git/locav/prompts/mutation-testing.md` (personal, only if the card changed `LocavApi`). Skip when the change set has no backend. If the mutation run has comments about what should be fixed, update the card content with them.

Outcome: if the pull requests were approved by the prompts, mark them as approved (GitHub MCP review `APPROVE`; only the PRs that passed); if none passed, mark the card as 'request changes'. If all approved, merge all the card's pull requests. When the colleague review passes, change the card status in the funnel to 'Revisado'.

Do not move the card unless the review result says where it goes:

- Failed: the card goes to 'Corrigir'.
- Passed: the card goes to 'Validação'.

## 2. Production review

Review cards in 'Revisão em Produção' that are already in production with `~/git/locav/prompts/production-review.md`.

## 3. Choose a card

After steps 1 and 2:

- If you already have a card in 'Em andamento', continue that card.
- Otherwise take a card from 'Não iniciado'. A card whose 'atribuído a' is you comes before any card with 'atribuído a' empty.
- Do not take a card assigned to someone else.

Execute the card with `~/git/locav/prompts/implementation.md` (that prompt moves 'Não iniciado' → 'Em andamento' when needed).

## 4. Hand off (your card in 'Em andamento')

After implementation (or correction) on the card:

1. **Implementation validation** — `~/git/locav/prompts/implementation-validation.md` (code only; no PRs/forms/commits required).
2. **Test gap analysis** — `~/git/locav/prompts/test-gap-analysis.md` when `LocavApi` and/or `locav-front` changed (backend + frontend).
3. **Mutation testing** (personal, only if the card changed `LocavApi`) — `~/git/locav/prompts/mutation-testing.md`. Skip when the change set has no backend. Not a team gate; do not block handoff forever on it if the user skips.
4. **Pre-QA** — `~/git/locav/prompts/pre-qa.md` (commits, PRs, and forms) after implementation-validation passes, and after gap analysis + mutation when those steps applied. When every applicable pre-QA check passes, that prompt **moves the card to 'QA/CR'**. The Dev - Locav funnel has no step checklists; do not mark 'Pull request created'.

Colleague 'QA/CR' uses `~/git/locav/prompts/colleague-review.md`.

Board **'Validação'** (tech lead, after colleague QA/CR) uses `~/git/locav/prompts/validation.md` — PRs, forms, and handoff readiness. Do not use it right after implementation.

- Tech lead approves: the card goes to 'Revisão em Produção'.
- Tech lead rejects: the card returns to 'Corrigir'.

## 5. Fix loop

When your card is in `changes-requested`, follow `~/git/locav/prompts/correction.md`. That prompt moves it to `in-progress` and applies the review fixes.

Then hand it off to 'QA/CR' again. Repeat until the card leaves 'Corrigir' toward 'Validação', and the tech lead sends it to 'Revisão em Produção'.

## 6. Production

When the card reaches 'Revisão em Produção' and the change is in production, review it as in step 2. That prompt asks yes/no before moving to 'Concluído' (pass) or 'Corrigir' (fail).

## Out of scope

- Do not skip colleague 'QA/CR' or 'Revisão em Produção' to start a new card.
- Do not move a card to 'Validação' or 'Revisão em Produção' on your own approval.
- Do not implement during a review pass. Related-improvements discovery (`~/git/locav/prompts/recommendation.md`) only applies while executing a card, and only when that prompt is in use.

## Done when

The report says which queue you worked, which card you touched, which stage it is in now, and whether production was actually checked. If a queue was empty, say so.
