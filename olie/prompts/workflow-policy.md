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
7. `done` — normally displayed as 'concluído'

The live label wins if it differs from the examples above. `changes-requested` may appear as 'corrigir' or 'corrigir ou melhorar'.

## Moving a card on the board

Resolve **card id** and **funnel steps** through MCP `olie-flow-ai` (search by card code). Never hard-code `step_id`. Never paste a Bearer token into a prompt, chat, or repo file.

1. Load the card via MCP. Take its project/card id (UUID) and the live funnel steps for that board.
2. Match the target logical stage to a live step by display name (`workflow-policy` board stages above).
3. Prefer an MCP tool that moves the card when one exists and works.
4. If you must call the management HTTP API directly:

```bash
curl -sS --url 'https://api.olie.ai/api/management/project-bulk-step-move' \
  -H 'accept: application/json' \
  -H "authorization: Bearer ${OLIE_FLOW_AI_TOKEN}" \
  -H 'content-type: application/json' \
  --data-raw "{\"project_ids\":[\"${CARD_PROJECT_ID}\"],\"step_id\":${TARGET_STEP_ID},\"unlink_others\":true,\"force_funnel_link\":false}"
```

- `OLIE_FLOW_AI_TOKEN` — same token as MCP (`~/.config/environment.d/*.conf`, `chmod 600`). Same value the Cursor MCP header uses.
- `CARD_PROJECT_ID` — UUID from MCP for that card (the `project_ids` array entry).
- `TARGET_STEP_ID` — numeric id of the matched live funnel step (e.g. 'Em progresso'), never a remembered constant.

Verify the card's stage after the call. On non-2xx, missing env, or ambiguous funnel match: stop and report (prompt-health rules).

## Starting a project execution (claim work)

When you **begin working** on a card in a given stage (implement, correct, colleague review, or production review), start a project execution so the board shows you are active on that step. Do this **after** any required stage move has succeeded. Resolve UUID and `funnel_step_id` from MCP / the live funnel — never hard-code them. Never paste a Bearer token.

1. `CARD_PROJECT_ID` — UUID from MCP for the card.
2. `FUNNEL_STEP_ID` — numeric id of the live step that matches the stage you are working in now (e.g. 'Em progresso' while implementing/correcting; 'QA/CR' while colleague-reviewing; 'Revisão de Produção' while production-reviewing).
3. Prefer an MCP tool that starts an execution when one exists and works.
4. HTTP fallback:

```bash
curl -sS --url "https://api.olie.ai/api/management/projects/${CARD_PROJECT_ID}/project-executions" \
  -H 'accept: application/json' \
  -H "authorization: Bearer ${OLIE_FLOW_AI_TOKEN}" \
  -H 'content-type: application/json' \
  --data-raw "{\"funnel_step_id\":${FUNNEL_STEP_ID}}"
```

On non-2xx, missing env, or ambiguous step match: stop and report (prompt-health rules). Do not continue the paste as if execution had started.

## Language

- UI copy, user-facing product content, and card notes are Brazilian Portuguese.
- Commit messages, pull request titles, and pull request bodies are English.
- Do not edit `en.json`. English translations are resolved later. New or changed UI keys go in `pt-br.json` only.

## Formatting

- During implementation, do not run Pint unless the user explicitly asks for it or the task is the pre-QA workflow.
- During pre-QA, run Pint for affected `api-main` PHP changes. If Pint changes files, isolate those formatting-only changes in a dedicated commit; do not create an empty formatting commit.

## Tooling failures and stalls (prompt health)

If a request, MCP call, shell command, Docker/compose wait, git/gh, or other step **this prompt assumes will work** fails or takes unusually long, **stop**. Do not silently work around it or swap tools to hide the break.

Report:

1. What you were doing
2. The objective error (status, short message) or that it hung past a reasonable wait
3. The most likely cause
4. That this likely means **this prompt (or its assumptions) needs to be updated**

Then wait for the user. Expected failures of the current task (e.g. testing an error path) can be reported and continued when that still makes sense.
