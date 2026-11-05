# Colleague Card Review — dispatcher

Review card {{ code }} while it sits in 'QA/CR'. This paste is **only a dispatcher**: bootstrap shared context, launch the gate prompts **in parallel**, wait for every applicable gate, apply **Colleague review outcome**, then print one scoreboard.

This is a review of someone else's card, not preparation of your own (pre-QA). Do not implement the card in this paste.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/televisao/prompts/workflow-policy.md`.

Contract for parallel work: `~/git/televisao/sandbox/ORCHESTRATION.md`. Shared outcome rules: **Colleague review outcome** in `~/git/televisao/prompts/workflow-policy.md`.

## 1. Bootstrap (serial, once)

1. Load the card via MCP `olie-flow-ai` (details, owners, PRs/form links, funnel step). Confirm it is in 'QA/CR'.
2. Detect whether the change set touched `~/git/televisao/televisao-api` (open PRs, form links, branch commits). That flag decides whether gap + mutation run.
3. On each company repository the card touches: find the author's branch, check it out (create the name from **Card branch name** in `workflow-policy.md` + base `preview` in `project.md` only if missing). Do not rename; do not commit on it. Leave unrelated local changes untouched — stop if checkout would overwrite them.
4. Record `started_at` (UTC) for the scoreboard.
5. Do **not** write the colleague verdict, gap list, or mutation fixes yet — workers do that. Do **not** move the funnel or approve/merge until §4.

## 2. Dispatch (parallel)

Open and **run** these prompts **at the same time** (Task / subagents / parallel tool batches). Pass the same card code `{{ code }}` and the shared bootstrap (project id, branches, backend yes/no). Do not wait for one gate to finish before starting another.

| Gate | Prompt | When |
| --- | --- | --- |
| Colleague core | `~/git/televisao/prompts/colleague-review-core.md` | Always |
| Test gap analysis | `~/git/televisao/prompts/test-gap-analysis.md` | Only if backend touched; else mark **skipped** |
| Mutation testing | `~/git/televisao/prompts/mutation-testing.md` | Only if backend touched; else mark **skipped** |

Rules for workers:

- **Dispatcher mode** — each child prompt must follow its “launched by colleague-review dispatcher” section: no sequential `next prompt` / `next mutation` recommendations; return a structured result to this paste; mutation drains **all** remaining changed `*Test.php` files in this run (ledger rows), not one file per paste.
- Prefer sandboxes (`~/git/bin/workvm-sandbox`) for exclusive mutation shards when available — see `ORCHESTRATION.md`. Compatible work (core + gap) may stay on the Card VM.
- Workers must not checkout a different branch than bootstrap set, and must not apply the funnel move / approve / merge.

If a worker tooling failure stops that gate, record it on the scoreboard as **failed/blocked** with the objective error; do not silently skip a required gate.

## 3. Wait and collect

Wait until every dispatched gate has finished (or is skipped). Collect:

- Colleague core: Pass / Fail (+ findings posted or not)
- Gap: No tests to add / Tests to add / Skipped / Blocked
- Mutation: Clean / Fixes reported / Skipped / Blocked (+ ledger summary)

## 4. Combined outcome

Apply **Colleague review outcome** in `~/git/televisao/prompts/workflow-policy.md` **once**, after all applicable gates finished (or the user explicitly skips a remaining gate in chat).

- Move to 'Corrigir' only if at least one applicable gate failed (colleague fail **or** gap reported tests to add **or** mutation reported fixes for the author).
- Pass path (approve / merge / 'Revisado') only if colleague passed **and** gap was skipped or clean **and** mutation was skipped or clean.
- Resolve 'Revisado' (and any step id) only via MCP `index-project-funnels-tool` → that board's `funnel_status[]` / `steps[]` by display name, then `edit-project-tool` / move tools. **Do not** call `get-available-steps` or curl the management catalog while that MCP tool works — empty `search`/`id` result means retry unfiltered, not HTTP. See **Resolving funnel steps** in `workflow-policy.md`.
- Do **not** invent a third path.

Card notes stay findings-only — **Card content vs chat** in `workflow-policy.md` (never prompt paths on the card).

## 5. Scoreboard (required final report)

Print one table (or equivalent bullets) covering **everything that ran**. Include timing when you have it.

| Field | Content |
| --- | --- |
| Card | {{ code }} |
| Owner(s) | 'atribuído a' |
| Started / ended (UTC) | timestamps |
| Duration | wall-clock |
| Backend touched | yes / no |
| Gates run | core + gap? + mutation? |
| Colleague core | Pass / Fail — short reason |
| Gap analysis | No tests to add / N titles / Skipped / Blocked |
| Mutation | Clean / fixes / Skipped / Blocked — files in ledger |
| Contrast | light/dark result (from core) |
| E2E | added/extended commit, or N/A / blocked |
| Pest on edited API tests | ok / fail file / N/A |
| PRs | approved+merged / not approved / deferred reason |
| Funnel | stayed 'QA/CR' / moved 'Corrigir' / status 'Revisado' |
| Incidents | tooling failures, restarts, skips |

Also list checks that did **not** run and why.

Do not call the card ready for 'Validação' while any failed gate remains open.
