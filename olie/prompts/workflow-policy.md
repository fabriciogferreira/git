# Olie Workflow Policy

Use this file when another Olie prompt needs a shared workflow decision. It prevents the same policy from diverging across card-development, review, and handoff prompts.

## Tool preference

When more than one tool can do the same job, use this order (do not skip ahead to avoid a prompt):

1. **MCP** — `olie-flow-ai` for card/board/forms; GitHub MCP for PR approve/merge/read when the prompt uses those tools.
2. **`gh`** — GitHub CLI when MCP is the wrong tool or unavailable. **Exception:** pre-QA **creates** PRs with `gh` first (GitHub MCP App form deferral / weak assignee-label support); see `pre-qa.md`.
3. **curl** — last resort for Olie management HTTP (`OLIE_MANAGEMENT_TOKEN`) when MCP itself is `needsAuth` / 401. Never prefer HTTP over a working MCP tool. Project Caderno/forum: MCP `get-notebook-tool` + `read-notebook-page-tool` first; `~/git/bin/workvm-olie-management-read.sh` only under **MCP auth**.

### GitHub reads vs writes (Auto-review)

Cursor Auto-review often prompts on `gh` in the shell (network + session credentials) even for GET-only commands. Prefer **GitHub MCP** for read-only discovery so the user is not asked to approve informational calls:

- **MCP (read):** current user (`get_me`), list/search PRs, PR details, reviewers/assignees already on a PR, labels, checks, commits, file contents, org/collaborator lookups needed to map card assignees → GitHub logins.
- **`gh` (write / pre-QA create):** `gh pr create`, `gh pr edit` (assignee/reviewer/label), `git push` that updates a PR head. An Auto-review OK on those is expected.
- Do **not** use shell `gh pr list` / `gh api user` / `gh auth status` only to discover login, assignees, reviewers, or labels when GitHub MCP can answer. Use `gh auth status` only immediately before a `gh` write if create fails with an auth error (then stop and report).

Never paste a Bearer token. Never silently swap tools to hide a failure (except `olie-flow-ai` `needsAuth` → **MCP auth** below).

## Expensive re-run budget

Do **not** repeat an expensive step when nothing material changed since the last run of that step in this chat (same code/asserts/env/deploy, same card diff).

| Expensive step | Re-run only when |
| --- | --- |
| `pest --mutate` / `pest --coverage` | Test or production blobs under test changed (`sha:` mismatch / missing stamp), or tooling was fixed; mutation also allows ≤1 re-mutate per `--class` after killable asserts (see mutation/coverage prompts). Matching `sha:` in the ledger → skip sandbox across chats. |
| Full Pest suite (`pest-parallel`) | A fix landed after a red suite, or the user sent `try again` after that fix. |
| Gap analysis / implementation-validation | Diff or requirements changed, or `try again` after `add` / `to correct`. |
| Colleague dispatcher gates | A gate was blocked/failed and the user asks to retry **that** gate — do not re-dispatch green gates “to confirm”. |
| Pre-QA checklist / production smoke | Code, PR, or production deploy changed; or a prior check failed and was fixed. |
| Correction verification | Re-check only what this correction changed — not the whole unrelated suite “for safety”. |

`try again` means “run again **after** a real change or unblock”, not “repeat the same measurement on an unchanged tree”.

## Backend change-set (when `develop...HEAD` is empty)

Shared recipe for gap / mutation / coverage / colleague bootstrap on `api-main` (base branch `develop` — `project.md`). Locav/Televisão use the same steps on their API clone and base branch.

1. **Always** include dirty paths: `git status --short`, `git diff --name-only HEAD`, and untracked files.
2. **Primary** branch diff: `git diff --name-only develop...HEAD` (three-dot). In-scope hunks: `git diff -U0 develop...HEAD -- <path>`.
3. If that three-dot list is **empty** but the card still has backend work (feature already merged, worktree tip ≡ `develop`, or `feature/…` tip already contained in `develop`):
   1. Prefer a still-existing feature tip: `git diff --name-only develop...<feature-tip>` / `git log develop..<feature-tip> --grep='<CODE>'`.
   2. Else collect **PR merge commits** for the card (`git log --merges --grep='<CODE>'`, and/or merge SHAs from card PR links). **Skip** sync merges whose subject is “merge develop into the branch” (or equivalent). For each remaining merge `M`, add `git diff --name-only M^1...M^2`.
   3. Else (or to fill gaps): non-merge commits `git log --no-merges --grep='<CODE>'` → `git diff-tree --no-commit-id --name-only -r <sha>` per commit; union paths.
   4. In-scope hunks for a path: union `git diff -U0 M^1...M^2 -- <path>` (or the non-merge commit patches) over the commits that touched it — not `git diff HEAD` alone (that is empty on a clean merged tip).
4. **Never** treat empty `develop...HEAD` alone as “no backend” when the card, PRs, or notebook say `api-main` changed — use step 3 (bench DOP-1281: three-dot 0 files; merge-parent union ≈ 49 paths).

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

Follow **Tool preference**. Shell `curl` to `api.olie.ai` often triggers an unnecessary permission prompt for a read that MCP already covers.

