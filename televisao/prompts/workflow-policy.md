# Televisão Workflow Policy

Use this file when another Televisão prompt needs a shared workflow decision. It prevents the same policy from diverging across card-development, review, and handoff prompts.

## Tool preference

When more than one tool can do the same job, use this order (do not skip ahead to avoid a prompt):

1. **MCP** — `olie-flow-ai` for card/board/forms; GitHub MCP for PR approve/merge/read when the prompt uses those tools.
2. **`gh`** — GitHub CLI when MCP is the wrong tool or unavailable. **Exception:** pre-QA **creates** PRs with `gh` first (GitHub MCP App form deferral / weak assignee-label support); see `pre-qa.md`.
3. **curl** — last resort for Olie management HTTP when MCP itself is `needsAuth` / 401. Never prefer HTTP over a working MCP tool. Project Caderno/forum: MCP `get-notebook-tool` + `read-notebook-page-tool` first; `~/git/bin/workvm-olie-management-read.sh` only under **MCP auth**.

Never paste a Bearer token. Never silently swap tools to hide a failure (except `olie-flow-ai` `needsAuth` → **MCP auth** below).

## Expensive re-run budget

Do **not** repeat an expensive step when nothing material changed since the last run of that step in this chat (same code/asserts/env/deploy, same card diff).

| Expensive step | Re-run only when |
| --- | --- |
| `pest --mutate` / `pest --coverage` | Test or production blobs under test changed (`sha:` mismatch / missing stamp), or tooling was fixed; mutation also allows ≤1 re-mutate per `--class` after killable asserts (see mutation/coverage prompts). Matching `sha:` in the ledger → skip sandbox across chats. |
| Full Pest suite (`pest-parallel`) | A fix landed after a red suite, or the user sent `try again` after that fix. Always `--ci` (TIA `locally()` must not shrink the regression suite). |
| Gap analysis / implementation-validation | Diff or requirements changed, or `try again` after `add` / `to correct`. |
| Colleague dispatcher gates | A gate was blocked/failed and the user asks to retry **that** gate — do not re-dispatch green gates “to confirm”. |
| Pre-QA checklist / production smoke | Code, PR, or production deploy changed; or a prior check failed and was fixed. |
| Correction verification | Re-check only what this correction changed — not the whole unrelated suite “for safety”. |

`try again` means “run again **after** a real change or unblock”, not “repeat the same measurement on an unchanged tree”.

## Pest TIA (local, meta only)

Do **not** edit `televisao-api` `tests/Pest.php` / `.gitignore` (company repo). Enable with `PEST_TIA_LOCALLY=1` on the **sandbox** slim compose (meta). Needs `git` + coverage driver in the CLI image. **Regression** (`pest-parallel`) always passes `--ci`. Opt out once: `--no-tia`.

## Backend change-set (when base...HEAD is empty)

Shared recipe for gap / mutation / coverage / colleague bootstrap on `televisao-api` (repository base from `project.md`). Same idea as Olie when the feature is already merged and three-dot is empty.

1. **Always** include dirty paths: `git status --short`, `git diff --name-only HEAD`, and untracked files.
2. **Primary** branch diff: `git diff --name-only <base>...HEAD` (three-dot). In-scope hunks: `git diff -U0 <base>...HEAD -- <path>`.
3. If that list is **empty** but the card still has backend work: resolve feature tip vs base; else PR merge commits (`git log --merges --grep='<CODE>'`, skip “merge base into branch” sync merges) → `git diff --name-only M^1...M^2`; else non-merge `--grep='<CODE>'` + `git diff-tree -r`. In-scope hunks from those commit diffs, not bare `HEAD`.
4. **Never** treat empty three-dot alone as “no backend” when the card/PRs say the API changed.

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
2. **Board catalog (steps, tags, funnel statuses)** — `index-project-funnels-tool` only. Optional `search` (e.g. `Tele.Visão` or `Revisado`) or `id` of a known step/tag/status. From the matching funnel (`Dev - Tele.Visão` for this product):
   - `steps[]` — board columns (`id`, `name`) for moves like 'Corrigir' / 'QA/CR'
   - `funnel_status[]` — status badges (`id`, `name`) such as 'Revisado' (not a step)
