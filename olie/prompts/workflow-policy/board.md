# Olie Workflow Policy — Board & funnel

Load this module for stage names, MCP moves the agent still owns, and what **not** to do by hand. Mechanical handoff (PR checklist + move to 'QA/CR') is manager **Pre-QA** (`bin/workvm-host-card-pre-qa`) — do not paste curl recipes here.

Index: `~/git/olie/prompts/workflow-policy.md`

## Board stages

The OlieFlowAi project funnel is the source of truth for stage display names and IDs.

- Never hard-code a funnel-step ID.
- Match a stage by its live display name, case-insensitively after trim.
- If no unique match, report available stages and stop before moving.

Logical lifecycle (live label wins):

1. `not-started` — 'Não iniciado'
2. `in-progress` — 'Em progresso'
3. `quality-review` — 'QA/CR'
4. `changes-requested` — 'corrigir' / 'corrigir ou melhorar'
5. `validation` — 'validação'
6. `production-review` — 'Revisão de Produção'
7. `done` — 'concluído'

## Resolving funnel steps (MCP)

Follow **Tool preference** in `workflow-policy/tools.md`. Prefer MCP reads over shell curl.

1. Card + current step — `get-project-details-tool` (or Card Spec dump when the prompt says so).
2. Board catalog — `index-project-funnels-tool` (`steps[]`, `funnel_status[]`). Empty filter ≠ MCP down; broaden search before HTTP.
3. Match display names; never hard-code ids.
4. While MCP works: do **not** call `GET .../get-available-steps` or curl the catalog.

## Moving a card (agent-owned moves)

Use when the **prompt** owns the move (e.g. implementation → 'Em progresso', colleague Pass → 'Validação', production → 'concluído'). For develop handoff into **'QA/CR'**: user runs manager **Pre-QA** — agent does not move / toggle checklist / create PRs (see `pre-qa.md`).

1. Resolve UUID + live step id via MCP (display name). Never hard-code `step_id`. Never paste a Bearer token.
2. **Name the destination** in any Auto-review / confirm UI (e.g. “Move DOP-1272 from QA/CR to Validação”), not only a numeric id.
3. **Incoming restrictions:** if the destination requires forms, answer them first (`get-model-dynamic-forms-tool` → `set-form-answers-tool`). A move that returns `incoming_restrictions` is unanswered fields — fill, then retry once.
4. Prefer `move-project-to-funnel-step-tool`. Verify the stage after the call.
5. Do **not** invent management curl in chat. If MCP cannot write and the prompt still requires a move, stop (prompt-health) — do not paste ad-hoc HTTP. Manager Pre-QA / durable scripts own HTTP fallbacks.

## Checklist items

Do **not** toggle funnel checklists (e.g. **Pull Request criado**) from the agent paste. Manager **Pre-QA** does that. If a checklist is wrong after Apply, tell the user to re-run **Pre-QA** (or fix in the board UI) — do not curl `toggle-funnel-checklist`.

## Project execution

Do not start or end a project execution. Do not POST `project-executions` / MCP that starts one. The Opbed Job page (`/job`) owns that. Continue card work without waiting for an execution.
