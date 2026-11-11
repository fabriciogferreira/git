# Colleague Card Review — dispatcher

Review card {{ code }} while it sits in 'QA/CR'. This paste is **only a dispatcher**: bootstrap shared context, launch the gate prompts **in parallel**, wait for every applicable gate, apply **Colleague review outcome**, then print one scoreboard.

This is a review of someone else's card, not preparation of your own (pre-QA). Do not implement the card in this paste.

If MCP (any configured server), requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: **stop this prompt**, report the objective error, and **ask the user to fix the broken tool** before continuing. Do not silently work around it, swap tools to hide the break, or keep reviewing. If the failure looks like a wrong assumption in this prompt (bad command or missing step), also say that **this prompt may need updating**. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy — do not call `mcp_auth` and do not ask the user to sign in again for that case only. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

Contract for parallel work: `~/git/olie/sandbox/ORCHESTRATION.md`. Shared outcome rules: **Colleague review outcome** in `~/git/olie/prompts/workflow-policy.md`.

## 1. Bootstrap (serial, once)

1. Load the card via MCP `olie-flow-ai` (details, owners, PRs/form links, funnel step). Confirm it is in 'QA/CR'.
2. Detect whether the change set touched `~/git/olie/api-main` (open PRs, form links, branch commits). That flag decides whether gap + mutation run.
3. On each company repository the card touches: find the author's branch, check it out (create from that repository's base — `develop` or `master` as it uses — only if missing). Do not rename; do not commit on it. Leave unrelated local changes untouched — stop if checkout would overwrite them.
4. Record `started_at` (UTC) for the scoreboard.
5. Do **not** write the colleague verdict, gap list, or mutation fixes yet — workers do that. Do **not** move the funnel or approve until §4.

## 2. Dispatch (parallel)

Open and **run** these prompts **at the same time** (Task / subagents / parallel tool batches). Pass the same card code `{{ code }}` and the shared bootstrap (project id, branches, backend yes/no). Do not wait for one gate to finish before starting another.

| Gate | Prompt | When |
| --- | --- | --- |
| Colleague core | `~/git/olie/prompts/colleague-review-core.md` | Always |
| Test gap analysis | `~/git/olie/prompts/test-gap-analysis.md` | Only if backend touched; else mark **skipped** |
| Mutation testing | `~/git/olie/prompts/mutation-testing.md` | Only if backend touched; else mark **skipped** |

Rules for workers:

- **Dispatcher mode** — each child prompt must follow its “launched by colleague-review dispatcher” section: no sequential `next prompt` / `next mutation` recommendations; return a structured result to this paste; mutation drains **all** remaining changed `api-main` `*Test.php` files in this run (ledger rows), not one file per paste.
- **Exclusive work (mutation / Pest) must use sandboxes** (`~/git/bin/workvm-sandbox create --project olie --profile mutation|tests`) — see `ORCHESTRATION.md`. Do **not** run `docker exec olie-api-main` Pest/mutation on the Card VM while gates are parallel (shared `testing` / `api_main`). Compatible work (core + gap analysis **without** Pest runtime) may stay on the Card VM.
- Workers must not checkout a different branch than bootstrap set, and must not apply the funnel move / approve.

If a worker tooling failure stops that gate, record it on the scoreboard as **failed/blocked** with the objective error; do not silently skip a required gate.

## 3. Wait and collect

Wait until every dispatched gate has finished (or is skipped). Collect:

- Colleague core: Pass / Fail (+ findings posted or not)
- Gap: No tests to add / Tests to add / Skipped / Blocked
- Mutation: Clean / Fixes reported / Skipped / Blocked (+ ledger summary)

## 4. Combined outcome

Apply **Colleague review outcome** in `~/git/olie/prompts/workflow-policy.md` **once**, after all applicable gates finished (or the user explicitly skips a remaining gate in chat).

- Move to 'Corrigir' only if at least one applicable gate failed (colleague fail **or** gap reported tests to add **or** mutation reported fixes for the author).
- Pass path (approve PRs via GitHub MCP `pull_request_review_write` event `APPROVE`; move to 'Validação') only if colleague passed **and** gap was skipped or clean **and** mutation was skipped or clean.
- Do **not** invent a third path.

Card notes stay findings-only — **Card content vs chat** in `workflow-policy.md` (never prompt paths, VMs, sandboxes, dispatcher/ledger jargon, or clean-gate process wrap-ups on the card).

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
| Payment / CAPTCHA | ok / N/A / blocked (from core when relevant) |
| PRs | approved / not approved / deferred reason |
| Funnel | stayed 'QA/CR' / moved 'Corrigir' / moved 'Validação' |
| Incidents | tooling failures, restarts, skips |

Also list checks that did **not** run and why.

Do not call the card ready for 'Validação' while any failed gate remains open.