3. Match display names case-insensitively after trim. Never hard-code step or status ids.
4. **Hard ban while MCP works:** do **not** call `GET /api/management/get-available-steps`, and do **not** open a shell/`curl` “fallback” for the step/status catalog, when `index-project-funnels-tool` has already returned successfully in this chat (including an empty `funnels: []` for a narrow `search`/`id`). Empty filter result ≠ MCP down. Retry: call again with **no** `search`/`id`, or a broader `search` (board name, `Revisado`, prefix `TV`), then pick the product funnel by display name. Management HTTP for this catalog is allowed **only** under **MCP auth** below (`needsAuth` / 401 on the tool itself), or when a write has no working MCP tool.

## Moving a card on the board

Resolve **card id** and **funnel steps** through MCP `olie-flow-ai` (search by card code). Never hard-code `step_id`. Never paste a Bearer token into a prompt, chat, or repo file.

**Name the destination step when asking to approve a move.** Auto-review (and any other confirmation UI) often shows only a generic “move funnel step” prompt. Whenever you call `move-project-to-funnel-step-tool`, `project-bulk-step-move`, or an equivalent write that changes the board column — including the description field the approval card displays — state the **live display name** of the destination step (and the current step when known). Example: “Move TV-123 from QA/CR to Validação”. Do **not** ask for confirmation with only a numeric `funnel_step_id` / `step_id`. Same rule for Olie, Locav, and Televisão.

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

1. **Colleague core** (`colleague-review-core.md`, launched by `colleague-review.md`) — pass or fail; write fail findings into the card content (OlieFlowAi).
2. **Test gap analysis** (`test-gap-analysis.md`) — when the change set touched `televisao-api` (backend only). Skip when there is no backend. Report in Cursor chat only on this stack (own-card is also chat-only — see `test-gap-analysis.md`).
3. **Coverage testing** (`coverage-testing.md`) — only when the change set touched `televisao-api`. Skip when there is no backend. Report coverage-driven work in Cursor chat only.
4. **Mutation testing** (`mutation-testing.md`) — only when the change set touched `televisao-api`. Skip when there is no backend. Report mutation-driven work in Cursor chat only. **Re-run budget:** after one mutate report, classify in-scope survivors as killable vs `equivalent` immediately; re-mutate only after a real assert change (prefer ≤1 re-run per `--class`); never re-mutate an unchanged tree “to confirm”. Coverage has a matching re-measure budget.

**Project content (gap / mutation / coverage):** do **not** write gap, mutation, or coverage results into the project/card while the reviewing user will fix them (**reviewer-fix**). Paste those three onto the card **only** when the combined outcome moves to 'Corrigir' because of a failure **outside** those gates (colleague core / product / acceptance) — so the author still sees the test debt alongside the bounce.

Own-card sequential order: gap → coverage → mutation → `pest-parallel.md` → `pre-qa.md`.

**Dispatcher:** paste `colleague-review.md` once. It bootstraps, then launches core + gap + mutation + coverage **in parallel** (gap/mutation/coverage skipped when no backend), waits, prints a scoreboard, and applies this outcome. Do not recommend sequential `next prompt` pastes for gap/mutation/coverage after that dispatcher. Contract: `~/git/televisao/sandbox/ORCHESTRATION.md`. Prefer `~/git/bin/workvm-sandbox --project televisao` to shard exclusive mutation / coverage (one changed test or production file per sandbox; queue when over `WORKVM_SANDBOX_MAX`). Compatible work (core + gap) stays on the Card VM. Own-card develop handoff still runs gap → coverage → mutation → pest-parallel as **stages**, but within coverage/mutation the default is **`correct coverages` / `correct mutations`** (parallel drain); `next coverage` / `next mutation` are opt-in one-file.

**Do not move to 'Corrigir' or set 'Revisado' until every applicable gate the dispatcher launched has finished** (or the user explicitly skips a remaining gate in chat). Do **not** approve or merge PRs until the combined outcome below. Workers never move the funnel themselves.

**Move to 'Corrigir'** only after all applicable gates finished **and** the colleague core review failed (or any failure **outside** test-gap / mutation / coverage). Product/acceptance defects bounce to the author.

