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

## Resolving funnel steps and funnel statuses (MCP first)

Prefer MCP `olie-flow-ai` over management HTTP for **read** discovery. Shell `curl` to `api.olie.ai` often triggers an unnecessary permission prompt for a read that MCP already covers.

1. **Card + current step** — `get-project-details-tool` (or search then details).
2. **Board catalog (steps, tags, funnel statuses)** — `index-project-funnels-tool` (optional `search` / `id`). Use `steps[]` for columns and `funnel_status[]` when a badge id is required.
3. Match display names case-insensitively after trim. Never hard-code step or status ids.
4. **Do not** call `GET /api/management/get-available-steps` when `index-project-funnels-tool` works. Use management HTTP only under **MCP auth** (MCP down) or when a write has no working MCP tool.

## Moving a card on the board

Resolve **card id** and **funnel steps** through MCP `olie-flow-ai` (search by card code). Never hard-code `step_id`. Never paste a Bearer token into a prompt, chat, or repo file.

1. Load the card via MCP. Take its project/card id (UUID) and the live funnel steps for that board (`get-project-details-tool` and/or `index-project-funnels-tool` — see above).
2. Match the target logical stage to a live step by display name (`workflow-policy` board stages above).
3. Prefer an MCP tool that moves the card when one exists and works (`move-project-to-funnel-step-tool`).
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

## Colleague review outcome

For a colleague card in 'QA/CR', the colleague review closes in two paths:

1. Failed / findings to fix — write the findings into the card content (OlieFlowAi); the card moves to the live funnel step 'Corrigir'.
2. Passed — mark the card's pull requests as approved through GitHub MCP (`pull_request_review_write`, event `APPROVE`); if all the card's PRs were approved, move the card to the live funnel step 'Validação'.

After the colleague review, if the change set touched the backend (`api-main`), recommend the personal `mutation-testing.md` before the tech lead pass.

## Project execution

Do not start or end a project execution. Do not POST `project-executions` and do not call an MCP tool that starts one. The Opbed Job page (`/job`) owns that request. Continue the card work without waiting for an execution to start.

## Several cards at once

The board shows one project execution. VMs can run several cards at the same time.

The Opbed Job page (`/job`) reads `board_executions` and sends the project-execution requests, one card at a time, for each card's 'Tempo que eu acho'. This chat does not send those requests, does not end an execution, and does not ask for the codes.

The user works every listed card in parallel on the VMs.

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

## MCP auth

Cursor desktop can show `olie-flow-ai` as authenticated, and the MCP request status can say the same, while this agent still receives `needsAuth`. `https://api.olie.ai` publishes OAuth discovery, so Cursor ignores the `Authorization` header in `mcp.json`. Interactive `mcp_auth` does not run in this agent.

Do not call `mcp_auth`. Do not ask the user to sign in again. Do not stop the card for that status.

On a WorkVM with `MCP=olie`, login rewrites the server URL to `http://127.0.0.1:47331/mcp/management`. That proxy returns 404 for OAuth discovery and forwards to `https://api.olie.ai/mcp/management` with `OLIE_FLOW_AI_MCP_TOKEN`. Use the MCP tools against that server.

If the tools are still `needsAuth`, or the call returns 401, load the card over management HTTP. If `OLIE_MANAGEMENT_TOKEN` is empty, read `~/.config/environment.d/*.conf` into the shell without printing values, then retry:

```bash
set -a
for conf in "${HOME}/.config/environment.d/"*.conf; do
  [ -f "$conf" ] || continue
  . "$conf"
done
set +a
```

Search by card code (`name_code` contains the code). Take `projects[].id` for the matching code:

```bash
curl -sS --url 'https://api.olie.ai/api/management/projects/search?perPage=20' \
  -H 'accept: application/json' \
  -H "authorization: Bearer ${OLIE_MANAGEMENT_TOKEN}" \
  -H 'content-type: application/json' \
  --data-raw "{\"filters\":[{\"field\":\"name_code\",\"operator\":\"contains\",\"value\":\"${CARD_CODE}\",\"logical_operator\":\"and\"}]}"
```

Load `GET /api/management/projects/${CARD_PROJECT_ID}`. Live step names come from that payload when it includes them. For the full step/status catalog when MCP is down, `GET /api/management/get-available-steps` (`funnels[].steps[]` and `funnels[].funnel_status[]`). Prefer restoring MCP and using `index-project-funnels-tool` (steps + `funnel_status`) instead of this HTTP path for routine reads. Match by display name. Never hard-code a step or status id. Never paste a Bearer token.

## Tokens

Two env vars in `~/.config/environment.d/*.conf` (`chmod 600`). Never the same value by assumption; never paste into chat or repo files.

