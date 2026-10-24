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
  -H "authorization: Bearer ${OLIE_MANAGEMENT_TOKEN}" \
  -H 'content-type: application/json' \
  --data-raw "{\"project_ids\":[\"${CARD_PROJECT_ID}\"],\"step_id\":${TARGET_STEP_ID},\"unlink_others\":true,\"force_funnel_link\":false}"
```

- `OLIE_MANAGEMENT_TOKEN` — Bearer for management HTTP only (`~/.config/environment.d/*.conf`, `chmod 600`). Not the MCP token. See **Tokens** below.
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
  -H "authorization: Bearer ${OLIE_MANAGEMENT_TOKEN}" \
  -H 'content-type: application/json' \
  --data-raw "{\"funnel_step_id\":${FUNNEL_STEP_ID}}"
```

On non-2xx, missing env, or ambiguous step match: stop and report (prompt-health rules). Do not continue the paste as if execution had started.

## Several cards at once

The board shows one project execution. VMs can run several cards at the same time. The visible execution stays one card.

The list is the signed-in user's Opbed config `board_executions`. Array order is the execution order. Each `card_id` matches `config.cards`. The card `title` is the board code. Read that list from the config. Do not ask for codes in the chat.

The user tells teammates which cards they will take, so those cards are not picked or reviewed by someone else. This chat does not send that message.

1. If `board_executions` is missing or empty, say so and stop.
2. For each row, the card's 'Tempo que eu acho' (`real_time_in_minutes`) must be a positive number of minutes. If any listed card is missing it, name those titles and start nothing.
3. Do not implement, review, move the funnel, or open a pull request in this pass. Only the execution requests, in the stored order.
4. The Job page sends the request in **Starting a project execution** (`POST …/project-executions` with the card's current `funnel_step_id`). One card at a time. It leaves that execution open for the card's 'Tempo que eu acho' minutes, ends it, and only then starts the next. This chat does not send that request and does not ask for the codes.
5. The user works every listed card in parallel on the VMs while those requests run one after another.

If the request that ends an execution fails, stop. Do not open the next execution while the previous one is still the visible one.

## Toggling a funnel-step checklist item

Board checklists on a funnel step (e.g. QA/CR item **Pull request created**) are toggled over management HTTP — not via OlieFlowAi MCP form answers. MCP `get-project-details` may return empty `project_checklists` even when the UI shows items.

```bash
curl -sS --url 'https://api.olie.ai/api/management/toggle-funnel-checklist' \
  -H 'accept: application/json' \
  -H "authorization: Bearer ${OLIE_MANAGEMENT_TOKEN}" \
  -H 'content-type: application/json' \
  --data-raw "{\"project_id\":\"${CARD_PROJECT_ID}\",\"step_checklist_id\":${STEP_CHECKLIST_ID}}"
```

- `CARD_PROJECT_ID` — project UUID from MCP.
- `STEP_CHECKLIST_ID` — numeric id of the checklist row to toggle (resolve from the live board / network for that step; do not invent or hard-code across funnels). Match by the item's display label when discovering (e.g. 'Pull request created').
- Expect `{"response":true}` and HTTP 2xx. On failure: stop and report (prompt-health).

Never paste a Bearer token into a prompt, chat, or repo file — only `${OLIE_MANAGEMENT_TOKEN}` from `environment.d`.

## Tokens

Two env vars in `~/.config/environment.d/*.conf` (`chmod 600`). Never the same value by assumption; never paste into chat or repo files.

| Variable | Use |
| --- | --- |
| `OLIE_FLOW_AI_MCP_TOKEN` | Cursor MCP `olie-flow-ai` only (`mcps/olie.json` → `${env:OLIE_FLOW_AI_MCP_TOKEN}`) |
| `OLIE_MANAGEMENT_TOKEN` | HTTP `https://api.olie.ai/api/management/...` (move card, project-executions, toggle-funnel-checklist). Needs `management:access`. |

Layout and examples: `~/git/.config/environment.d/README.md`.

## Payment test cards

A review that charges a card has no safe number unless these are written down. Use only these numbers. Do not use a real card.

| Number | Result |
| --- | --- |
| `4000000000000010` | Success. Order **Pago**, transaction **Capturada**. |
| `4000000000000028` | Failure. Not authorized. |
| `4000000000000036` | Processing, then success. |
| `4000000000000044` | Processing, then failure. |

When the change needs more than one outcome, run each relevant number. A success-only check does not cover an unauthorized charge or a charge that stays in processing.

## Production verification URL

Production review (`production-review` / 'Revisão de Produção') checks the **gui1** frame. Log in at **https://gui1.olie.ai/auth/login** with the account in `~/git/olie/prompts/production-review.md`. Local hosts (`*.olie.localhost`), `https://esolie.olie.ai`, and other frames are not production evidence.

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
