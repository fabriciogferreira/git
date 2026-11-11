# Locav Workflow Policy

Use this file when another Locav prompt needs a shared workflow decision. It prevents the same policy from diverging across card-development, review, and handoff prompts.

## Tool preference

When more than one tool can do the same job, use this order (do not skip ahead to avoid a prompt):

1. **MCP** — `olie-flow-ai` for card/board/forms; GitHub MCP for PR approve/merge/read when the prompt uses those tools.
2. **`gh`** — GitHub CLI when MCP is the wrong tool or unavailable. **Exception:** pre-QA **creates** PRs with `gh` first (GitHub MCP App form deferral / weak assignee-label support); see `pre-qa.md`.
3. **curl** — last resort for Olie management HTTP when MCP itself is `needsAuth` / 401. Never prefer HTTP over a working MCP tool. Project Caderno/forum: MCP `get-notebook-tool` + `read-notebook-page-tool` first; `~/git/bin/workvm-olie-management-read.sh` only under **MCP auth**.

Never paste a Bearer token. Never silently swap tools to hide a failure (except `olie-flow-ai` `needsAuth` → **MCP auth** below).

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

## Resolving funnel steps and funnel statuses (MCP first)

Follow **Tool preference**. Shell `curl` to `api.olie.ai` often triggers an unnecessary permission prompt for a read that MCP already covers.

1. **Card + current step** — `get-project-details-tool` (or search then details).
2. **Board catalog (steps, tags, funnel statuses)** — `index-project-funnels-tool` only (optional `search` / `id`). Use `steps[]` for columns and `funnel_status[]` for badges such as 'Revisado'.
3. Match display names case-insensitively after trim. Never hard-code step or status ids.
4. **Hard ban while MCP works:** do **not** call `GET /api/management/get-available-steps`, and do **not** open a shell/`curl` “fallback” for the step/status catalog, when `index-project-funnels-tool` has already returned successfully in this chat (including an empty `funnels: []` for a narrow `search`/`id`). Empty filter result ≠ MCP down. Retry unfiltered or with a broader `search`, then match by display name. Management HTTP for this catalog only under **MCP auth** (`needsAuth` / 401 on the tool itself), or when a write has no working MCP tool.

## Moving a card on the board

Resolve **card id** and **funnel steps** through MCP `olie-flow-ai` (search by card code). Never hard-code `step_id`. Never paste a Bearer token into a prompt, chat, or repo file.

**Name the destination step when asking to approve a move.** Auto-review (and any other confirmation UI) often shows only a generic “move funnel step” prompt. Whenever you call `move-project-to-funnel-step-tool`, `project-bulk-step-move`, or an equivalent write that changes the board column — including the description field the approval card displays — state the **live display name** of the destination step (and the current step when known). Example: “Move LOC-123 from QA/CR to Validação”. Do **not** ask for confirmation with only a numeric `funnel_step_id` / `step_id`. Same rule for Olie, Locav, and Televisão.

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
2. **Test gap analysis** (`test-gap-analysis.md`) — when the change set touched `LocavApi` and/or `locav-front`. Skip when neither changed. On this colleague stack, write missing use cases into the card content when that run reports them. (Own-card develop handoff lists gaps in chat only — see `test-gap-analysis.md`.)
3. **Mutation testing** (`mutation-testing.md`) — only when the change set touched `LocavApi`. Skip when there is no backend. Write mutation-driven fixes into the card content when that run reports them.

Order when the stack applies: colleague-review → test-gap-analysis → mutation-testing (mutation only if `LocavApi`).

**Do not move to 'Corrigir' or set 'Revisado' after only the colleague paste** when gap analysis or mutation still applies. Leave the card in 'QA/CR', recommend `test-gap-analysis.md` then `mutation-testing.md` when backend applies **in the Cursor chat only** (never on the card — **Card content vs chat**), and finish that stack first (or the user explicitly skips it). Do **not** approve or merge PRs until the combined outcome below.

**Move to 'Corrigir'** only after all applicable gates finished **and** at least one failed (colleague fail and/or gap analysis reported missing cases and/or mutation reported fixes for the author).