**Reviewer-fix path** — colleague core **Pass**, but test-gap and/or mutation and/or coverage reported work: leave the card in 'QA/CR'; do **not** move to 'Corrigir'; do **not** write gap/mutation/coverage into the project/card. The reviewing user may fix those gates in this chat (`add` / `to correct` / `correct mutations` / `correct coverages` / `try again` as applicable). When those gates are clean (or the user explicitly skips remaining work), apply the Pass path.

**Pass path** (approve PRs via GitHub MCP `pull_request_review_write` event `APPROVE`, merge when all approved, funnel status 'Revisado'): only when the colleague review passed **and** gap analysis was skipped or clean **and** mutation either was skipped (no backend) or finished without fixes to send back **and** coverage either was skipped (no backend) or finished without fixes to send back. Resolve 'Revisado' with `index-project-funnels-tool` → that board's `funnel_status[]` by display name, then `edit-project-tool` with `funnel_status` `{ project_funnel_id, funnel_status_id }`. Never hard-code the status id. Never resolve that id via `get-available-steps` / curl when the index tool works (see **Resolving funnel steps**). If that funnel has no 'Revisado' status, use the move procedure above for the closest live step and report the available statuses.

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

1. Call MCP `get-notebook-tool` with `model_type` `project` and `model_id` the card code or UUID (e.g. `TV-16` or `CARD_PROJECT_ID` from `get-project-details-tool`).
2. If `notebook` is `null`, the project has no Caderno yet — note that and continue from card media/description only (not a tooling failure).
3. Walk every entry in `pages` and every nested `children` array. Collect each page's `id` and `name`, including the default page.
4. For each page id, call MCP `read-notebook-page-tool` with `page_id`. Read every block's `markdown` (and `type`). That text is part of what the card asks for. Empty `blocks` means an empty page — note the name and continue.
5. A block with `type` `image` (or an image URL in markdown): follow `televisao-project-image-analysis` (notebook page images). Do not store signed URL query strings; they expire.

Do **not** use `~/git/bin/workvm-olie-management-read.sh` (`get-forum` / `get-thread` / `get-thread-data`) while MCP notebook tools work. That helper is only **Tool preference** step 3 under **MCP auth** (`needsAuth` / 401 on the notebook tools themselves). Never inline Bearer curl for Caderno.

On MCP error (other than `notebook: null`): stop and report (prompt-health rules). Do not implement from the card title or the MCP card alone when the notebook read failed.

## Host card environment

Cards run as **host units** on jarvis (no WorkVM required for the card workspace). Contract: `~/git/host-cards-no-vm.md`. CLI: `~/git/bin/workvm-host-card`.

**Ensure (start or resume — multi-day):** at the beginning of `implementation.md`, `correction.md`, `pest-parallel.md`, `colleague-review.md`, and `production-review.md`, **before** git checkout, board moves that need a local stack, or heavy review work:

```bash
~/git/bin/workvm-host-card ensure --project televisao --code '{{ code }}'
```

- **Shell permissions (required):** call `ensure` / `destroy` **on the first attempt** with unrestricted agent shell — `required_permissions: ["all"]`. Never probe them in the default sandbox “to see if it works”.
  - **Sandbox symptom cluster** (sandbox only — **not** a broken jarvis host): `PermissionError` / `Permission denied` writing `~/.cursor/mcp.json`; `github.com` DNS timeout / `could not read Username for 'https://github.com'`; missing `/var/run/docker.sock`; empty stub `resolv.conf`; or `gh` “token invalid” **only in that agent shell**. The same ensure succeeds with `all` when the host is fine.
  - If Auto-review **blocks** the unrestricted shell: retry the **exact same** command via the approval card (`request_smart_mode_approval` / ask the user to approve **that** shell). Do **not** ask them to chmod, fix DNS, `gh auth login`, or paste ensure in a terminal unless `all` already ran and still failed for a real host reason.
  - Do **not** stop the prompt declaring tooling/host broken while only the sandboxed shell failed.