1. **Card + current step** — `get-project-details-tool` (or search then details).
2. **Board catalog (steps, tags, funnel statuses)** — `index-project-funnels-tool` only (optional `search` / `id`). Use `steps[]` for columns and `funnel_status[]` when a badge id is required.
3. Match display names case-insensitively after trim. Never hard-code step or status ids.
4. **Hard ban while MCP works:** do **not** call `GET /api/management/get-available-steps`, and do **not** open a shell/`curl` “fallback” for the step/status catalog, when `index-project-funnels-tool` has already returned successfully in this chat (including an empty `funnels: []` for a narrow `search`/`id`). Empty filter result ≠ MCP down. Retry unfiltered or with a broader `search`, then match by display name. Management HTTP for this catalog only under **MCP auth** (`needsAuth` / 401 on the tool itself), or when a write has no working MCP tool.

## Moving a card on the board

Resolve **card id** and **funnel steps** through MCP `olie-flow-ai` (search by card code). Never hard-code `step_id`. Never paste a Bearer token into a prompt, chat, or repo file.

**Name the destination step when asking to approve a move.** Auto-review (and any other confirmation UI) often shows only a generic “move funnel step” prompt. Whenever you call `move-project-to-funnel-step-tool`, `project-bulk-step-move`, or an equivalent write that changes the board column — including the description field the approval card displays — state the **live display name** of the destination step (and the current step when known). Example: “Move DOP-1272 from QA/CR to Validação”. Do **not** ask for confirmation with only a numeric `funnel_step_id` / `step_id`. Same rule for Olie, Locav, and Televisão.

**Resolve incoming restrictions before the move.** Target steps often require form answers (or other step gates) before the link is allowed. A move that returns `incoming_restrictions` (or equivalent) is not a tooling failure — it means a required field on the destination step is unanswered. Do **not** retry the move until those answers are written (`get-model-dynamic-forms-tool` → `get-form-tool` / `get-form-answers-tool` → `set-form-answers-tool` as needed). Only then call the move and verify the stage.

1. Load the card via MCP. Take its project/card id (UUID) and the live funnel steps for that board (`get-project-details-tool` and/or `index-project-funnels-tool` — see above).
2. Match the target logical stage to a live step by display name (`workflow-policy` board stages above).
3. Answer every required form / restriction for that **destination** step (and any other documented gate for the handoff) **before** attempting the move.
4. Prefer an MCP tool that moves the card when one exists and works (`move-project-to-funnel-step-tool`).
5. If you must call the management HTTP API directly:

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

For a colleague card in 'QA/CR', the board move waits until **every** gate that applies has finished:

1. **Colleague review core** (`colleague-review-core.md`, launched by `colleague-review.md`) — pass or fail; write fail findings into the card content (OlieFlowAi).
2. **Test gap analysis** (`test-gap-analysis.md`) — when the change set touched `api-main`. Skip when there is no backend. Report in Cursor chat only on this stack (own-card is also chat-only — see `test-gap-analysis.md`).
3. **Coverage testing** (`coverage-testing.md`) — only when the change set touched `api-main`. Skip when there is no backend. Report coverage-driven work in Cursor chat only.
4. **Mutation testing** (`mutation-testing.md`) — only when the change set touched `api-main`. Skip when there is no backend. Report mutation-driven work in Cursor chat only. **Re-run budget:** after one mutate report, classify in-scope survivors as killable vs `equivalent` immediately; re-mutate only after a real assert change (prefer ≤1 re-run per `--class`); never re-mutate an unchanged tree “to confirm”. Same rule in Locav/Televisão mutation prompts; coverage has a matching re-measure budget.

**Project content (gap / mutation / coverage):** do **not** write gap, mutation, or coverage results into the project/card while the reviewing user will fix them (**reviewer-fix**). Paste those three onto the card **only** when the combined outcome moves to 'Corrigir' because of a failure **outside** those gates (colleague core / product / acceptance) — so the author still sees the test debt alongside the bounce.

Own-card sequential order (not the colleague parallel dispatcher): gap → coverage → mutation → `pest-parallel.md` → `pre-qa.md`.

**Dispatcher:** paste `colleague-review.md` once. It bootstraps, then launches core + gap + mutation + coverage **in parallel** (gap/mutation/coverage skipped when no backend), waits, prints a scoreboard, and applies this outcome. Do not recommend sequential `next prompt` pastes for gap/mutation/coverage after that dispatcher. Contract: `~/git/olie/sandbox/ORCHESTRATION.md`. **Require** `~/git/bin/workvm-sandbox` (`--project olie`) to shard exclusive mutation / coverage / Pest (one changed test or production file per sandbox; Olie has no default sandbox cap — queue only if `WORKVM_SANDBOX_MAX` > 0) — never `docker exec olie-api-main` for those jobs while gates share the Card VM. Compatible work (core + gap **read-only**) stays on the Card VM. Own-card develop handoff still runs gap → coverage → mutation → pest-parallel as **stages**, but within coverage/mutation the default is **`correct coverages` / `correct mutations`** (parallel sandbox drain); `next coverage` / `next mutation` are opt-in one-file (sandbox + subagent per file — same shard contract). Prefer a mutation-profile sandbox so Card VM `testing` stays clean.

