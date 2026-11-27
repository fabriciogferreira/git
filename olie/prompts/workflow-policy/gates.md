# Olie Workflow Policy — Gates & chat commands

Load this module for re-run budget, backend change-set, colleague outcome, and develop chat commands.

Index: `~/git/olie/prompts/workflow-policy.md`

## Expensive re-run budget

Do **not** repeat an expensive step when nothing material changed since the last run of that step in this chat (same code/asserts/env/deploy, same card diff).

| Expensive step | Re-run only when |
| --- | --- |
| `pest --mutate` / `pest --coverage` | Test or production blobs under test changed (`sha:` mismatch / missing stamp), or tooling was fixed; mutation also allows ≤1 re-mutate per `--class` after killable asserts (see mutation/coverage prompts). Matching `sha:` in the ledger → skip sandbox across chats. |
| Full Pest suite (`pest-parallel`) | A fix landed after a red suite, or the user sent `try again` after that fix. Full suite via `workvm-host-card-pest` (no `--ci` on artisan — unsupported; wrapper sets `PEST_TIA_LOCALLY=0` so TIA does not shrink). |
| Gap analysis / implementation-validation | Diff or requirements changed, or `try again` after `add` / `to correct`. |
| Colleague dispatcher gates | A gate was blocked/failed and the user asks to retry **that** gate — do not re-dispatch green gates “to confirm”. |
| Pre-QA checklist / production smoke | Code, PR, or production deploy changed; or a prior check failed and was fixed. |
| Correction verification | Re-check only what this correction changed — not the whole unrelated suite “for safety”. |

`try again` means “run again **after** a real change or unblock”, not “repeat the same measurement on an unchanged tree”.

## Pest TIA (local, meta only)

Do **not** edit `api-main` `tests/Pest.php` / `.gitignore` (company repo). Enable with `PEST_TIA_LOCALLY=1` on the **sandbox** slim compose + `git` in `olie/sandbox/Dockerfile.app`. **Regression** (`pest-parallel` / `workvm-host-card-pest`) must **not** pass `--ci` to `artisan test` (Laravel rejects it); the wrapper forces `PEST_TIA_LOCALLY=0` on exec for a full suite. Path-scoped / `--mutate` use `--no-tia` on `vendor/bin/pest` when needed.

## Backend change-set

**Default:** trust manager artifacts — **Gap** / **Coverage** / **Mutation** already resolve the change-set (`lib/coverage/score.py` `change_set_paths`: dirty + `develop...HEAD` + merge-parent / `--grep=<CODE>` fallback). Agent: read `app_files[]` / `tests[]` / score files from those artifacts. Do **not** re-derive the git recipe in chat when a fresh seed exists.

**Never** treat empty `develop...HEAD` alone as “no backend” when the card, PRs, or Caderno say `api-main` changed — re-run the manager gate (or ask the user to) instead of inventing a manual diff walk. Colleagues detecting backend touch: prefer Card Spec forms/PRs + Gap seed status over a three-dot empty check.

## Colleague review outcome

For a colleague card in 'QA/CR', the board move waits until **every** gate that applies has finished:

1. **Colleague review core** (`colleague-review-core.md`, launched by `colleague-review.md`) — pass or fail; write fail findings into the card content (OlieFlowAi).
2. **Test gap analysis** (`test-gap-analysis.md`) — when the change set touched `api-main`. User runs manager **Gap** (Card Spec required); agent only judges the seed. Skip when there is no backend. Report in Cursor chat only on this stack (own-card is also chat-only — see `test-gap-analysis.md`).
3. **Coverage testing** (`coverage-testing.md`) — only when the change set touched `api-main`. Skip when there is no backend. Report coverage-driven work in Cursor chat only.
4. **Mutation testing** (`mutation-testing.md`) — only when the change set touched `api-main`. Skip when there is no backend. Report mutation-driven work in Cursor chat only. **Re-run budget:** after one mutate report, classify in-scope survivors as killable vs `equivalent` immediately; re-mutate only after a real assert change (prefer ≤1 re-run per `--class`); never re-mutate an unchanged tree “to confirm”. Same rule in Locav/Televisão mutation prompts; coverage has a matching re-measure budget.

**Project content (gap / mutation / coverage):** do **not** write gap, mutation, or coverage results into the project/card while the reviewing user will fix them (**reviewer-fix**). Paste those three onto the card **only** when the combined outcome moves to 'Corrigir' because of a failure **outside** those gates (colleague core / product / acceptance) — so the author still sees the test debt alongside the bounce.

Own-card sequential order: Gap → Coverage → Mutation → Pest (manager) → agent `pre-qa.md` Phase A → manager **Pre-QA** → agent Phase B.

