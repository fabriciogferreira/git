# Olie Workflow Policy

Use this file when another Olie prompt needs a shared workflow decision. It prevents the same policy from diverging across card-development, review, and handoff prompts.

## Board stages

The OlieFlowAi project funnel is the source of truth for stage display names and IDs. Read the card and its funnel before moving a card:

- Never hard-code a funnel-step ID.
- Match a stage by its live display name, case-insensitively after trimming whitespace.
- If no unique matching live stage exists, report the available stages and stop before moving the card.

The logical lifecycle is:

1. `not-started` — normally displayed as 'Não iniciado'
2. `in-progress` — normally displayed as 'Em progresso'
3. `quality-review` — normally displayed as 'QA/CR'
4. `changes-requested` — normally displayed as 'corrigir ou melhorar'
5. `validation` — normally displayed as 'validação'
6. `production-review` — normally displayed as 'Revisão de Produção'

The live label wins if it differs from the examples above.

## Language

- UI copy, user-facing product content, and card notes are Brazilian Portuguese.
- Commit messages, pull request titles, and pull request bodies are English.

## Formatting

- During implementation, do not run Pint unless the user explicitly asks for it or the task is the pre-QA workflow.
- During pre-QA, run Pint for affected `api-main` PHP changes. If Pint changes files, isolate those formatting-only changes in a dedicated commit; do not create an empty formatting commit.