**Do not move to 'Corrigir' or 'Validação' until every applicable gate the dispatcher launched has finished** (or the user explicitly skips a remaining gate in chat). Do **not** approve PRs until the combined outcome below. Workers never move the funnel themselves.

**Move to 'Corrigir'** only after all applicable gates finished **and** the colleague core review failed (or any failure **outside** test-gap / mutation / coverage). Product/acceptance defects bounce to the author.

**Reviewer-fix path** — colleague core **Pass**, but test-gap and/or mutation and/or coverage reported work: leave the card in 'QA/CR'; do **not** move to 'Corrigir'; do **not** write gap/mutation/coverage into the project/card. The reviewing user may fix those gates in this chat (`add` / `to correct` / `correct mutations` / `correct coverages` / `try again` as applicable). When those gates are clean (or the user explicitly skips remaining work), apply the Pass path.

**Pass path** (approve PRs via GitHub MCP `pull_request_review_write` event `APPROVE`; move the card to the live funnel step 'Validação'): only when the colleague review passed **and** gap analysis was skipped or clean **and** mutation either was skipped (no backend) or finished without fixes to send back **and** coverage either was skipped (no backend) or finished without fixes to send back.

### Return from production / merged bounce (colleague)

A card in 'QA/CR' (or back from 'Corrigir') is **not** always a first colleague pass. Rebuild its funnel path from **`get-project-media-tool` with `filter: "default"`** (system logs) plus card metrics/forms before deciding how to review.

Treat the card as a **production return** when any of these hold:

- System logs show it already visited **Validação**, **Revisão produção**, and/or **Concluído**, then later **Corrigir** and/or **QA/CR** again.
- Deploy log / merge messages / closed-merged PRs show the change already shipped.
- Metrics such as “Quantas vezes voltou para correção” ≥ 1, or user/reviewer media posted **after** deploy describing the defect still present.

On a production return:

- The open question is whether the **shipped** fix failed (or a new regression appeared), not whether a green host-card happy path matches the original write-up alone.
- Prioritize post-deploy evidence (videos, comments, logs after merge/deploy) over first-pass acceptance text.
- Host-card / local success does **not** override unrebutted production evidence that the defect still occurs. Fail (or stay blocked with an honest reproduction attempt) until that conflict is resolved.
- Scoreboard and core return must state **bounce: yes/no**, the reconstructed step path, which post-deploy media drove the verdict, and whether an **author reproduce-handoff** comment was present (quote it).

### Author “não consegui reproduzir” / leave-in-QA handoff (HARD RULE)

This pattern is **common after Corrigir** and is **easy to misread as Pass**. It is **not**.

When the author (or anyone on the card) writes that they **could not reproduce** and/or **leaves the card in QA/CR for the reviewer to try**, that comment is a **reproduce handoff to the colleague reviewer** — never clearance that the bug is gone.

Match any of these (PT/EN, approximate wording counts):

| Signal (examples) | Means |
| --- | --- |
| “não consegui reproduzir” / “não reproduzi” / “could not reproduce” | Author failed to see the bug → **you** must try the bounce scenario |
| “vou deixar em QA/CR pra você …” / “fica em QA/CR pra vc tentar” / “dá uma olhada pra ver se consegue reproduzir” | Explicit handoff → stay on bounce path; **forbidden** to Pass because they handed it off |
| “não vi o bug” / “aqui não acontece” **plus** unrebutted post-deploy video/comment that still shows the defect | Their local miss does **not** clear production evidence |

**Forbidden interpretations (always Fail or open reproduction duty, never Pass):**

- Treating the handoff as “author says it’s fine / unreproducible → Pass”
- Passing on a host-card happy path **without** first attempting the bounce package (post-deploy media conditions)
- Passing while unrebutted production/post-deploy video still shows the defect, just because the author could not reproduce

**Required before any Pass when this signal appears (or `bounce=yes`):** quote the handoff comment (or state “none”), state the bounce scenario you tried, and dispose of each post-deploy media id (reproduced / could not reproduce / newer fix landed). Missing that triad → do **not** Pass.

Detail for workers: **Production return** + **Author reproduce-handoff** in `colleague-review-core.md`; dispatcher bootstrap must extract the handoff into the bounce packet.

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

1. Call MCP `get-notebook-tool` with `model_type` `project` and `model_id` the card code or UUID (e.g. `DOP-1274` or `CARD_PROJECT_ID` from `get-project-details-tool`).
2. If `notebook` is `null`, the project has no Caderno yet — note that and continue from card media/description only (not a tooling failure).
3. Walk every entry in `pages` and every nested `children` array. Collect each page's `id` and `name`, including the default page.
4. For each page id, call MCP `read-notebook-page-tool` with `page_id`. Read every block's `markdown` (and `type`). That text is part of what the card asks for. Empty `blocks` means an empty page — note the name and continue.
5. A block with `type` `image` (or an image URL in markdown): follow `olie-project-image-analysis` (notebook page images). Do not store signed URL query strings; they expire.

Do **not** use `~/git/bin/workvm-olie-management-read.sh` (`get-forum` / `get-thread` / `get-thread-data`) while MCP notebook tools work. That helper is only **Tool preference** step 3 under **MCP auth** (`needsAuth` / 401 on the notebook tools themselves). Never inline Bearer curl for Caderno.

