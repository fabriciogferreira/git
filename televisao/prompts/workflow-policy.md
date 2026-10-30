# Televisão Workflow Policy

Use this file when another Televisão prompt needs a shared workflow decision. It prevents the same policy from diverging across card-development, review, and handoff prompts.

## Tool preference

When more than one tool can do the same job, use this order (do not skip ahead to avoid a prompt):

1. **MCP** — `olie-flow-ai` for card/board/forms; GitHub MCP for PR approve/merge/read when the prompt uses those tools.
2. **`gh`** — GitHub CLI when MCP is the wrong tool or unavailable. **Exception:** pre-QA **creates** PRs with `gh` first (GitHub MCP App form deferral / weak assignee-label support); see `pre-qa.md`.
3. **curl** — last resort for Olie management HTTP. Forum TipTap has no MCP tool: use `~/git/bin/workvm-olie-management-read.sh` (`get-forum` / `get-thread` / `get-thread-data`) instead of inline Bearer curl.

Never paste a Bearer token. Never silently swap tools to hide a failure (except `olie-flow-ai` `needsAuth` → **MCP auth** below).

## Board stages

The OlieFlowAi project funnel is the source of truth for stage display names and IDs. Read the card and its funnel before moving a card:

- Never hard-code a funnel-step ID.
- Match a stage by its live display name, case-insensitively after trimming whitespace.
- If no unique matching live stage exists, report the available stages and stop before moving the card.

Televisão develop lifecycle (logical key → live display name on this board):

1. `not-started` — 'Não Iniciado'
2. `in-progress` — 'Em andamento'
3. `quality-review` — 'QA/CR'
4. `changes-requested` — 'Corrigir'
5. `validation` — 'Validação'
6. `production-review` — 'Revisão de produção'
7. `done` — 'Concluído'

Earlier board stages ('Backlog', 'Planejamento') and terminal 'Cancelado/Duplicado' are outside the develop handoff prompts. Do not take work from them unless the user explicitly asks.

The live label wins if it differs from the examples above. Resolve the numeric step id from MCP / the live funnel at move time — never from memory.

## Resolving funnel steps and funnel statuses (MCP first)

Follow **Tool preference**. Shell `curl` to `api.olie.ai` often triggers an unnecessary permission prompt for a read that MCP already covers.

1. **Card + current step** — `get-project-details-tool` (or search then details). Use the card UUID and the linked `funnel_steps` / funnel pivot.
2. **Board catalog (steps, tags, funnel statuses)** — `index-project-funnels-tool`. Optional `search` (e.g. `Tele.Visão` or `Revisado`) or `id` of a known step/tag/status. From the matching funnel (`Dev - Tele.Visão` for this product):
   - `steps[]` — board columns (`id`, `name`) for moves like 'Corrigir' / 'QA/CR'
   - `funnel_status[]` — status badges (`id`, `name`) such as 'Revisado' (not a step)
3. Match display names case-insensitively after trim. Never hard-code step or status ids.
4. **Do not** call `GET /api/management/get-available-steps` when `index-project-funnels-tool` works. Use management HTTP only under **MCP auth** below (MCP `needsAuth` / 401), or when a write has no working MCP tool.

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

- `OLIE_MANAGEMENT_TOKEN` — Bearer for management HTTP only (`~/.config/environment.d/*.conf`, `chmod 600`). Not the MCP token (`OLIE_FLOW_AI_MCP_TOKEN`).
- `CARD_PROJECT_ID` — UUID from MCP for that card (the `project_ids` array entry).
- `TARGET_STEP_ID` — numeric id of the matched live funnel step (e.g. 'Em andamento'), never a remembered constant.

Verify the card's stage after the call. On non-2xx, missing env, or ambiguous funnel match: stop and report (prompt-health rules).

## Colleague review outcome

For a colleague card in 'QA/CR' (logical `quality-review`), the board move waits until **every** gate that applies has finished:

1. **Colleague review** (`colleague-review.md`) — pass or fail; write fail findings into the card content (OlieFlowAi).
2. **Test gap analysis** (`test-gap-analysis.md`) — when the change set touched `televisao-api` (backend only). Skip when there is no backend. Write missing use cases into the card content when that run reports them.
3. **Mutation testing** (`mutation-testing.md`) — only when the change set touched `televisao-api`. Skip when there is no backend. Write mutation-driven fixes into the card content when that run reports them.