**Colleague coordinator:** user runs manager **Card Spec** (+ **Gap** / **Coverage** / **Mutation** / **Pest** when backend), then pastes `colleague-review.md`. Agent runs **core** (product review); optional gap from manager seed. Coverage/mutation/Pest/gap seed come from manager artifacts — the agent does **not** sandbox-drain measure gates in the colleague paste. Scoreboard + this outcome still apply. Own-card handoff: Gap → Coverage/Mutation/Pest (manager) → `pre-qa.md` Phase A → manager **Pre-QA** → Phase B. Sandbox contract for other exclusive work: `~/git/olie/sandbox/ORCHESTRATION.md`.

**Do not move to 'Corrigir' or 'Validação' until every applicable gate the dispatcher launched has finished** (or the user explicitly skips a remaining gate in chat). Do **not** approve PRs until the combined outcome below. Workers never move the funnel themselves.

**Move to 'Corrigir'** only after all applicable gates finished **and** the colleague core review failed (or any failure **outside** test-gap / mutation / coverage). Product/acceptance defects bounce to the author.

**Reviewer-fix path** — colleague core **Pass**, but test-gap and/or mutation and/or coverage reported work: leave the card in 'QA/CR'; do **not** move to 'Corrigir'; do **not** write gap/mutation/coverage into the project/card. The reviewing user may fix those gates in this chat (`add` / `to correct` / `correct mutations` / `correct coverages` / `try again` as applicable). When those gates are clean (or the user explicitly skips remaining work), apply the Pass path.

**Pass path** (approve PRs via GitHub MCP `pull_request_review_write` event `APPROVE`; move the card to the live funnel step 'Validação'): only when the colleague review passed **and** gap analysis was skipped or clean **and** mutation either was skipped (no backend) or finished without fixes to send back **and** coverage either was skipped (no backend) or finished without fixes to send back.

### Return from production / merged bounce (colleague)

A card in 'QA/CR' (or back from 'Corrigir') is **not** always a first colleague pass. Rebuild its funnel path from Card Spec **`media.md`** (system logs) plus forms/metrics in `project.md` — not a live MCP media re-list.

Treat the card as a **production return** when any of these hold:

- System logs show it already visited **Validação**, **Revisão produção**, and/or **Concluído**, then later **Corrigir** and/or **QA/CR** again.
- Deploy log / merge messages / closed-merged PRs show the change already shipped.
- Metrics such as “Quantas vezes voltou para correção” ≥ 1, or user/reviewer media posted **after** deploy describing the defect still present.

On a production return:

- The open question is whether the **shipped** fix failed (or a new regression appeared), not whether a green host-card happy path matches the original write-up alone.
- Prioritize post-deploy evidence (videos, comments, logs after merge/deploy) over first-pass acceptance text.
- An author note that they “could not reproduce” is a request for the reviewer to try the bounce scenario — **not** a Pass.
- Host-card / local success does **not** override unrebutted production evidence that the defect still occurs. Fail (or stay blocked with an honest reproduction attempt) until that conflict is resolved.
- Scoreboard and core return must state **bounce: yes/no**, the reconstructed step path, and which post-deploy media drove the verdict.

Detail for workers: **Production return** in `colleague-review-core.md`; dispatcher bootstrap classifies bounce before dispatch.

## Chat commands (develop handoff)

Exact phrases from the user in this chat (match case-insensitively after trim). Not the same as controlled-mode checklist `next` inside `implementation.md` / `correction.md` (those prompts: **Plan mode** before creating the plan, then `next` per checklist item).