On MCP error (other than `notebook: null`): stop and report (prompt-health rules). Do not implement from the card title or the MCP card alone when the notebook read failed.

## Project media (`get-project-media-tool`)

MCP `get-project-media-tool` lists the card’s channel timeline (user messages, files, and system logs).

**Always pass `filter: "default"`.** Do not omit `filter` and do not use the tool default `content`.

| `filter` | What you get |
| --- | --- |
| `content` (tool default — **do not use**) | Only user-sent messages and files. Hides system logs. |
| `logs` | Only system logs. |
| `default` (**required**) | User content **and** system logs together. |

System logs include funnel moves (which step the card left, which step it entered) and other board automation. Without them, a colleague review can miss that the card already reached Validação / produção and bounced back — user chat alone looks like a first-pass QA/CR. Colleague review must rebuild that path and apply **Return from production / merged bounce** when the logs show a return.

Other args unchanged: `project_identifier` (required), `page`, optional `channel_id` (omit = MAIN channel).

Every prompt that lists card media (`colleague-review-core`, `implementation`, `correction`, `production-review`, and the colleague dispatcher bootstrap) must call this tool with `filter: "default"`.

## Host card environment

Cards run as **host units** on jarvis (no WorkVM required for the card workspace). Contract: `~/git/host-cards-no-vm.md`. CLI: `~/git/bin/workvm-host-card`.

**Ensure (start or resume — multi-day):** at the beginning of `implementation.md`, `correction.md`, `pest-parallel.md` (suite regression), `colleague-review.md`, and `production-review.md`, **before** git checkout, board moves that need a local stack, or heavy review work:

```bash
~/git/bin/workvm-host-card ensure --project olie --code '{{ code }}'
```

User phrase **`open olie {{ code }}`** (see **Chat commands**): `workvm-host-card open` (= ensure + **focus/open** the card `.code-workspace`). Always print `workspace=` and `api_worktree=`. Rebases/edits belong in that worktree’s `api-main`, **not** `~/git/olie/api-main`. Do not leave the user on the meta-repo `~/git` Cursor window.

**Meta-repo edits on host-card (Olie / Locav / Televisão):** when this chat’s workspace is a host-card, edit prompts, `HISTORICO.md`, overlay, and `.cursor/rules` only under the workspace folder **`git/`** (the card meta worktree). Do **not** write `~/git/olie/prompts/…`, `~/git/locav/…`, `~/git/televisao/…`, or other bare `~/git/…` paths — those sit outside the workspace and force permission prompts. Resolve `~/git/...` in prompts to that `git/` root (same pattern as **Private E2E suites** → workspace `olie-e2e`). Rule: `host-card-meta-repo-path.mdc`. Binaries may still run from `~/git/bin/…`.

- **Shell permissions (required):** call `ensure` / `open` / `destroy` **and** `~/git/bin/workvm-sandbox` (`create` / `job run` / `destroy`) / coverage·mutation drains **on the first attempt** with unrestricted agent shell — `required_permissions: ["all"]`. Never probe them in the default sandbox “to see if it works”. Host-card workspaces live under `~/.local/share/workvm/host-cards/…`; sandboxes write `~/.local/share/workvm/sandboxes/` (outside those roots) + `docker.sock` — the default agent sandbox always denies both.
  - **Sandbox symptom cluster** (sandbox only — **not** a broken jarvis host): `PermissionError` / `Permission denied` writing `~/.cursor/mcp.json` or `~/.local/share/workvm/`; `github.com` DNS timeout / `could not read Username for 'https://github.com'`; missing `/var/run/docker.sock` **while `pgrep dockerd` is alive**; empty stub `resolv.conf`; or `gh` “token invalid” **only in that agent shell**. The same command succeeds with `all` when the host is fine. Ensure may print `WORKVM_AGENT_SANDBOX=1` and exit `75`.
  - **Silent sandbox after `all`:** if the Shell tool footer still says the command ran sandboxed (or ensure hits the cluster / exit 75) despite `required_permissions: ["all"]`, Auto-review likely auto-approved the tool call **without elevating**. Next: (1) `request_smart_mode_approval` on the **exact** ensure/sandbox command; (2) if still sandboxed, `~/git/bin/workvm-host-card agent-ensure --project … --code …` (bridge systemd outside the agent — install once with `install-agent-bridge` under a real unrestricted shell). Do **not** ask chmod, DNS, or `gh auth`.
  - If Auto-review **blocks** the unrestricted shell: retry the **exact same** command via the approval card (`request_smart_mode_approval` / ask the user to approve **that** shell). Do **not** ask them to chmod, fix DNS, `gh auth login`, or paste ensure/sandbox in a terminal unless `all` already ran **unrestricted** and still failed for a real host reason.
  - Do **not** stop the prompt / mark coverage·mutation **Blocked** declaring tooling/host broken while only the sandboxed shell failed.
