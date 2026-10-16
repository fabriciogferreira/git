# Locav Workflow Policy

Use this file when another Locav prompt needs a shared workflow decision. It prevents the same policy from diverging across card-development, review, and handoff prompts.

## Board stages

The OlieFlowAi project funnel is the source of truth for stage display names and IDs. Read the card and its funnel before moving a card:

- Never hard-code a funnel-step ID.
- Match a stage by its live display name, case-insensitively after trimming whitespace.
- If no unique matching live stage exists, report the available stages and stop before moving the card.

Locav develop lifecycle (logical key → live display name on this board):

1. `not-started` — 'Não iniciado'
2. `in-progress` — 'Em andamento'
3. `quality-review` — 'QA/CR'
4. `changes-requested` — 'Corrigir'
5. `validation` — 'Validação'
6. `production-review` — 'Revisão em Produção'
7. `done` — 'Concluído'

Earlier board stages ('Backlog', 'Planejamento') and terminal 'Cancelado/Duplicado' are outside the develop handoff prompts. Do not take work from them unless the user explicitly asks.

The live label wins if it differs from the examples above. Resolve the numeric step id from MCP / the live funnel at move time — never from memory.

## Moving a card on the board

Resolve **card id** and **funnel steps** through MCP `olie-flow-ai` (search by card code). Never hard-code `step_id`. Never paste a Bearer token into a prompt, chat, or repo file.

1. Load the card via MCP. Take its project/card id (UUID) and the live funnel steps for that board.
2. Match the target logical stage to a live step by display name (`workflow-policy` board stages above).
3. Prefer an MCP tool that moves the card when one exists and works.
4. If you must call the management HTTP API directly:

```bash
curl -sS --url 'https://api.olie.ai/api/management/project-bulk-step-move' \
  -H 'accept: application/json' \
  -H "authorization: Bearer ${OLIE_MANAGEMENT_TOKEN}" \
  -H 'content-type: application/json' \
  --data-raw "{\"project_ids\":[\"${CARD_PROJECT_ID}\"],\"step_id\":${TARGET_STEP_ID},\"unlink_others\":true,\"force_funnel_link\":false}"
```

- `OLIE_MANAGEMENT_TOKEN` — Bearer for management HTTP only (`~/.config/environment.d/*.conf`, `chmod 600`). Not the MCP token (`OLIE_FLOW_AI_MCP_TOKEN`).
- `CARD_PROJECT_ID` — UUID from MCP for that card (the `project_ids` array entry).
- `TARGET_STEP_ID` — numeric id of the matched live funnel step (e.g. 'Em andamento'), never a remembered constant.

Verify the card's stage after the call. On non-2xx, missing env, or ambiguous funnel match: stop and report (prompt-health rules).

## Starting a project execution (claim work)

When you **begin working** on a card in a given stage (implement, correct, colleague review, or production review), start a project execution so the board shows you are active on that step. Do this **after** any required stage move has succeeded. Resolve UUID and `funnel_step_id` from MCP / the live funnel — never hard-code them. Never paste a Bearer token.

1. `CARD_PROJECT_ID` — UUID from MCP for the card.
2. `FUNNEL_STEP_ID` — numeric id of the live step that matches the stage you are working in now (e.g. 'Em andamento' while implementing/correcting; 'QA/CR' while colleague-reviewing; 'Revisão em Produção' while production-reviewing).
3. Prefer an MCP tool that starts an execution when one exists and works.
4. HTTP fallback:

```bash
curl -sS --url "https://api.olie.ai/api/management/projects/${CARD_PROJECT_ID}/project-executions" \
  -H 'accept: application/json' \
  -H "authorization: Bearer ${OLIE_MANAGEMENT_TOKEN}" \
  -H 'content-type: application/json' \
  --data-raw "{\"funnel_step_id\":${FUNNEL_STEP_ID}}"
```

On non-2xx, missing env, or ambiguous step match: stop and report (prompt-health rules). Do not continue the paste as if execution had started.

## Reading the project forum

The card from MCP is not the whole spec. Before deciding what to implement, correct, or review, also read every thread on that project and the text of the **latest version** of each thread.

`CARD_PROJECT_ID` is the project UUID from MCP (the same id used in `project_ids`). Never hard-code it. Never paste a Bearer token; use `${OLIE_MANAGEMENT_TOKEN}`. Do not copy browser headers (sentry, sec-ch-ua, cookies, socket id).

1. Load the forum:

```bash
curl -sS --url 'https://api.olie.ai/api/management/get-forum' \
  -H 'accept: application/json' \
  -H "authorization: Bearer ${OLIE_MANAGEMENT_TOKEN}" \
  -H 'content-type: application/json' \
  --data-raw '{"model_class":"App\\Models\\Project","model_id":"'"${CARD_PROJECT_ID}"'"}'
```

2. Take `forum.id` as `FORUM_ID`. Walk `forum.threads` and every nested `children` array. Collect each thread's `id` and `name`, including the default thread. Do not stop at `default_thread_id`.
3. For each thread, load its versions:

```bash
curl -sS --url "https://api.olie.ai/api/management/get-thread/${FORUM_ID}/${THREAD_ID}" \
  -H 'accept: application/json' \
  -H "authorization: Bearer ${OLIE_MANAGEMENT_TOKEN}"
```

4. From `thread.versions`, choose the version with the latest `created_at`. That id is `VERSION_ID`. If `versions` is empty, note the thread name and continue with the others.
5. Load that version. The body is a TipTap document; read its text. That text is part of what the card asks for.

```bash
curl -sS --url "https://api.olie.ai/api/management/get-thread-data/${FORUM_ID}/${THREAD_ID}?version=${VERSION_ID}" \
  -H 'accept: application/json' \
  -H "authorization: Bearer ${OLIE_MANAGEMENT_TOKEN}"
```

On non-2xx or missing env: stop and report (prompt-health rules). Do not implement from the card title or the MCP card alone when the forum call failed.

## Language

- UI copy, user-facing product content, and card notes are Brazilian Portuguese.
- Commit messages, pull request titles, and pull request bodies are English.

## Formatting

- During implementation, do not run Pint unless the user explicitly asks for it or the task is the pre-QA workflow.
- During pre-QA, run Pint for affected `LocavApi` PHP changes (`docker exec locav-backend`). If Pint changes files, isolate those formatting-only changes in a dedicated commit; do not create an empty formatting commit.

## Tooling failures and stalls (prompt health)

If a request, MCP call, shell command, Docker/compose wait, git/gh, or other step **this prompt assumes will work** fails or takes unusually long, **stop**. Do not silently work around it or swap tools to hide the break.

Report:

1. What you were doing
2. The objective error (status, short message) or that it hung past a reasonable wait
3. The most likely cause
4. That this likely means **this prompt (or its assumptions) needs to be updated**

Then wait for the user. Expected failures of the current task (e.g. testing an error path) can be reported and continued when that still makes sense.