| Command | Meaning |
| --- | --- |
| `next prompt` | Open and **run** the next prompt this chat already recommended (path under `~/git/olie/prompts/`). Do not wait for the user to paste that file. If none was recommended yet, say so and stop. **Exception — coverage / mutation / Pest:** if the latest manager artifact for that gate is `needs_work` / missing while backend changed, **refuse** `next prompt`. Tell the user to run **Coverage** / **Mutation** / **Pest** in `manager.sh` as applicable. |
| `next mutation` / `correct mutations` | User runs **Mutation** in `~/git/manager.sh` (full change-set measure → `latest.json`). Agent only reads the artifact and implements `agent_action` gaps — see `mutation-testing.md` / `lib/mutation/ARTIFACT.md`. Not `to correct`. |
| `next coverage` / `correct coverages` | User runs **Coverage** in `~/git/manager.sh` (full change-set measure → `latest.json`). Agent only reads the artifact and implements `agent_action` gaps — see `coverage-testing.md` / `lib/coverage/ARTIFACT.md`. |
| `try again` | Resume or re-run the **current** prompt after a stop or manual fix. Continue from the blocked step when safe; otherwise restart that prompt’s procedure. Do not jump to another prompt. |
| `add` | After **Tests to add** from `~/git/olie/prompts/test-gap-analysis.md`: implement every listed missing test (title + description from that report) only. Do not open coverage / mutation / Pest parallel / pre-QA in the same turn. When done, recommend `try again` (user re-runs manager **Gap**, agent re-reads seed). Not for validation **Needs code fixes** (`to correct`) and not `correct mutations`. |
| `to correct` | Fix the latest corrective list in this chat: **Needs code fixes** from `~/git/olie/prompts/implementation-validation.md`, or failures from the manager Pest artifact (`latest.json`). Implement those items only; then the user re-runs **Pest** in the manager. For gap **Tests to add**, use `add` instead. Not board `correction.md` / 'corrigir' unless the card is already in `changes-requested`. Not `correct mutations`. |
| `open olie CODE` / `open PROJECT CODE` | **Funnel cards (`olie` / `locav` / `televisao`): CODE required.** If the user says only `open olie` (no card code), **stop and ask** — do not guess (last card, only on `list`). Optional: `workvm-host-card list`. With CODE: `~/git/bin/workvm-host-card open --project olie --code <CODE>`. **Single-unit** (`use-url-query`, `opbed`, `boilerplate-laravel`, `boilerplate-next`, `fabriciogferreira`): no `{{ code }}` — `open use-url-query` → `--project` and `--code` both the project name. Ensure + **open/focus** the card `.code-workspace` (product worktrees, not shared clones). Syncs card meta `worktree/git` to live `~/git` HEAD. Print `workspace=` and `api_worktree=`. Olie: first open infers `stack_groups` (`back`=app; `front`=http+front-management+olie-e2e; front→back) from olie-fronts branches matching CODE (default `back`) and persists; reopen reuses. Override: `--groups` / `WORKVM_HOST_CARD_GROUPS`. |
| `add front` / `add back` (Olie host-card) | `~/git/bin/workvm-host-card add --project olie --code <CODE> --group front` (or `back`). Merges into meta `stack_groups` and re-ensure — use when a back-only card later needs browser/e2e. **Playwright MCP** only registers when `front` is in `stack_groups` (olie-e2e). **PrimeVue MCP** uses `workvm-primevue-mcp.sh` (repairs broken mise `npx` after Cursor reinstall). |
| `finish card` / `finalize card` | **Local only:** (1) `~/git/bin/workvm-host-card destroy --project olie --code <CODE>` (card compose + clones → branch base do `project.conf`, ex. `develop`); (2) **then** stop the **main** project compose (`docker compose -f ~/git/olie/docker-compose.yml down` — see **Destroy**). Does **not** close Cursor; does **not** tear down `hc-olie-data` / other cards. After both succeed, tell the user they can close the card window manually. Do **not** ask about or move the board to 'concluído'. Do not destroy other cards. |
| `colleague review CODE` | Load `~/git/olie/prompts/colleague-review.md`, substitute `CODE` for `{{ code }}` **in memory only**, run the dispatcher. Do not edit or save the prompt file. |
| `run prompt NAME CODE` | Same for `~/git/olie/prompts/<NAME>.md` (with or without `.md`). Substitute in memory; never write the template. |
| `resolva` | After a **prompt-health** stop: fix the blocker **in this session only** (local/env/compose). Do not encode a permanent meta-repo solution. Then resume the interrupted prompt. |
| `documente` | After a **prompt-health** stop: write the problem into `~/git/HISTORICO.md` (and a short rule/prompt note if useful) as a known issue / workaround. Apply a small local unblock if safe; if the real fix is too large for this card, **document only** and stop after writing. |
| `resolva permanentemente` | After a **prompt-health** stop: unblock now **and** leave a durable fix so the **next card** does not rediscover it — `HISTORICO.md` (`problema` / `por que é um problema` / `resolvido como`) plus the right artifact (`.cursor/rules`, this workflow-policy, `bin/`/`lib/`, overlay, etc.). Prefer rule/script over prose-only when the failure is mechanical. |

When a prompt finishes and names a next paste, remember that path so `next prompt` can load it without a new paste. While Coverage / Mutation / Pest `latest.json` is `needs_work`, the continue path is: user re-runs that action in the manager (+ agent implements `agent_action`s), not `next prompt`. Own-card develop handoff order: Gap → Coverage → Mutation → Pest (manager) → `pre-qa.md` Phase A → manager **Pre-QA** → Phase B.