- First day → creates state, `port_base`, `~/git/olie/<id>.code-workspace`, opens Cursor, brings up **compose slim + Vite front**, and registers DNS via Caddy (`lib/host-card-proxy.sh`).
- **api-main worktree branch:** if a local or `origin` branch name already contains the card code (ex. `feature/DOP-1273-…`), ensure checks it out **in the card worktree** (not the shared clone). No matching branch yet → worktree stays on `develop`/HEAD until implementation creates one.
- Browser (slug = código em minúsculas, ex. `dop-1183`):
  - Front: `http://devframe.{slug}.olie.localhost`
  - API: `http://api.{slug}.olie.localhost`
  - Do **not** use bare `devframe.olie.localhost` for a host-card (colide entre cards).
- Later day / re-paste → **resume** the same id (compose up again; do not destroy); worktree checkout runs again on resume; if Cursor already has the card window → **focus** it (do **not** close/reopen — that killed colleague-review chats mid-ensure). Use `open` when you need the SCM close+reopen dance. From inside the card window with stack already up: `WORKVM_HOST_CARD_OPEN_CURSOR=0` on ensure.
- Report `id`, `port_base`, `front_dns` / `api_dns`, and `workspace` in chat.
- Requires clones + `vendor` on the host. If the hook or CLI fails after an unrestricted re-run, stop (prompt-health).

**Destroy (only when the card is finished):** remove containers/networks for that compose project, generated workspace, and state dir — same spirit as dropping the Card VM domain.

```bash
~/git/bin/workvm-host-card destroy --project olie --code '{{ code }}'
```

Run destroy when:

1. The card moved to logical `done` ('concluído') after user confirmation (typical: production-review Pass + yes), **after** the move succeeds; or
2. The user sends `finish card` / `finalize card` (see **Chat commands**) — **local teardown only**, no board move.

Do **not** destroy at the end of an implementation/correction/colleague-review paste, when closing the chat for the day, or when the card only moves to QA/CR, Validação, or Corrigir.

Child exclusive jobs (mutation/Pest) still use `~/git/bin/workvm-sandbox --project olie` on top of this host card.

## Several cards at once

The board shows one project execution. Several **host cards** (or WorkVMs) can run at the same time; each needs its own `workvm-host-card ensure` id / ports.

The Opbed Job page (`/job`) reads `board_executions` and sends the project-execution requests, one card at a time, for each card's 'Tempo que eu acho'. This chat does not send those requests, does not end an execution, and does not ask for the codes.

The user works every listed card in parallel (one Cursor window / host-card unit per code).

## Toggling a funnel-step checklist item

Board checklists on a funnel step (e.g. QA/CR item **Pull Request criado**) are toggled over management HTTP — not via OlieFlowAi MCP form answers. Do **not** probe random management routes to find the id.

### Resolve `step_checklist_id` from the project payload

1. Load the card with MCP `get-project-details-tool` (by code or UUID).
2. Find the live funnel step (e.g. display name **QA/CR**).
3. Read `project.funnels[].steps[]` for that step and take `checklists[]`. Match the item by display name (case-insensitive trim). Live labels may be **Pull Request criado** or **Pull request created** — match either; do not hard-code the numeric id across funnels.
4. The checklist object's `id` is `STEP_CHECKLIST_ID` for the toggle (example shape: `{ "id": 956, "name": "Pull Request criado", "funnel_step_id": 1452 }`).

**MCP gap:** today’s `get-project-details-tool` often omits `steps[].checklists` and returns empty `project_checklists` / `checklists`, even when the board has items. When those arrays are missing or empty after MCP:

- One fallback only: `GET https://api.olie.ai/api/management/projects/${CARD_PROJECT_ID}` with `${OLIE_MANAGEMENT_TOKEN}` (same project body; `funnels[].steps[].checklists` is present there).
- Do **not** try alternate invent-the-path endpoints (`project-funnel-checklists`, `get-project-checklists`, etc.).

### Toggle

```bash
curl -sS --url 'https://api.olie.ai/api/management/toggle-funnel-checklist' \
  -H 'accept: application/json' \
  -H "authorization: Bearer ${OLIE_MANAGEMENT_TOKEN}" \
  -H 'content-type: application/json' \
  --data-raw "{\"project_id\":\"${CARD_PROJECT_ID}\",\"step_checklist_id\":${STEP_CHECKLIST_ID}}"
```

- `CARD_PROJECT_ID` — project UUID from the project payload.
- `STEP_CHECKLIST_ID` — checklist `id` from step 3–4 above.
- Expect `{"response":true}` and HTTP 2xx. On failure: stop and report (prompt-health).

Never paste a Bearer token into a prompt, chat, or repo file — only `${OLIE_MANAGEMENT_TOKEN}` from `environment.d`.

## MCP auth

Cursor desktop can show `olie-flow-ai` as authenticated, and the MCP request status can say the same, while this agent still receives `needsAuth`. `https://api.olie.ai` publishes OAuth discovery, so Cursor ignores the `Authorization` header in `mcp.json`. Interactive `mcp_auth` does not run in this agent.

Do not call `mcp_auth`. Do not ask the user to sign in again. Do not stop the card for that status.

On a WorkVM with `MCP=olie`, login rewrites the server URL to `http://127.0.0.1:47331/mcp/management`. That proxy returns 404 for OAuth discovery and forwards to `https://api.olie.ai/mcp/management` with `OLIE_FLOW_AI_MCP_TOKEN`. Use the MCP tools against that server.