- First day → creates state, `port_base`, `~/git/televisao/<id>.code-workspace`, opens Cursor, and brings up **compose slim** (`televisao/sandbox/host-card-ensure.sh`) using clones under `~/git/televisao`.
- Later day / re-paste → **resume** the same id (compose up again; do not destroy).
- Report `id`, `port_base`, URLs, and `workspace` in chat. Prefer that workspace window for the card.
- Exclusive jobs still use `~/git/bin/workvm-sandbox --project televisao`. If the hook or CLI fails after an unrestricted re-run, stop (prompt-health).

**Destroy (only when the card is finished):**

```bash
~/git/bin/workvm-host-card destroy --project televisao --code '{{ code }}'
```

Run destroy when the card moved to logical `done` after user confirmation (typical: production-review Pass + yes), **after** the move succeeds; or when the user sends `finish card`. Do **not** destroy at the end of an implementation/correction/colleague-review paste or when closing the chat for the day.

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

These suites are **private** (owner-only WorkVM tooling). Agents may add/run/commit them on meta-repo `main` and mention results **only in Cursor chat**. Do **not** cite `televisao-*-e2e`, Playwright meta paths, or “e2e coverage in the meta-repo” in card content, Caderno/notebook, company repos, or PR titles/bodies. Locav may cite Cypress because it ships inside `locav-front`; Televisão may not. Verification text may say the behavior was checked locally without naming the private suite.

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

## Closing PR review feedback

GitHub exposes review feedback in two shapes. Agents must close both; chat-only “done” is not enough.

| Shape | How it appears | How to close |
| --- | --- | --- |
| **Inline thread** | Line/file conversation; has **Resolve** | After the fix **and** the validation stack for this return (at least `implementation-validation`; when backend changed also gap → coverage → mutation → Pest parallel as applicable): mark the thread **Resolved** (`resolveReviewThread` / MCP). |
| **Review body** | Summary on `CHANGES_REQUESTED` / substantive `COMMENTED` with **no** inline threads | GitHub has **no** Resolve on the body. After every actionable point is addressed **and** that same validation stack has passed: post **one** public PR audit comment listing each point (`✅` / `⬜` + reason) with commit SHAs on the **pushed** tip. Do **not** dismiss the review to fake closure. |

**Timing (do not invert):**

1. **`correction.md`** — implement fixes + local regression tests; draft the audit checklist in the chat report. Do **not** Resolve threads, do **not** post the audit comment, and do **not** treat commit/push as “closing the review” in that paste.
2. **`implementation-validation.md`** (then gap → coverage → mutation → `pest-parallel` when backend changed; Televisão may insert `recommendation.md` before validation per that project’s flow).
3. **`pre-qa.md` §5.0** — commit/push if needed, then Resolve + audit comment, then move to 'QA/CR'.

Marking a finding “resolved” on GitHub before those validations is a miss: the reviewer would see green closure on an unvalidated tip.

Loading feedback for correction / return to 'QA/CR':

1. Resolve associated PR URLs (**Code review form** / card PR fields / project content).
2. Read **threads** (`get_review_comments` / `reviewThreads`) **and** **reviews** (`get_reviews`). Empty threads alone ≠ “no PR feedback”.
3. Triage every actionable thread comment and every actionable body bullet like any other finding.

`correction.md` §8b prepares the close (draft only). `pre-qa.md` §5.0 **owns** the public close (Resolve + audit) before the move back to 'QA/CR'.

## Code review form

The card's code-review form holds **Revisor(es)**, **Pull Request (front)**, and **Pull Request (back)**. Read and write it with MCP `olie-flow-ai`. Do not call `dynamic-forms/get-form-answers` or `system/bulk-update/answer_pool`. Never hard-code form ids, funnel ids, or field ids. Never paste a Bearer token.

1. `get-model-dynamic-forms-tool` with `model` `project` and `model_id` the project UUID (not the card code).
2. Copy, unchanged, the funnel-form `target` whose fields include those three labels.
3. `get-form-answers-tool` with that `target`.

