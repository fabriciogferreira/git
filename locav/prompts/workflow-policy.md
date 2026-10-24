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

## Project execution

Do not start or end a project execution. Do not POST `project-executions` and do not call an MCP tool that starts one. The Opbed Job page (`/job`) owns that request. Continue the card work without waiting for an execution to start.

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
5. Load that version. The body is a TipTap document. Read its text. That text is part of what the card asks for. Walk every node, including nested `content`. A node with `type` `image` and a non-empty `attrs.src` is an image: follow `locav-project-image-analysis` (thread images). `imageUpload` without `src` is an empty editor node; skip it. Do not store the query string of `src`; it is a signed URL and expires.

```bash
curl -sS --url "https://api.olie.ai/api/management/get-thread-data/${FORUM_ID}/${THREAD_ID}?version=${VERSION_ID}" \
  -H 'accept: application/json' \
  -H "authorization: Bearer ${OLIE_MANAGEMENT_TOKEN}"
```

On non-2xx or missing env: stop and report (prompt-health rules). Do not implement from the card title or the MCP card alone when the forum call failed.

## Card branch name

Locav does not store the git branch in the card. Build it. Use the same name in every repository the card changes.

`{type}/{code}-{english-slug}`

- `type` is `feature` or `bug`. Read `project.tags[].name`. A tag named Melhoria (any case) means `feature`. A tag named Bug means `bug`. If both are present, stop and report the tags. If neither is present, infer `feature` or `bug` from the card name, description, and threads, and say why.
- `code` is the card code in lowercase (`LCV-24` → `lcv-24`).
- `english-slug` is the card `name` translated to English, then lowercased. Separate words with `-`. Keep only letters and numbers. Drop punctuation, accents, and extra dots (`L.ogin!!!!!!` → `login`).

Example: type `feature`, code `LCV-24`, name `adicionar Botão de login na tela de L.ogin!!!!!!` → `feature/lcv-24-add-a-login-button-to-the-login-screen`.

Tags come with the project. MCP project details include `tags`. If they are missing, load the project:

```bash
curl -sS --url "https://api.olie.ai/api/management/projects/${CARD_PROJECT_ID}" \
  -H 'accept: application/json' \
  -H "authorization: Bearer ${OLIE_MANAGEMENT_TOKEN}"
```

`CARD_PROJECT_ID` is the project UUID. Never hard-code it. Never paste a Bearer token. Do not copy browser headers.

## Running Cypress

Do not run Cypress inside `locav-frontend`. That image is Alpine (musl). The Cypress binary is glibc. `apk add xvfb` installs, then the smoke test still exits with `premature close` and `Error relocating ... __memcpy_chk`. More Alpine packages do not fix that.

The dev server stays in `locav-frontend` (`http://localhost:3000`). Run Cypress on the host, from `~/git/locav/locav-front`, with the Node binary. The graphical session already has `DISPLAY`. Do not add `package-lock.json`.

```bash
cd ~/git/locav/locav-front
node node_modules/cypress/bin/cypress install
node node_modules/cypress/bin/cypress run
```

`cypress install` extracts the binary into `~/.cache/Cypress` and needs `unzip` on `PATH`. If `unzip` is missing, install it and run `cypress install` again. This VM is Arch: `sudo pacman -S --needed --noconfirm unzip`. A missing `unzip` leaves the cache without `Cypress/Cypress` and the next run reports `No version of Cypress is installed`.

If `node_modules/cypress` is missing, `docker exec locav-frontend bun install` first, then run the host commands again. If the host command fails for another reason, stop and report (prompt-health rules).

## Code review form

The card's code-review form holds **Revisor(es)**, **Pull Request (front)**, and **Pull Request (back)**. Read and write it with MCP `olie-flow-ai`. Do not call `dynamic-forms/get-form-answers` or `system/bulk-update/answer_pool`. Never hard-code form ids, funnel ids, or field ids. Never paste a Bearer token.

1. `get-model-dynamic-forms-tool` with `model` `project` and `model_id` the project UUID (not the card code).
2. Copy, unchanged, the funnel-form `target` whose fields include those three labels.
3. `get-form-answers-tool` with that `target`.

**Revisor(es).** `answer` is a JSON string of an array of `{id, name}`. Those items are the PR reviewers. Do not use every collaborator, and do not drop the assignee unless that person is absent from this list. Parse the string. `gh --reviewer` needs a GitHub login that is a collaborator on that repository. Add a person only when their `name` matches exactly one collaborator login. When a name matches none, or more than one, do not add that person and do not stop the pull request. If `answer` is null, the array is empty, or nobody matches, open the pull request with no reviewers. Report each skipped name in the final report.

**Pull request links.** After each PR exists and `gh pr view` confirms it, write the URL with `set-form-answers-tool` on the same `target`. Send only the fields that change. **Pull Request (front)** gets the `locav-front` PR URL. **Pull Request (back)** gets the `LocavApi` PR URL. Use each field's `id` from `get-form-answers-tool`. The value is an array of one URL, `["https://..."]`, not a bare URL. If that repository has no PR, do not send that field. Then `get-form-answers-tool` again and confirm each written URL is stored.

## Pull request body

The body of each pull request is `.github/pull_request_template.md` in that repository, with every section filled. `LocavApi` uses `~/git/locav/LocavApi/.github/pull_request_template.md`. `locav-front` uses `~/git/locav/locav-front/.github/pull_request_template.md`. Keep the headings and the checklist items. Replace the HTML comments that ask for content. Do not replace the template with a short summary.

- **Link do card na Olie:** `https://esolie.olie.ai/projects/{CARD_PROJECT_ID}/details/overview`, with the project UUID.
- **PR(s) relacionados:** the other repository's pull request URL when this card changes both. After every required PR exists, `gh pr edit` each body so that line has the real URL. When this card changes only one repository, mark **Não se aplica**.
- **Descrição da solução técnica:** what changed in this repository, in Brazilian Portuguese.
- **Pontos em aberto:** the open points, or **Não se aplica** when there are none.
- Check a checklist box only when that item was done for this change. Leave it unchecked when it does not apply.

The title stays English. `gh pr view` must still show the template headings, the card link, and the related pull request URL when one exists.

## Language

- UI copy, user-facing product content, and card notes are Brazilian Portuguese.
- Commit messages and pull request titles are English.
- Pull request bodies follow **Pull request body** above.

## Formatting

- During implementation, do not run Pint unless the user explicitly asks for it or the task is the pre-QA workflow.
- During pre-QA, run Pint for affected `LocavApi` PHP changes (`docker exec locav-backend`). If Pint changes files, isolate those formatting-only changes in a dedicated commit; do not create an empty formatting commit.

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

Load `GET /api/management/projects/${CARD_PROJECT_ID}`. Live step names come from that payload when it includes them. Otherwise `GET /api/management/get-available-steps` (`funnels[].steps[].id` and `name`). Match the stage by display name. Never hard-code a step id. Never paste a Bearer token.

## Tooling failures and stalls (prompt health)

If a request, MCP call, shell command, Docker/compose wait, git/gh, or other step **this prompt assumes will work** fails or takes unusually long, **stop**. Do not silently work around it or swap tools to hide the break. `olie-flow-ai` `needsAuth` is the **MCP auth** case above, not this stop.

Report:

1. What you were doing
2. The objective error (status, short message) or that it hung past a reasonable wait
3. The most likely cause
4. That this likely means **this prompt (or its assumptions) needs to be updated**

Then wait for the user. Expected failures of the current task (e.g. testing an error path) can be reported and continued when that still makes sense.