If the tools are still `needsAuth`, or the call returns 401, fall back per **Tool preference** step 3 (curl). Load `OLIE_MANAGEMENT_TOKEN` from `~/.config/environment.d/*.conf` without printing it. Search projects (`POST .../projects/search`, `name_code` contains the card code) and `GET .../projects/${CARD_PROJECT_ID}`. For the step/status catalog, `GET .../get-available-steps` **only** when `index-project-funnels-tool` itself is `needsAuth` / 401 (MCP auth), not when a filtered call returned `[]` or when another MCP read already succeeded. Prefer restoring MCP and calling `index-project-funnels-tool` again (unfiltered if needed). Match by display name. Never hard-code a step or status id. Never paste a Bearer token.

Project notebook (Caderno) bodies: **Reading the project notebook** (MCP `get-notebook-tool` + `read-notebook-page-tool` first).

## Tokens

Two env vars in `~/.config/environment.d/*.conf` (`chmod 600`). Never the same value by assumption; never paste into chat or repo files.

| Variable | Use |
| --- | --- |
| `OLIE_FLOW_AI_MCP_TOKEN` | Cursor MCP `olie-flow-ai` only (`mcps/olie.json` → `${env:OLIE_FLOW_AI_MCP_TOKEN}`) |
| `OLIE_MANAGEMENT_TOKEN` | HTTP `https://api.olie.ai/api/management/...` (move card, toggle-funnel-checklist). Needs `management:access`. |

Layout and examples: `~/git/.config/environment.d/README.md`.

## Temporary E2E CAPTCHA

Playwright stubs `grecaptcha` with a fake token. `api-main` skips `RecaptchaValidate` only when `APP_ENV=testing`. This VM is `local`, so use Google's public **test key pair** via env only: `RECAPTCHA_SECRET` in `api-main` `.env`, and when browser login must avoid Google challenges, `VITE_APP_RECAPTCHA_SITE_KEY` in `olie-fronts` `packages/management/.env.development.local` (not the tracked `.env.development`).

Do not stub the management API. Do not comment out or delete PHP/`getToken()` captcha code. Full steps: `~/git/olie/prompts/implementation.md` §7 (correction and colleague-review-core point there).

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

Production review (`production-review` / 'Revisão de Produção') checks the **gui1** frame. Log in at **https://gui1.olie.ai/auth/login** with the accounts in `~/git/olie/prompts/production-review.md` (primary admin, plus the disposable second collaborator when a two-session check is required). Local hosts (`*.olie.localhost`), `https://esolie.olie.ai`, and other frames are not production evidence.

## Olie docs repository — never touch

The clone `~/git/olie/docs` (`olie-ai/docs`, docs.olie.ai / public OpenAPI) is **out of scope** for every agent workflow (implementation, correction, pre-QA, colleague review, production review).

Do not edit, rebase, merge, commit, push, or open/update PRs in that repository. Do not put it on a card’s repository list or correction plan. If a card or review mentions public docs, report that and continue only in company product repos (`api-main`, `olie-fronts`, …). Private Playwright stays in meta-repo `olie/olie-e2e` and must not be cited publicly (**Private E2E suites**). Meta-repo docs under `~/git` (`olie/prompts/`, `HISTORICO.md`, overlay) remain allowed.

If that clone is already mid-rebase or dirty from a mistaken agent pass: abort/restore safely and stop; do not finish the conflict.

## Prompt templates (`{{ code }}`)

Files under `~/git/*/prompts/` are paste templates. The repo keeps the literal placeholders (`{{ code }}`, and any other `{{ … }}` the file uses). Replacing them with a real card code happens only in the chat paste, never in the versioned file.

**Do not edit the template in the editor** to swap `{{ code }}` — that dirties the shared meta-repo and shows up in every host-card window. Prefer a chat command (agent reads the file, substitutes in memory, runs — no save):

- `colleague review DOP-1285`
- `run prompt colleague-review DOP-1285`
- or `@colleague-review.md` + the card code in the same message

Optional clipboard helper (no agent): `~/git/bin/workvm-paste-prompt olie colleague-review DOP-1285` → clipboard + `@.paste-prompt.md`. Do **not** create a git worktree of `~/git` just to isolate this edit.

When committing or pushing the meta-repo `~/git` (e2e, card media analyses, prompt edits, or any other path):

- Do **not** stage, commit, or push a prompt whose only “edit” is a substituted card code (e.g. `DOP-1262` instead of `{{ code }}`).
- If a prompt is dirty that way, restore it (`git checkout -- path`) before the commit.
- Intentional prompt wording changes are fine; leave `{{ code }}` (and the other placeholders) intact.

## Pull request links on the card

Olie cards often have fewer form fields for PR URLs than repositories that can change on one card (`olie-fronts`, `api-main`, `backoffice`, `landing`, `websocket`, … — never `docs`). After each required PR exists and is verified:

