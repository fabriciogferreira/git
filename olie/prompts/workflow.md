# Workday

Use this at the start of the day, and again whenever the current card is no longer the next action. Text inside single quotes is a board label or a field name. Do not rename it.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

This paste is **only the workday order**. Do not invent a full implementation or review workflow here. When a stage needs execution, open the matching file under `~/git/olie/prompts/` (or wait for the user to paste it).

Resolve the live board labels and IDs through OlieFlowAi as described in `~/git/olie/prompts/workflow-policy.md`. The labels below are examples, not a substitute for the live funnel.

## Order

1. Review colleagues' cards in 'QA/CR'.
2. Review cards in 'Revisão de Produção'.
3. Only then develop: continue a card already in progress, or take the next card from 'Não iniciado'.

Do not start development while a card is waiting in step 1 or step 2.

## Board

| Stage | Who acts | What happens |
| --- | --- | --- |
| 'Não iniciado' | Tech lead places the card. You take it when it is your turn to develop. | The field 'atribuído a' says who must solve it. |
| 'Em progresso' | You | Execute the card. |
| 'QA/CR' | A teammate, or you when the card is a colleague's | Quality review before a tech lead sees it. |
| `changes-requested` (normally 'corrigir ou melhorar') | The person who owns the card | The review failed. Fix it. |
| 'validação' | Tech lead | Approve or send it back. Use `~/git/olie/prompts/validation.md`. |
| 'Revisão de Produção' | You, once the change is in production | Confirm production behavior. Local success is not enough. After the report, ask yes/no before moving to 'concluído' (pass) or 'corrigir' (fail). |
| 'concluído' | — | Production review passed and the user allowed the move. |

## 1. Colleague QA/CR

Review cards sitting in 'QA/CR' that belong to colleagues. Use `~/git/olie/prompts/colleague-review.md`. Do not open a pull request on a company repository for them. Do not move their card unless the review result says where it goes:

- Failed: the card goes to 'corrigir' ou melhorar.
- Passed: the card goes to 'validação'.

## 2. Production review

Review cards in 'Revisão de Produção' that are already in production with `~/git/olie/prompts/production-review.md`. Production checks use https://esolie.olie.ai/overview (see **Production verification URL** in `~/git/olie/prompts/workflow-policy.md`).

## 3. Choose a card

After steps 1 and 2:

- If you already have a card in 'Em progresso', continue that card.
- Otherwise take a card from 'Não iniciado'. A card whose 'atribuído a' is you comes before any card with 'atribuído a' empty.
- Do not take a card assigned to someone else.

Execute the card with `~/git/olie/prompts/implementation.md` (that prompt moves 'Não iniciado' → 'Em progresso' when needed).

## 4. Hand off (your card in 'Em progresso')

After implementation (or correction) on the card:

1. **Implementation validation** — `~/git/olie/prompts/implementation-validation.md` (code only; no PRs/forms/commits required).
2. **Pre-QA** — `~/git/olie/prompts/pre-qa.md` (commits, PRs, forms, checklist) only after implementation-validation passes. When every applicable pre-QA check passes, that prompt **moves the card to 'QA/CR'**.

Colleague 'QA/CR' uses `~/git/olie/prompts/colleague-review.md`.

Board **'validação'** (tech lead, after colleague QA/CR) uses `~/git/olie/prompts/validation.md` — PRs, forms, and handoff readiness. Do not use it right after implementation.

- Tech lead approves: the card goes to 'Revisão de Produção'.
- Tech lead rejects: the card returns to 'corrigir' ou melhorar.

## 5. Fix loop

When your card is in `changes-requested`, follow `~/git/olie/prompts/correction.md`. That prompt moves it to `in-progress` and applies the review fixes.

Then hand it off to 'QA/CR' again. Repeat until the card leaves 'corrigir' ou melhorar toward 'validação', and the tech lead sends it to 'Revisão de Produção'.

## 6. Production

When the card reaches 'Revisão de Produção' and the change is in production, review it as in step 2. That prompt asks yes/no before moving to 'concluído' (pass) or 'corrigir' (fail).

## Out of scope

- Do not skip colleague 'QA/CR' or 'Revisão de Produção' to start a new card.
- Do not move a card to 'validação' or 'Revisão de Produção' on your own approval.
- Do not implement during a review pass. Related-improvements discovery (`~/git/olie/prompts/recommendation.md`) only applies while executing a card, and only when that prompt is in use.

## Done when

The report says which queue you worked, which card you touched, which stage it is in now, and whether production was actually checked. If a queue was empty, say so.