Order when backend applies: colleague-review → test-gap-analysis → mutation-testing.

**Do not move to 'Corrigir' after only the colleague paste** when gap analysis or mutation still applies. Leave the card in 'QA/CR', recommend `test-gap-analysis.md` then `mutation-testing.md` **in the Cursor chat only** (never on the card — **Card content vs chat**), and finish that stack first (or the user explicitly skips it).

**Move to 'Corrigir'** only after all applicable gates finished **and** at least one failed (colleague fail and/or gap analysis reported missing cases and/or mutation reported fixes for the author).

**Pass path** (approve PRs via GitHub MCP `pull_request_review_write` event `APPROVE`, merge when all approved, funnel status 'Revisado'): only when the colleague review passed **and** gap analysis was skipped or clean **and** mutation either was skipped (no backend) or finished without fixes to send back. Resolve 'Revisado' with `index-project-funnels-tool` → that board's `funnel_status[]` by display name, then `edit-project-tool` with `funnel_status` `{ project_funnel_id, funnel_status_id }`. Never hard-code the status id. If that funnel has no 'Revisado' status, use the move procedure above for the closest live step and report the available statuses.

## Project execution

Do not start or end a project execution. Do not POST `project-executions` and do not call an MCP tool that starts one. The Opbed Job page (`/job`) owns that request. Continue the card work without waiting for an execution to start.

## Reading the project forum

The card from MCP is not the whole spec. Before deciding what to implement, correct, or review, also read every thread on that project and the text of the **latest version** of each thread.

`CARD_PROJECT_ID` is the project UUID from MCP (the same id used in `project_ids`). Never hard-code it. Never paste a Bearer token. Prefer the read-only helper (loads `environment.d`, no write endpoints) so Auto-review is less likely to prompt:

```bash
GIT_ROOT="${GIT_ROOT:-$HOME/git}"
"$GIT_ROOT/bin/workvm-olie-management-read.sh" get-forum "${CARD_PROJECT_ID}"
"$GIT_ROOT/bin/workvm-olie-management-read.sh" get-thread "${FORUM_ID}" "${THREAD_ID}"
"$GIT_ROOT/bin/workvm-olie-management-read.sh" get-thread-data "${FORUM_ID}" "${THREAD_ID}" "${VERSION_ID}"
```

Do not copy browser headers (sentry, sec-ch-ua, cookies, socket id).

1. Load the forum with `get-forum` (helper above).
2. Take `forum.id` as `FORUM_ID`. Walk `forum.threads` and every nested `children` array. Collect each thread's `id` and `name`, including the default thread. Do not stop at `default_thread_id`.
3. For each thread, load its versions with `get-thread`.
4. From `thread.versions`, choose the version with the latest `created_at`. That id is `VERSION_ID`. If `versions` is empty, note the thread name and continue with the others.
5. Load that version with `get-thread-data`. The body is a TipTap document. Read its text. That text is part of what the card asks for. Walk every node, including nested `content`. A node with `type` `image` and a non-empty `attrs.src` is an image: follow `televisao-project-image-analysis` (thread images). `imageUpload` without `src` is an empty editor node; skip it. Do not store the query string of `src`; it is a signed URL and expires.

On non-2xx or missing env: stop and report (prompt-health rules). Do not implement from the card title or the MCP card alone when the forum call failed.

## Card branch name

Televisão does not store the git branch in the card. Build it. Use the same name in every repository the card changes.

`{type}/{code}-{english-slug}`

- `type` is `feature` or `bug`. Read `project.tags[].name`. A tag named Melhoria (any case) means `feature`. A tag named Bug means `bug`. If both are present, stop and report the tags. If neither is present, infer `feature` or `bug` from the card name, description, and threads, and say why.
- `code` is the card code in lowercase (`TV-24` → `tv-24`).
- `english-slug` is the card `name` translated to English, then lowercased. Separate words with `-`. Keep only letters and numbers. Drop punctuation, accents, and extra dots (`L.ogin!!!!!!` → `login`).