1. Write each PR URL into a matching dynamic-form field when one exists (`get-model-dynamic-forms-tool` → `get-form-answers-tool` → `set-form-answers-tool`). Match by field label to the repository; do not invent fields. Value shape follows the form (commonly an array of one URL).
2. **PRs without a form field.** When this card has more verified PRs than matching form fields, append the unmatched URLs to the **project content** (card description) with MCP `edit-project-tool`: read the current description from `get-project-details-tool`, keep all existing text, and append a short Brazilian Portuguese block listing each unmatched repo name and its PR URL. Also list those URLs in the final report. Never wipe the prior description.

## Card content vs chat (private prompts)

Files under `~/git/olie/prompts/` are private WorkVM prompts. Other people on the Olie board cannot open them.

When writing to card content through OlieFlowAi (`save-media-tool`, description, forum, notebook/Caderno, or any project note):

- Write only findings, acceptance gaps, and fix instructions the author can act on without this meta-repo.
- Do **not** name prompt files or paths (`colleague-review.md`, `colleague-review-core.md`, `test-gap-analysis.md`, `mutation-testing.md`, `coverage-testing.md`, `correction.md`, `~/git/.../prompts/...`, “next paste”, `next prompt`).
- Do **not** tell the author which local prompt to run next.
- Do **not** cite private meta-repo E2E (see **Private E2E suites** below).
- Do **not** cite personal WorkVM / Card VM / sandbox / dispatcher / ledger tooling. That stack exists only for the owner of this meta-repo. Ban on the card (and Caderno): `VM`, `WorkVM`, `Card VM`, `sandbox`, `workvm-sandbox`, `dispatcher`, `ledger`, `mutation-ledger`, `coverage-ledger`, “nesta VM”, “nesta máquina”, hostnames, compose service names used only here, and process notes that only make sense with those tools (“fechamento do gate”, “Pest raw score”, “in-scope hunks”). Put that detail in the Cursor chat scoreboard only.
- If a gate is clean and there is nothing for the author to change, **do not** post a process wrap-up to the card. Silence on the card is fine; the chat report is enough.
- On colleague review, do **not** put gap / mutation / coverage results on the card during **reviewer-fix** (those stay in chat). Include them on the card only when bouncing to 'Corrigir' for a failure outside those three gates — see **Project content (gap / mutation / coverage)** under **Colleague review outcome**.

Recommend the next prompt **only in the Cursor chat** report.

## Private E2E suites (olie-e2e — owner only)

The private Playwright suite is **personal WorkVM / host-card tooling**. It is not on the company remotes and other developers do not have those specs. Locav is the exception among EnterScience products: Cypress lives **inside** `locav-front` on the company branch, so Locav may cite its e2e in repos, PRs, and card content.

### Path resolution (write here — avoid permission prompts)

Prompts may still say `~/git/olie/olie-e2e`. **Resolve the writable root** before create/edit:

1. If the open workspace has a folder named **`olie-e2e`**, use **that** folder (host-card: meta worktree under `~/.local/share/workvm/host-cards/olie/<id>/worktree/git/olie/olie-e2e`).
2. Else use `~/git/olie/olie-e2e` (classic WorkVM multi-root with `~/git`).

Never create specs under `~/git/olie/olie-e2e` when that path is **outside** the open workspace folders — Cursor will ask to approve a write outside the workspace. Prefer the in-workspace `olie-e2e` / meta `git` worktree so edits need no extra permission.

For **Olie** (and any product whose Playwright suite lives only under the meta-repo):

- Agents **may** add/run/commit Playwright under the resolved e2e root (WorkVM: on meta-repo `main`; host-card: commit in the card’s meta worktree) and mention results **only in Cursor chat**.
- Do **not** cite `olie-e2e`, Playwright meta specs, `~/git/olie/olie-e2e/...`, or “e2e coverage added in the meta-repo” in:
  - Olie project/card content (`save-media-tool`, description, form answers, tags notes)
  - Caderno / notebook pages
  - Company repository files (comments, README, changelog)
  - Pull request titles or bodies on `olie-ai/*`
