# Workday

Use this at the start of the day, and again whenever the current card is no longer the next action. Text inside single quotes is a board label or a field name. Do not rename it.

Do not repeat `project.md`, `implementation.md`, `pre-qa.md`, `colleague-review.md`, `correction.md`, `production-review.md`, or `recommendation.md`. Those files say how to execute or review. This file says the order.

Resolve the live board labels and IDs through OlieFlowAi as described in `workflow-policy.md`. The labels below are examples, not a substitute for the live funnel.

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
| 'validação' | Tech lead | Approve or send it back. |
| 'Revisão de Produção' | You, once the change is in production | Confirm production behavior. Local success is not enough. |

## 1. Colleague QA/CR

Review cards sitting in 'QA/CR' that belong to colleagues. Follow `colleague-review.md`. Do not open a pull request on a company repository for them. Do not move their card unless the review result says where it goes:

- Failed: the card goes to 'corrigir' ou melhorar.
- Passed: the card goes to 'validação'.

## 2. Production review

Review cards in 'Revisão de Produção' that are already in production with `production-review.md`.

## 3. Choose a card

After steps 1 and 2:

- If you already have a card in 'Em progresso', continue that card.
- Otherwise take a card from 'Não iniciado'. A card whose 'atribuído a' is you comes before any card with 'atribuído a' empty.
- Do not take a card assigned to someone else.

Move the card you take to 'Em progresso', then execute it with `implementation.md`.

## 4. Hand off

When the requested behavior is implemented, move the card to 'QA/CR' so a teammate can review it. Run `pre-qa.md` before that move.

You do not perform 'validação'. The tech lead does.

- Tech lead approves: the card goes to 'Revisão de Produção'.
- Tech lead rejects: the card returns to 'corrigir' ou melhorar.

## 5. Fix loop

When your card is in `changes-requested`, follow `correction.md`. That prompt moves it to `in-progress` and applies the review fixes.

Then hand it off to 'QA/CR' again. Repeat until the card leaves 'corrigir' ou melhorar toward 'validação', and the tech lead sends it to 'Revisão de Produção'.

## 6. Production

When the card reaches 'Revisão de Produção' and the change is in production, review it as in step 2.

## Out of scope

- Do not skip colleague 'QA/CR' or 'Revisão de Produção' to start a new card.
- Do not move a card to 'validação' or 'Revisão de Produção' on your own approval.
- Do not implement during a review pass. `recommendation.md` only applies while executing a card, and only when that prompt is in use.

## Done when

The report says which queue you worked, which card you touched, which stage it is in now, and whether production was actually checked. If a queue was empty, say so.