Example: type `feature`, code `TV-24`, name `adicionar Botão de login na tela de L.ogin!!!!!!` → `feature/tv-24-add-a-login-button-to-the-login-screen`.

Tags come with the project. MCP `get-project-details-tool` includes `tags`. If they are missing, call that tool again (or `index-projects-tool` then details). Prefer MCP over management HTTP. Never hard-code the project UUID. Never paste a Bearer token.

## Running Playwright

E2E lives in the meta-repo, not in the company clones. `televisao-front` uses `~/git/televisao/televisao-front-e2e` (`http://localhost:3000`). `televisao-meet-front` uses `~/git/televisao/televisao-meet-front-e2e` (`http://localhost:3001`). The API stack must already be up (`~/git/televisao/televisao-api`, `docker compose up -d`). Do not run Playwright inside a company front image. Specs stay in those directories; they do not ship on the company branch.

```bash
cd ~/git/televisao/televisao-front-e2e
./run.sh
./run.sh tests/auth.smoke.spec.ts
```

```bash
cd ~/git/televisao/televisao-meet-front-e2e
./run.sh
```

`./run.sh` execs into `televisao-front-e2e` or `televisao-meet-front-e2e`. If that container is down, `docker compose up -d` in the same directory. If the command fails, stop and report (prompt-health rules).

## Code review form

The card's code-review form holds **Revisor(es)**, **Pull Request (front)**, and **Pull Request (back)**. Read and write it with MCP `olie-flow-ai`. Do not call `dynamic-forms/get-form-answers` or `system/bulk-update/answer_pool`. Never hard-code form ids, funnel ids, or field ids. Never paste a Bearer token.

1. `get-model-dynamic-forms-tool` with `model` `project` and `model_id` the project UUID (not the card code).
2. Copy, unchanged, the funnel-form `target` whose fields include those three labels.
3. `get-form-answers-tool` with that `target`.

**Revisor(es).** `answer` is a JSON string of an array of `{id, name}`. Those items are the PR reviewers. Do not use every collaborator, and do not drop the assignee unless that person is absent from this list. Parse the string. `gh --reviewer` needs a GitHub login that is a collaborator on that repository. Add a person only when their `name` matches exactly one collaborator login. When a name matches none, or more than one, do not add that person and do not stop the pull request. If `answer` is null, the array is empty, or nobody matches, open the pull request with no reviewers. Report each skipped name in the final report.

**Pull request links.** After each PR exists and `gh pr view` confirms it, write the URL with `set-form-answers-tool` on the same `target`. Send only the fields that change. **Pull Request (front)** gets the `televisao-front` PR URL. **Pull Request (back)** gets the `televisao-api` PR URL. A changed `televisao-meet-front` or `televisao-meet-core` PR goes only into a field whose label names that repository. If no field matches, leave the URL in the report and do not invent a field. Use each field's `id` from `get-form-answers-tool`. The value is an array of one URL, `["https://..."]`, not a bare URL. If that repository has no PR, do not send that field. Then `get-form-answers-tool` again and confirm each written URL is stored.

## Pull request body

The body of each pull request is `.github/pull_request_template.md` in that repository, with every section filled. Paths: `~/git/televisao/televisao-api/.github/pull_request_template.md`, `~/git/televisao/televisao-front/.github/pull_request_template.md`, `~/git/televisao/televisao-meet-front/.github/pull_request_template.md`, `~/git/televisao/televisao-meet-core/.github/pull_request_template.md`. Keep the headings and the checklist items. Replace the HTML comments that ask for content. Do not replace the template with a short summary. If a repository has no template file, stop and report; do not invent the body.

- **Link do card na Olie:** `https://esolie.olie.ai/projects/{CARD_PROJECT_ID}/details/overview`, with the project UUID.
- **PR(s) relacionados:** the other repositories' pull request URLs when this card changes more than one. After every required PR exists, `gh pr edit` each body so that line has the real URLs. When this card changes only one repository, mark **Não se aplica**.
- **Descrição da solução técnica:** what changed in this repository, in Brazilian Portuguese.
- **Pontos em aberto:** the open points, or **Não se aplica** when there are none.
- Check a checklist box only when that item was done for this change. Leave it unchecked when it does not apply.

The title stays English. `gh pr view` must still show the template headings, the card link, and the related pull request URL when one exists.