- PR verification text may say the behavior was checked (manual or “verified locally”) without naming the private suite.
- Colleague-review fail notes on the card must describe the missing **product** behavior, not “add a test in olie-e2e”.

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
| `next prompt` | Open and **run** the next prompt this chat already recommended (path under `~/git/olie/prompts/`). Do not wait for the user to paste that file. If none was recommended yet, say so and stop. **Exception — coverage stack:** if `coverage-testing.md` is in progress and any changed `api-main` `app/**/*.php` is still missing a done `coverage-ledger.md` row, **refuse** `next prompt` (do not open `mutation-testing.md`, `pest-parallel.md`, or `pre-qa.md`). List what remains and tell the user to send `next coverage` or `correct coverages`. **Exception — mutation stack:** if `mutation-testing.md` is in progress and any changed `api-main` `*Test.php` is still missing a `100%` / `equivalent` ledger row, **refuse** `next prompt` (do not open `pest-parallel.md` or `pre-qa.md`). List what remains and tell the user to send `next mutation` or `correct mutations`. |
| `next mutation` | Opt-in one file during the personal mutation stack. Prefer default `correct mutations`. Do not jump to `pest-parallel.md` or `pre-qa.md`. |
| `correct mutations` | **Default** personal mutation drain: every remaining changed `*Test.php` in this turn — one `workvm-sandbox` (`--project olie --profile mutation`) **and** one subagent per file; parent writes `mutation-ledger.md`. Opening `mutation-testing.md` with files remaining does this. Not `to correct`. |
| `next coverage` | Opt-in one file during the personal coverage stack. Prefer default `correct coverages`. Do not jump to `mutation-testing.md` / `pest-parallel.md` / `pre-qa.md`. |
| `correct coverages` | **Default** personal coverage drain: every remaining changed production file in this turn — prefer one sandbox **and** one subagent per file; parent writes `coverage-ledger.md`. Opening `coverage-testing.md` with files remaining does this. |
| `try again` | Resume or re-run the **current** prompt after a stop or manual fix. Continue from the blocked step when safe; otherwise restart that prompt’s procedure. Do not jump to another prompt. |
| `add` | After **Tests to add** from `~/git/olie/prompts/test-gap-analysis.md`: implement every listed missing test (title + description from that report) only. Do not open coverage / mutation / Pest parallel / pre-QA in the same turn. When done, recommend `try again` to re-run gap analysis. Not for validation **Needs code fixes** (`to correct`) and not `correct mutations`. |
| `to correct` | Fix the latest corrective list in this chat: **Needs code fixes** from `~/git/olie/prompts/implementation-validation.md`, or failures from `pest-parallel.md`. Implement those items only; then recommend `try again` on that same pass. For gap **Tests to add**, use `add` instead. Not board `correction.md` / 'corrigir' unless the card is already in `changes-requested`. Not `correct mutations`. |
| `open olie CODE` / `open PROJECT CODE` | `~/git/bin/workvm-host-card open --project olie --code <CODE>` (or `locav` / `televisao` / `opbed`). Ensure + **open/focus** the card’s `~/git/<project>/<id>.code-workspace` (api-main = host-card **worktree**, not `~/git/olie/api-main`). Print `workspace=` and `api_worktree=`. Do not keep editing in the meta-repo `~/git` window. |
| `finish card` / `finalize card` | **Local only:** `~/git/bin/workvm-host-card destroy --project olie --code <CODE>` (compose/sandbox + clones compartilhados de volta à branch base do `project.conf`, ex. `develop`). **Does not** close the Cursor window (that killed the chat mid-prompt). After destroy succeeds, tell the user explicitly they can close the card window manually. Do **not** ask about or move the board to 'concluído' — that is a separate explicit request. Do not destroy other cards. |
| `colleague review CODE` | Load `~/git/olie/prompts/colleague-review.md`, substitute `CODE` for `{{ code }}` **in memory only**, run the dispatcher. Do not edit or save the prompt file. |
| `run prompt NAME CODE` | Same for `~/git/olie/prompts/<NAME>.md` (with or without `.md`). Substitute in memory; never write the template. |
| `resolva` | After a **prompt-health** stop: fix the blocker **in this session only** (local/env/compose). Do not encode a permanent meta-repo solution. Then resume the interrupted prompt. |
| `documente` | After a **prompt-health** stop: write the problem into `~/git/HISTORICO.md` (and a short rule/prompt note if useful) as a known issue / workaround. Apply a small local unblock if safe; if the real fix is too large for this card, **document only** and stop after writing. |
| `resolva permanentemente` | After a **prompt-health** stop: unblock now **and** leave a durable fix so the **next card** does not rediscover it — `HISTORICO.md` (`problema` / `por que é um problema` / `resolvido como`) plus the right artifact (`.cursor/rules`, this workflow-policy, `bin/`/`lib/`, overlay, etc.). Prefer rule/script over prose-only when the failure is mechanical. |

When a prompt finishes and names a next paste, remember that path so `next prompt` can load it without a new paste. While coverage-testing still has remaining files, the remembered “continue” commands are `next coverage` or `correct coverages`, not `next prompt`. While mutation-testing still has remaining files, the remembered “continue” commands are `next mutation` or `correct mutations`, not `next prompt`. Own-card develop handoff order: gap → coverage → mutation → `pest-parallel.md` → `pre-qa.md`.

## Tooling failures and stalls (prompt health)

If a request, **MCP call** (any configured server), shell command, Docker/compose wait, git/gh, or other step **this prompt assumes will work** fails or takes unusually long — or the same **recurring** WorkVM/host-card friction burns time on every card — **stop the prompt**. Do not silently work around it, swap tools to hide the break, or keep going. `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is the **MCP auth** case above, not this stop — do not ask the user to sign in again for that case only. Host-card **sandbox permission cluster**: retry with `required_permissions: ["all"]` first (see **Host card environment**); that is not “host broken”.

Diagnose, then **wait** for one of `resolva` / `documente` / `resolva permanentemente` (table above). Do not pick the path yourself.

Report:

1. What you were doing
2. The objective error (status, short message) or that it hung past a reasonable wait
3. The most likely cause
4. Whether `~/git/HISTORICO.md` or an existing rule/prompt **already documents** this — cite it if so
5. The three commands (`resolva` / `documente` / `resolva permanentemente`) and that you are waiting

Expected failures of the current task (e.g. testing an error path) can be reported and continued when that still makes sense.