**Revisor(es).** `answer` is a JSON string of an array of `{id, name}`. Those items are the PR reviewers. Do not use every collaborator, and do not drop the assignee unless that person is absent from this list. Parse the string. `gh --reviewer` needs a GitHub login that is a collaborator on that repository. Add a person only when their `name` matches exactly one collaborator login. When a name matches none, or more than one, do not add that person and do not stop the pull request. If `answer` is null, the array is empty, or nobody matches, open the pull request with no reviewers. Report each skipped name in the final report.

**Pull request links.** After each PR exists and `gh pr view` confirms it, write the URL with `set-form-answers-tool` on the same `target`. Send only the fields that change. **Pull Request (front)** gets the `televisao-front` PR URL. **Pull Request (back)** gets the `televisao-api` PR URL. A changed `televisao-meet-front` or `televisao-meet-core` PR goes only into a field whose label names that repository. Use each field's `id` from `get-form-answers-tool`. The value is an array of one URL, `["https://..."]`, not a bare URL. If that repository has no PR, do not send that field. Then `get-form-answers-tool` again and confirm each written URL is stored.

**PRs without a form field.** The code-review form only covers front/back. When this card also has a verified PR for another repository (typically `televisao-meet-front` or `televisao-meet-core`) and no form field label matches that repository, **do not invent a field**. Append those URLs to the **project content** (card description) with MCP `edit-project-tool`: read the current description from `get-project-details-tool`, keep all existing text, and append a short Brazilian Portuguese block listing each unmatched repo name and its PR URL. Also list those URLs in the final report. Never wipe the prior description.

## Pull request body

The body of each pull request is `.github/pull_request_template.md` in that repository, with every section filled. Paths: `~/git/televisao/televisao-api/.github/pull_request_template.md`, `~/git/televisao/televisao-front/.github/pull_request_template.md`, `~/git/televisao/televisao-meet-front/.github/pull_request_template.md`, `~/git/televisao/televisao-meet-core/.github/pull_request_template.md`. Keep the headings and the checklist items. Replace the HTML comments that ask for content. Do not replace the template with a short summary. If a repository has no template file, stop and report; do not invent the body.

- **Link do card na Olie:** `https://esolie.olie.ai/projects/{CARD_PROJECT_ID}/details/overview`, with the project UUID.
- **PR(s) relacionados:** the other repositories' pull request URLs when this card changes more than one. After every required PR exists, `gh pr edit` each body so that line has the real URLs. When this card changes only one repository, mark **Não se aplica**.
- **Descrição da solução técnica:** what changed in this repository, in Brazilian Portuguese.
- **Pontos em aberto:** the open points, or **Não se aplica** when there are none.
- Check a checklist box only when that item was done for this change. Leave it unchecked when it does not apply.

The title stays English. `gh pr view` must still show the template headings, the card link, and the related pull request URL when one exists.

## Prompt templates (`{{ code }}`)

Files under `~/git/*/prompts/` are paste templates. The repo keeps the literal placeholders (`{{ code }}`, and any other `{{ … }}` the file uses). Replacing them with a real card code happens only in the chat paste, never in the versioned file.

When committing or pushing the meta-repo `~/git` (e2e or any other path):

- Do **not** stage, commit, or push a prompt whose only “edit” is a substituted card code (e.g. a real card code instead of `{{ code }}`).
- If a prompt is dirty that way, restore it (`git checkout -- path`) before the commit.
- Intentional prompt wording changes are fine; leave `{{ code }}` (and the other placeholders) intact.

## Card content vs chat (private prompts)

Files under `~/git/televisao/prompts/` are private WorkVM prompts. Other people on the Olie board cannot open them.

When writing to card content through OlieFlowAi (`save-media-tool`, description, forum, notebook/Caderno, or any project note):

- Write only findings, acceptance gaps, and fix instructions the author can act on without this meta-repo — **plus** the **Evidence table on project content** below (allowed exception).
- Do **not** name prompt files or paths (`colleague-review.md`, `colleague-review-core.md`, `test-gap-analysis.md`, `mutation-testing.md`, `coverage-testing.md`, `correction.md`, `~/git/.../prompts/...`, “next paste”, `next prompt`).
- Do **not** tell the author which local prompt to run next.
- Do **not** cite private meta-repo Playwright (`televisao-front-e2e` / `televisao-meet-front-e2e`) — see **Running Playwright**.
- If a gate is clean and there is nothing for the author to change, **do not** post a prose process wrap-up to the card. The **Evidence table** still applies when the trigger says to write it.
- On colleague review, do **not** dump gap / mutation / coverage **findings lists** onto the card during **reviewer-fix** (those stay in chat). Include author-facing findings when bouncing to 'Corrigir' for a failure outside those three gates — see **Project content (gap / mutation / coverage)** under **Colleague review outcome**. The **Evidence table** on Pass or Corrigir bounce is separate and **required** (see below).