## Card content vs chat (private prompts)

Files under `~/git/televisao/prompts/` are private WorkVM prompts. Other people on the Olie board cannot open them.

When writing to card content through OlieFlowAi (`save-media-tool`, description, forum, or any project note):

- Write only findings, acceptance gaps, and fix instructions the author can act on without this meta-repo.
- Do **not** name prompt files or paths (`colleague-review.md`, `test-gap-analysis.md`, `mutation-testing.md`, `correction.md`, `~/git/.../prompts/...`, “next paste”, `next prompt`).
- Do **not** tell the author which local prompt to run next.

Recommend the next prompt **only in the Cursor chat** report.

## Language

- UI copy, user-facing product content, and card notes are Brazilian Portuguese.
- Commit messages and pull request titles are English.
- Pull request bodies follow **Pull request body** above.

## Formatting

- During implementation, do not run Pint unless the user explicitly asks for it or the task is the pre-QA workflow.
- During pre-QA, run Pint for affected `televisao-api` PHP changes (`docker exec televisao-backend`). If Pint changes files, isolate those formatting-only changes in a dedicated commit; do not create an empty formatting commit.

## MCP auth

Cursor desktop can show `olie-flow-ai` as authenticated, and the MCP request status can say the same, while this agent still receives `needsAuth`. `https://api.olie.ai` publishes OAuth discovery, so Cursor ignores the `Authorization` header in `mcp.json`. Interactive `mcp_auth` does not run in this agent.

Do not call `mcp_auth`. Do not ask the user to sign in again. Do not stop the card for that status.

On a WorkVM with `MCP=olie`, login rewrites the server URL to `http://127.0.0.1:47331/mcp/management`. That proxy returns 404 for OAuth discovery and forwards to `https://api.olie.ai/mcp/management` with `OLIE_FLOW_AI_MCP_TOKEN`. Use the MCP tools against that server.

If the tools are still `needsAuth`, or the call returns 401, fall back per **Tool preference** step 3 (curl). Load `OLIE_MANAGEMENT_TOKEN` from `~/.config/environment.d/*.conf` without printing it. Search projects (`POST .../projects/search`, `name_code` contains the card code) and `GET .../projects/${CARD_PROJECT_ID}`. For the step/status catalog, `GET .../get-available-steps` only when MCP is down — prefer restoring MCP and `index-project-funnels-tool` for routine reads. Match by display name. Never hard-code a step or status id. Never paste a Bearer token.

Forum thread bodies: **Reading the project forum** (helper, not inline curl).

## Chat commands (develop handoff)

Exact phrases from the user in this chat (match case-insensitively after trim). Not the same as controlled-mode checklist `next` inside `implementation.md` / `correction.md`.

| Command | Meaning |
| --- | --- |
| `next prompt` | Open and **run** the next prompt this chat already recommended (path under `~/git/televisao/prompts/`). Do not wait for the user to paste that file. If none was recommended yet, say so and stop. |
| `try again` | Resume or re-run the **current** prompt after a stop or manual fix. Continue from the blocked step when safe; otherwise restart that prompt’s procedure. Do not jump to another prompt. |
| `to correct` | Fix every item listed under **Needs code fixes** from the latest `~/git/televisao/prompts/implementation-validation.md` pass in this chat. Implement those fixes only; then recommend re-running implementation-validation (`try again` on that pass, or `next prompt` if validation was already named next). Not board `correction.md` / 'Corrigir' unless the card is already in `changes-requested`. |

When a prompt finishes and names a next paste, remember that path so `next prompt` can load it without a new paste.

## Tooling failures and stalls (prompt health)

If a request, MCP call, shell command, Docker/compose wait, git/gh, or other step **this prompt assumes will work** fails or takes unusually long, **stop**. Do not silently work around it or swap tools to hide the break. `olie-flow-ai` `needsAuth` is the **MCP auth** case above, not this stop.

Report:

1. What you were doing
2. The objective error (status, short message) or that it hung past a reasonable wait
3. The most likely cause
4. That this likely means **this prompt (or its assumptions) needs to be updated**

Then wait for the user. Expected failures of the current task (e.g. testing an error path) can be reported and continued when that still makes sense.
