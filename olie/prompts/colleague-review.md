# Colleague Card Review — dispatcher

Review card {{ code }} while it sits in 'QA/CR'. This paste is **only a dispatcher**: bootstrap shared context, launch the gate prompts **in parallel**, wait for every applicable gate, apply **Colleague review outcome**, then print one scoreboard.

This is a review of someone else's card, not preparation of your own (pre-QA). Do not implement the card in this paste.

If MCP (any configured server), requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: **stop this prompt**, report the objective error, and **ask the user to fix the broken tool** before continuing. Do not silently work around it, swap tools to hide the break, or keep reviewing. If the failure looks like a wrong assumption in this prompt (bad command or missing step), also say that **this prompt may need updating**. Exceptions: (1) `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** — do not call `mcp_auth` and do not ask the user to sign in again. (2) **Host-card sandbox cluster** (`Permission denied` on `~/.cursor/mcp.json`, fake DNS/`gh`/`docker.sock` failures) — follow **Shell permissions** under **Host card environment** in `~/git/olie/prompts/workflow-policy.md` (first call with `all`; approval card if Auto-review blocks). Do **not** treat that cluster as a broken host or ask for chmod/DNS/`gh auth` until unrestricted ensure has actually failed.

Contract for parallel work: `~/git/olie/sandbox/ORCHESTRATION.md`. Shared outcome rules: **Colleague review outcome** in `~/git/olie/prompts/workflow-policy.md`.

## 1. Bootstrap (serial, once)

0. **Host card environment** — `~/git/bin/workvm-host-card ensure --project olie --code '{{ code }}'` (**Host card environment** in `workflow-policy.md`). Resume if the unit already exists. Do **not** destroy when this dispatcher ends (card stays in QA/CR, Validação, or Corrigir).
1. Load the card via MCP `olie-flow-ai` (details, owners, PRs/form links, funnel step). Confirm it is in 'QA/CR'. Also read every project thread and the latest version of each one (**Reading the project notebook** in `~/git/olie/prompts/workflow-policy.md`). The card's requirements, acceptance criteria, and those notebook page texts are the source of truth — pass that context to the workers. A change that works but does not match the card is not a pass.
2. Detect whether the change set touched `~/git/olie/api-main` (open PRs, form links, branch commits). That flag decides whether gap + mutation + coverage run.
3. On each company repository the card touches: find the author's branch, check it out (create from that repository's base — `develop` or `master` as it uses — only if missing). Do not rename; do not commit on it. Leave unrelated local changes untouched — stop if checkout would overwrite them.
4. Record `started_at` (UTC) for the scoreboard.
5. Do **not** write the colleague verdict, gap list, or mutation/coverage fixes yet — core writes product fail findings; gap/mutation/coverage stay in chat until §4. Do **not** move the funnel or approve until §4.

## 2. Dispatch (parallel)

Open and **run** these prompts **at the same time** (Task / subagents / parallel tool batches). Pass the same card code `{{ code }}` and the shared bootstrap (project id, branches, backend yes/no). Do not wait for one gate to finish before starting another.

| Gate | Prompt | When |
| --- | --- | --- |
| Colleague core | `~/git/olie/prompts/colleague-review-core.md` | Always |
| Test gap analysis | `~/git/olie/prompts/test-gap-analysis.md` | Only if backend touched; else mark **skipped** |
| Mutation testing | `~/git/olie/prompts/mutation-testing.md` | Only if backend touched; else mark **skipped** |
| Coverage testing | `~/git/olie/prompts/coverage-testing.md` | Only if backend touched; else mark **skipped** |

Rules for workers:

- **Dispatcher mode** — each child prompt must follow its “launched by colleague-review dispatcher” section: no sequential `next prompt` / `next mutation` / `next coverage` recommendations; return a structured result to this paste; mutation drains **all** remaining changed `api-main` `*Test.php` files in this run (ledger rows), not one file per paste; coverage drains **all** remaining changed `app/**/*.php` files (ledger rows) in this run.
- **Exclusive work (mutation / coverage / Pest) must use sandboxes** (`~/git/bin/workvm-sandbox create --project olie --profile mutation|tests --from-commit <card api-main tip>`) — see `ORCHESTRATION.md`. Bootstrap (or each worker) resolves the tip from the host-card worktree; **never** bare create. Do **not** run `docker exec olie-api-main` Pest/mutation/coverage on the shared stack while gates are parallel (shared `testing` / `api_main`). Compatible work (core + gap analysis **without** Pest runtime) may stay on the host card unit.
- Workers must not checkout a different branch than bootstrap set, and must not apply the funnel move / approve.

If a worker tooling failure stops that gate, record it on the scoreboard as **failed/blocked** with the objective error; do not silently skip a required gate.

## 3. Wait and collect

**Re-run budget:** after this scoreboard is complete, do **not** re-dispatch gates that already returned Clean/Pass on an unchanged tree “to confirm”. Retry only a blocked/failed gate when the user asks (or after a real unblock). Shared rule: **Expensive re-run budget** in `workflow-policy.md`.

Wait until every dispatched gate has finished (or is skipped). Collect:

- Colleague core: Pass / Fail (+ findings posted or not)
- Gap: No tests to add / Tests to add / Skipped / Blocked
- Mutation: Clean / Fixes reported / Skipped / Blocked (+ ledger summary)
- Coverage: Clean / Fixes reported / Skipped / Blocked (+ ledger summary)

## 4. Combined outcome

Apply **Colleague review outcome** in `~/git/olie/prompts/workflow-policy.md` **once**, after all applicable gates finished (or the user explicitly skips a remaining gate in chat).

- Move to 'Corrigir' only if colleague core failed (or any failure **outside** test-gap / mutation / coverage).
- **Reviewer-fix path:** colleague core Pass but gap and/or mutation and/or coverage reported work → stay in 'QA/CR'; do **not** move to 'Corrigir'; do **not** write gap/mutation/coverage into the project/card; the reviewing user may fix those gates in this chat. Apply Pass path only after they are clean (or explicitly skipped).
- When moving to 'Corrigir' for a core (or other non-test-gate) fail, **then** also paste any open gap/mutation/coverage findings onto the card for the author.
- Pass path (approve PRs via GitHub MCP `pull_request_review_write` event `APPROVE`; move to 'Validação') only if colleague passed **and** gap was skipped or clean **and** mutation was skipped or clean **and** coverage was skipped or clean.
- Do **not** invent another path beyond Corrigir / reviewer-fix / Pass.

Card notes stay findings-only — **Card content vs chat** in `workflow-policy.md` (never prompt paths, VMs, sandboxes, dispatcher/ledger jargon, or clean-gate process wrap-ups on the card). Never post gap/mutation/coverage process wrap-ups on a Pass or reviewer-fix card.

## 5. Scoreboard (required final report)

Print one table (or equivalent bullets) covering **everything that ran**. Include timing when you have it.

| Field | Content |
| --- | --- |
| Card | {{ code }} |
| Owner(s) | 'atribuído a' |
| Started / ended (UTC) | timestamps |
| Duration | wall-clock |
| Backend touched | yes / no |
| Gates run | core + gap? + mutation? + coverage? |
| Colleague core | Pass / Fail — short reason |
| Gap analysis | No tests to add / N titles / Skipped / Blocked |
| Mutation | Clean / fixes / Skipped / Blocked — files in ledger |
| Coverage | Clean / fixes / Skipped / Blocked — files in ledger |
| Contrast | light/dark result (from core) |
| E2E | added/extended commit, or N/A / blocked |
| Payment / CAPTCHA | ok / N/A / blocked (from core when relevant) |
| PRs | approved / not approved / deferred reason |
| Funnel | stayed 'QA/CR' (reviewer-fix) / moved 'Corrigir' / moved 'Validação' |
| Incidents | tooling failures, restarts, skips |

Also list checks that did **not** run and why.

Do not call the card ready for 'Validação' while any failed gate remains open.