**Pass path** (approve PRs via GitHub MCP `pull_request_review_write` event `APPROVE`, merge when all approved, funnel status 'Revisado'): only when the colleague review passed **and** gap analysis was skipped or clean **and** mutation either was skipped (no `LocavApi`) or finished without fixes to send back. Resolve 'Revisado' with `index-project-funnels-tool` → that board's `funnel_status[]` by display name, then `edit-project-tool` with `funnel_status`; never hard-code the id. Do not use HTTP `get-available-steps` when MCP works. If that funnel has no 'Revisado' status, use the move procedure above for the closest live step and report the available statuses.

## Project execution

Do not start or end a project execution. Do not POST `project-executions` and do not call an MCP tool that starts one. The Opbed Job page (`/job`) owns that request. Continue the card work without waiting for an execution to start.

## Reading the project notebook (Caderno)

The card from MCP is not the whole spec. Before deciding what to implement, correct, or review, also read **every page** on that project's notebook and the Markdown of each page. Older prompts called this the project **forum** / **threads** — same object, new MCP name.

| Older (management HTTP / UI habit) | MCP `olie-flow-ai` |
| --- | --- |
| forum | notebook (Caderno) |
| thread / sub-thread | page / nested page (`pages[].children`) |
| `get-forum` (list) | `get-notebook-tool` (full page tree) |
| `get-thread-data` (latest TipTap) | `read-notebook-page-tool` |

There is **one notebook per project**. **`get-notebook-tool` is the list-all tool**: it returns `pages` plus nested `children`. There is no separate "list forums" MCP tool — walk that tree. Do not stop at `default_page_id`.

1. Call MCP `get-notebook-tool` with `model_type` `project` and `model_id` the card code or UUID (e.g. `LCV-24` or `CARD_PROJECT_ID` from `get-project-details-tool`).
2. If `notebook` is `null`, the project has no Caderno yet — note that and continue from card media/description only (not a tooling failure).
3. Walk every entry in `pages` and every nested `children` array. Collect each page's `id` and `name`, including the default page.
4. For each page id, call MCP `read-notebook-page-tool` with `page_id`. Read every block's `markdown` (and `type`). That text is part of what the card asks for. Empty `blocks` means an empty page — note the name and continue.
5. A block with `type` `image` (or an image URL in markdown): follow `locav-project-image-analysis` (notebook page images). Do not store signed URL query strings; they expire.

Do **not** use `~/git/bin/workvm-olie-management-read.sh` (`get-forum` / `get-thread` / `get-thread-data`) while MCP notebook tools work. That helper is only **Tool preference** step 3 under **MCP auth** (`needsAuth` / 401 on the notebook tools themselves). Never inline Bearer curl for Caderno.

On MCP error (other than `notebook: null`): stop and report (prompt-health rules). Do not implement from the card title or the MCP card alone when the notebook read failed.

## Card branch name

Locav does not store the git branch in the card. Build it. Use the same name in every repository the card changes.

`{type}/{code}-{english-slug}`

- `type` is `feature` or `bug`. Read `project.tags[].name`. A tag named Melhoria (any case) means `feature`. A tag named Bug means `bug`. If both are present, stop and report the tags. If neither is present, infer `feature` or `bug` from the card name, description, and threads, and say why.
- `code` is the card code in lowercase (`LCV-24` → `lcv-24`).
- `english-slug` is the card `name` translated to English, then lowercased. Separate words with `-`. Keep only letters and numbers. Drop punctuation, accents, and extra dots (`L.ogin!!!!!!` → `login`).

Example: type `feature`, code `LCV-24`, name `adicionar Botão de login na tela de L.ogin!!!!!!` → `feature/lcv-24-add-a-login-button-to-the-login-screen`.

Tags come with the project. MCP `get-project-details-tool` includes `tags`. If they are missing, call that tool again (or `index-projects-tool` then details). Prefer MCP over management HTTP. Never hard-code the project UUID. Never paste a Bearer token.

## Running Cypress

Cypress lives **inside** `locav-front` on the company branch. Locav is the EnterScience exception: agents **may** cite Cypress specs, coverage, and paths in company repos, pull requests, card content, and Caderno. (Olie/Televisão Playwright suites are private meta-repo tooling and must not be cited the same way.)

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

## Prompt templates (`{{ code }}`)