Recommend the next prompt **only in the Cursor chat** report.

## Evidence table on project content

Same contract as Olie (`~/git/olie/prompts/workflow-policy.md` **Evidence table on project content**): upsert a Brazilian Portuguese evidence table into the card description at the end of **pre-qa** (Implementation), **correction**, **colleague-review** (Pass or Corrigir only — not mid reviewer-fix), and **production-review**. Keep other description text; replace a block only when the `###` heading matches exactly.

Televisão specifics:

- **Front e2e:** private Playwright — on the card use `verificado localmente (ok)` / `falhou` / `n/a` only; never name `televisao-*-e2e` or meta paths (**Running Playwright**).
- **Back formatting / generated commits to exclude from diff `A..B`:** dedicated Pint commit and dedicated Scribe output commit when present (**Scribe (API docs)** / **Formatting**).
- **Back repo:** `televisao-api`. Front may include `televisao` Next app and/or meet fronts when touched — one **Front** section covering the changed front surface(s).
- Still ban prompt paths, sandbox/VM/ledger jargon on the card.

### Template (Televisão)

```markdown
### Evidência — Implementation

**Front**
| check | resultado |
| --- | --- |
| deploy | ok / falhou / n/a |
| e2e | verificado localmente (ok) / falhou / n/a |
| tsc | ok / falhou / n/a |
| lint | ok / falhou / n/a |

**Back**
diff: abc1234..def5678 (sem Pint/Scribe)
| check | resultado |
| --- | --- |
| pint | ok / n/a |
| phpstan | ok / falhou / n/a |
| mutation | X% no diff; +Y pp; meta 1 pp: sim/não/n/a |
| coverage | X% no diff; +Y pp; meta 1 pp: sim/não/n/a |
| all test | X% (ou N passed / M total) |
```

## Language

- UI copy, user-facing product content, and card notes are Brazilian Portuguese.
- Commit messages and pull request titles are English.
- Pull request bodies follow **Pull request body** above.

## Formatting

- During implementation, do not run Pint unless the user explicitly asks for it or the task is the pre-QA workflow.
- During pre-QA, run Pint for affected `televisao-api` PHP changes (`docker exec televisao-backend`). If Pint changes files, isolate those formatting-only changes in a dedicated commit; do not create an empty formatting commit.

## Scribe (API docs)

`televisao-api` uses Knuckles Scribe (`config/scribe.php`, `php artisan scribe:generate`). Same idea as the dedicated Pint commit: reviewers should not have to read generated blobs mixed into feature commits.

- When a card changes API inputs/outputs (routes, FormRequests, resources, status codes, or Scribe annotations), update the **source** docs (controller `@group` / `@response` / `@*Param`, FormRequest `queryParameters()` / `bodyParameters()`), then regenerate with:

```bash
docker exec -w /srv televisao-backend php artisan scribe:generate --force -n
```

  On a host-card stack, use that card’s backend container the same way (e.g. `hc-televisao-<slug>-backend-1`).