| Variable | Use |
| --- | --- |
| `OLIE_FLOW_AI_MCP_TOKEN` | Cursor MCP `olie-flow-ai` only (`mcps/olie.json` → `${env:OLIE_FLOW_AI_MCP_TOKEN}`) |
| `OLIE_MANAGEMENT_TOKEN` | HTTP `https://api.olie.ai/api/management/...` (move card, toggle-funnel-checklist). Needs `management:access`. |

Layout and examples: `~/git/.config/environment.d/README.md`.

## Temporary E2E CAPTCHA

Playwright stubs `grecaptcha` with a fake token. `api-main` skips `RecaptchaValidate` only when `APP_ENV=testing`. This VM is `local`, so the real `RECAPTCHA_SECRET` answers `Token inválido` and the spec never reaches the password step.

Do not stub the management API to get past that. Do not change PHP. The same temporary window is Google's public test secret in the local `.env` only (`siteverify` then accepts any token). Full steps: `implementation.md`, `correction.md`, and `colleague-review.md`, section "Temporary E2E CAPTCHA".

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

## Olie docs repository — never touch

The clone `~/git/olie/docs` (`olie-ai/docs`, docs.olie.ai / public OpenAPI) is **out of scope** for every agent workflow (implementation, correction, pre-QA, colleague review, production review).

Do not edit, rebase, merge, commit, push, or open/update PRs in that repository. Do not put it on a card’s repository list or correction plan. If a card or review mentions public docs, report that and continue only in product repos (`api-main`, `olie-fronts`, `olie-e2e`, …). Meta-repo docs under `~/git` (`olie/prompts/`, `HISTORICO.md`, overlay) remain allowed.

If that clone is already mid-rebase or dirty from a mistaken agent pass: abort/restore safely and stop; do not finish the conflict.

## Language

- UI copy, user-facing product content, and card notes are Brazilian Portuguese.
- Commit messages, pull request titles, and pull request bodies are English.
- Do not edit `en.json`. English translations are resolved later. New or changed UI keys go in `pt-br.json` only.

## Formatting

- During implementation, do not run Pint unless the user explicitly asks for it or the task is the pre-QA workflow.
- During pre-QA, run Pint for affected `api-main` PHP changes. If Pint changes files, isolate those formatting-only changes in a dedicated commit; do not create an empty formatting commit.

## Chat commands (develop handoff)

Exact phrases from the user in this chat (match case-insensitively after trim). Not the same as controlled-mode checklist `next` inside `implementation.md` / `correction.md`.

| Command | Meaning |
| --- | --- |
| `next prompt` | Open and **run** the next prompt this chat already recommended (path under `~/git/olie/prompts/`). Do not wait for the user to paste that file. If none was recommended yet, say so and stop. **Exception — mutation stack:** if `~/git/olie/prompts/mutation-testing.md` is in progress and any changed `api-main` `*Test.php` is still missing a `100%` / `equivalent` ledger row, **refuse** `next prompt` (do not open `pre-qa.md`). List what remains and tell the user to send `next mutation`. |
| `next mutation` | Only during the personal mutation stack (`~/git/olie/prompts/mutation-testing.md`): open that prompt and process the **next** changed test file not yet done in `~/git/olie/prompts/mutation-ledger.md` (one file per turn). Same as re-pasting mutation-testing. Do not jump to `pre-qa.md`. If the stack is already complete, say so and point at `next prompt` → `pre-qa.md`. |
| `try again` | Resume or re-run the **current** prompt after a stop or manual fix. Continue from the blocked step when safe; otherwise restart that prompt’s procedure. Do not jump to another prompt. |
| `to correct` | Fix every item listed under **Needs code fixes** from the latest `~/git/olie/prompts/implementation-validation.md` pass in this chat. Implement those fixes only; then recommend re-running implementation-validation (`try again` on that pass, or `next prompt` if validation was already named next). Not board `correction.md` / 'corrigir' unless the card is already in `changes-requested`. |

When a prompt finishes and names a next paste, remember that path so `next prompt` can load it without a new paste. While mutation-testing still has remaining files, the remembered “continue” command for the stack is `next mutation`, not `next prompt`.

## Tooling failures and stalls (prompt health)

If a request, **MCP call** (any configured server), shell command, Docker/compose wait, git/gh, or other step **this prompt assumes will work** fails or takes unusually long, **stop the prompt**. Do not silently work around it, swap tools to hide the break, or keep going. **Ask the user to fix the broken tool** (MCP auth/token, proxy, Docker, env, etc.) and wait before continuing. `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is the **MCP auth** case above, not this stop — do not ask the user to sign in again for that case only.

Report:

1. What you were doing
2. The objective error (status, short message) or that it hung past a reasonable wait
3. The most likely cause
4. That the user should fix the tooling, **or** that this prompt (or its assumptions) may need updating if the failure looks like a bad prompt instruction

Then wait for the user. Expected failures of the current task (e.g. testing an error path) can be reported and continued when that still makes sense.