Files under `~/git/*/prompts/` are paste templates. The repo keeps the literal placeholders (`{{ code }}`, and any other `{{ … }}` the file uses). Replacing them with a real card code happens only in the chat paste, never in the versioned file.

When committing or pushing the meta-repo `~/git`:

- Do **not** stage, commit, or push a prompt whose only “edit” is a substituted card code (e.g. a real `LOC-…` instead of `{{ code }}`).
- If a prompt is dirty that way, restore it (`git checkout -- path`) before the commit.
- Intentional prompt wording changes are fine; leave `{{ code }}` (and the other placeholders) intact.

## Card content vs chat (private prompts)

Files under `~/git/locav/prompts/` are private WorkVM prompts. Other people on the Olie board cannot open them.

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

- During implementation, do not run PHP CS Fixer unless the user explicitly asks for it or the task is the pre-QA workflow.
- During pre-QA, run PHP CS Fixer for affected `LocavApi` PHP changes. If PHP CS Fixer changes files, isolate those formatting-only changes in a dedicated commit; do not create an empty formatting commit.

## MCP auth

Cursor desktop can show `olie-flow-ai` as authenticated, and the MCP request status can say the same, while this agent still receives `needsAuth`. `https://api.olie.ai` publishes OAuth discovery, so Cursor ignores the `Authorization` header in `mcp.json`. Interactive `mcp_auth` does not run in this agent.

Do not call `mcp_auth`. Do not ask the user to sign in again. Do not stop the card for that status.

On a WorkVM with `MCP=olie`, login rewrites the server URL to `http://127.0.0.1:47331/mcp/management`. That proxy returns 404 for OAuth discovery and forwards to `https://api.olie.ai/mcp/management` with `OLIE_FLOW_AI_MCP_TOKEN`. Use the MCP tools against that server.

If the tools are still `needsAuth`, or the call returns 401, fall back per **Tool preference** step 3 (curl). Load `OLIE_MANAGEMENT_TOKEN` from `~/.config/environment.d/*.conf` without printing it. Search projects (`POST .../projects/search`, `name_code` contains the card code) and `GET .../projects/${CARD_PROJECT_ID}`. For the step/status catalog, `GET .../get-available-steps` **only** when `index-project-funnels-tool` itself is `needsAuth` / 401 (MCP auth), not when a filtered call returned `[]` or when another MCP read already succeeded. Prefer restoring MCP and calling `index-project-funnels-tool` again (unfiltered if needed). Match by display name. Never hard-code a step or status id. Never paste a Bearer token.

Project notebook (Caderno) bodies: **Reading the project notebook** (MCP `get-notebook-tool` + `read-notebook-page-tool` first).

## Chat commands (develop handoff)

Exact phrases from the user in this chat (match case-insensitively after trim). Not the same as controlled-mode checklist `next` inside `implementation.md` / `correction.md`.

| Command | Meaning |
| --- | --- |
| `next prompt` | Open and **run** the next prompt this chat already recommended (path under `~/git/locav/prompts/`). Do not wait for the user to paste that file. If none was recommended yet, say so and stop. |
| `try again` | Resume or re-run the **current** prompt after a stop or manual fix. Continue from the blocked step when safe; otherwise restart that prompt’s procedure. Do not jump to another prompt. |
| `to correct` | Fix the latest corrective list in this chat: either **Needs code fixes** from `~/git/locav/prompts/implementation-validation.md`, or **Tests to add** from `~/git/locav/prompts/test-gap-analysis.md`. Implement those items only; then recommend `try again` on that same pass (re-run validation or gap analysis). Not board `correction.md` / 'Corrigir' unless the card is already in `changes-requested`. |

When a prompt finishes and names a next paste, remember that path so `next prompt` can load it without a new paste.

## Tooling failures and stalls (prompt health)

If a request, MCP call, shell command, Docker/compose wait, git/gh, or other step **this prompt assumes will work** fails or takes unusually long, **stop**. Do not silently work around it or swap tools to hide the break. `olie-flow-ai` `needsAuth` is the **MCP auth** case above, not this stop.

Report:

1. What you were doing
2. The objective error (status, short message) or that it hung past a reasonable wait
3. The most likely cause
4. That this likely means **this prompt (or its assumptions) needs to be updated**

Then wait for the user. Expected failures of the current task (e.g. testing an error path) can be reported and continued when that still makes sense.