- Generated artifacts that land in git (typically `.scribe/`, `resources/views/scribe/`, `public/vendor/scribe/`) go in a **dedicated commit** that contains only Scribe output. Do not create an empty Scribe commit. Do not mix those paths with feature, test, or Pint commits.
- Annotations and FormRequest parameter helpers stay with the functional/docs-source commit; only the regenerate output is isolated.
- Colleague review: do **not** fail or nitpick the contents of those generated paths when they sit in that dedicated commit. Review the source annotations and the live contract instead. Missing regenerate / missing dedicated commit when the API contract changed is a defect.
- Do not invent OpenAPI/Blade/YAML by hand as a substitute for `scribe:generate`.

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
| `next prompt` | Open and **run** the next prompt this chat already recommended (path under `~/git/televisao/prompts/`). Do not wait for the user to paste that file. If none was recommended yet, say so and stop. **Exception — mutation stack:** refuse while changed `televisao-api` `*Test.php` files lack a done `mutation-ledger.md` row — tell the user to send `next mutation`. **Exception — coverage stack:** refuse while changed `app/**/*.php` files lack a done `coverage-ledger.md` row — tell the user to send `next coverage` or `correct coverages`. |
| `next mutation` | Opt-in one file during the personal mutation stack. Prefer default `correct mutations`. |
| `correct mutations` | **Default** personal mutation drain: every remaining changed `*Test.php` in this turn (sandbox + subagent per file when available). Opening `mutation-testing.md` with files remaining does this. |
| `next coverage` | Opt-in one file during the personal coverage stack. Prefer default `correct coverages`. |
| `correct coverages` | **Default** personal coverage drain: every remaining changed production file in this turn. Opening `coverage-testing.md` with files remaining does this. |
| `try again` | Resume or re-run the **current** prompt after a stop or manual fix. Continue from the blocked step when safe; otherwise restart that prompt’s procedure. Do not jump to another prompt. |
| `to correct` | Fix the latest corrective list in this chat: either **Needs code fixes** from `~/git/televisao/prompts/implementation-validation.md`, or **Tests to add** from `~/git/televisao/prompts/test-gap-analysis.md`. Implement those items only; then recommend `try again` on that same pass (re-run validation or gap analysis). Not board `correction.md` / 'Corrigir' unless the card is already in `changes-requested`. |
| `open televisao CODE` / `open PROJECT CODE` | **Funnel (`televisao` / `olie` / `locav`): CODE required** — omit → stop and ask; do not guess. **Single-unit** (`use-url-query`, `opbed`, `boilerplate-*`, `fabriciogferreira`): `open PROJECT` → `--code` = project name. With CODE: `~/git/bin/workvm-host-card open --project televisao --code <CODE>`. Ensure + focus/open the card `.code-workspace`. Syncs meta `worktree/git` to live `~/git` HEAD. Print `workspace=` / `api_worktree=`. |
| `finish card` / `finalize card` | **Local only:** `~/git/bin/workvm-host-card destroy --project televisao --code <CODE>` (compose/sandbox + fecha a janela Cursor + clones → branch base do `project.conf`). Do **not** ask about or move the board to concluído — that is a separate explicit request. |
| `resolva` | After a **prompt-health** stop: fix the blocker **in this session only**. Do not encode a permanent meta-repo solution. Then resume the interrupted prompt. |
| `documente` | After a **prompt-health** stop: write the problem into `~/git/HISTORICO.md` (and a short rule/prompt note if useful). Small local unblock if safe; if the real fix is too large for this card, **document only**. |
| `resolva permanentemente` | After a **prompt-health** stop: unblock now **and** leave a durable fix for the next card (`HISTORICO.md` + rule / workflow-policy / `bin`/`lib` / overlay as needed). |

When a prompt finishes and names a next paste, remember that path so `next prompt` can load it without a new paste.

## Tooling failures and stalls (prompt health)

If a request, MCP call, shell command, Docker/compose wait, git/gh, or other step **this prompt assumes will work** fails or takes unusually long — or the same **recurring** WorkVM/host-card friction burns time on every card — **stop**. Do not silently work around it or swap tools to hide the break. `olie-flow-ai` `needsAuth` is the **MCP auth** case above, not this stop. Host-card sandbox permission cluster: retry with `required_permissions: ["all"]` first.

Diagnose, then **wait** for `resolva` / `documente` / `resolva permanentemente` (table above). Do not pick the path yourself.

Report:

1. What you were doing
2. The objective error (status, short message) or that it hung past a reasonable wait
3. The most likely cause
4. Whether `~/git/HISTORICO.md` or an existing rule/prompt **already documents** this — cite it if so
5. The three commands and that you are waiting

Expected failures of the current task (e.g. testing an error path) can be reported and continued when that still makes sense.
