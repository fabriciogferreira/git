# Mutation testing (personal)

Use this when the card changed `~/git/televisao/televisao-api`. Skip entirely when the change set has no backend.

Three entry points:

1. **Own card (develop handoff)** — after `~/git/televisao/prompts/coverage-testing.md` (which follows gap when backend changed). **Default:** drain every remaining changed `*Test.php` in this paste (`correct mutations` / parallel sandboxes). Use **`next mutation`** only when the user asks for one file. When finished (or the user stops), next is `~/git/televisao/prompts/pest-parallel.md`, then `pre-qa.md`.
2. **Colleague card via dispatcher** — launched **in parallel** by `~/git/televisao/prompts/colleague-review.md` with `colleague-review-core.md`, `test-gap-analysis.md`, and `coverage-testing.md`. **Dispatcher mode:** drain **every** remaining changed `*Test.php` in this run (sandbox shard per `ORCHESTRATION.md`). Do **not** stop after one file. Do **not** recommend `next mutation` / `next prompt`. Do **not** apply the funnel move — return Pass/Fixes/Blocked to the dispatcher; it applies **Colleague review outcome**.
3. **Colleague card pasted alone** — same default as own-card (parallel drain); **`next mutation`** only if the user asks for one file; when none remain, tell the user to paste `colleague-review.md` (or finish the dispatcher they already started) so the combined outcome runs. Do not move 'Corrigir' / 'Revisado' yourself when the dispatcher owns the card.

Chat commands: `~/git/televisao/prompts/workflow-policy.md` → **Chat commands** (`correct mutations` default; `next mutation` opt-in).

**Own-card / alone:** default = **`correct mutations`** (all remaining files this turn). **`next mutation`** = one file only when asked. **Colleague dispatcher:** all remaining files in this run (sandbox shard when available — `~/git/televisao/sandbox/ORCHESTRATION.md`).

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/televisao/prompts/workflow-policy.md`.

Personal workflow on this VM. Run it only when `televisao-backend` already has Pest and `pest-plugin-mutate`. If either is missing, stop. Do not install them and do not bump PHP to match another product.

Do not add mutation testing to CI, `phpunit.xml`, Dockerfiles, or compose. Do not commit `covers()` or `mutates()` into company tests. Do not open a pull request whose purpose is mutation testing. Converting the one file below to Pest, and assertion edits that make a mutation fail, are normal test changes in `~/git/televisao/televisao-api`; do not commit or push them unless the user asks in this chat.

**Scope is the user’s local diff, plus a small legacy bonus.** Never walk the whole `tests/` tree. Never use `--everything` (it mutates every covered line the test touches — middleware, models, framework path — and is too slow for this repo).

## Ledger

Progress lives only in `~/git/televisao/prompts/mutation-ledger.md` (meta-repo). Create that file if it is missing, with a table:

| Test file | Result | Notes |
| --- | --- | --- |
| `tests/...` | `100%` or `equivalent` | `sha:<fp>`; `--class` targets; +1 legacy |

A row is done when Result is `100%` or `equivalent` for **in-scope** mutations (see below). `equivalent` means every remaining in-scope untested mutation is a behavior-preserving change (for example a cast the tests already feed as a float) and the Notes column says why. Do not mark a file done to skip a real in-scope gap.

**Cross-chat skip (file@blob):** when closing a row, stamp Notes with `sha:<fingerprint>` from `~/git/bin/workvm-ledger-sha.sh <televisao-api> <test-path> <each --class production path>`. Later chats / dispatcher skip that test (no sandbox/mutate) when Result is done **and** `sha:` still matches. Done row with **no** `sha:` → re-run once and stamp.

## Change-set file list (shared)

Work only in `~/git/televisao/televisao-api`.

1. List changed paths (staged + unstaged + untracked):

   `git status --short` and `git diff --name-only HEAD` plus untracked files.

2. From that list, keep `*Test.php` under `tests/`. Sort by path. Skip a path only when its ledger row is done **and** its `sha:` fingerprint still matches (`workvm-ledger-sha.sh` on the test + `--class` production paths). Path-only skip without `sha:` is not enough across chats. Skip a file that is a trait or helper and not a test case.
3. Collect production PHP classes from the same change set (`app/**/*.php` added or modified). Map each path to its FQCN (PSR-4 `App\` ← `app/`). Those are the mutation `--class` targets.
4. Compute **in-scope line ranges** per changed `app/` file via `git diff -U0 HEAD -- <path>` (added/modified hunks only). New files: the whole file is in-scope.

If the change set has test files but **no** `app/` PHP changes, stop and say there is nothing to mutate (do not fall back to full-project or `--everything`).

## One changed test file / `next mutation`

Opt-in one-file path (user asked for `next mutation`).

1. Take the first remaining changed test file from the shared list (or the path the user named).
2. If none remain: **dispatcher mode** → return clean/complete to the dispatcher and stop. **Own-card** → say the change-set mutation stack is complete, recommend `~/git/televisao/prompts/pest-parallel.md`, and stop. **Alone on colleague stack** → say complete and tell the user to use `colleague-review.md`.
3. If that file is still a PHPUnit test case (`extends TestCase`) and Drift is already installed, convert **that file only** before mutating: `docker exec -w /srv televisao-backend vendor/bin/pest --drift <that-file>`. Do not pass `tests/`. If Drift is missing, stop and report. Do not install it.
4. Prepare, mutate the change-set `--class` targets, close the file. **Own-card / alone (`next mutation`):** stop — do not start the next file. **Dispatcher mode:** continue with the next remaining file (or sandbox shard).

## `correct mutations` (parallel drain)

**Default** for own-card / alone when this prompt opens (or the user sends `correct mutations`).

1. Build the remaining-file list (shared steps 1–2). If empty, say complete and recommend `pest-parallel.md`.
2. Parent orchestrates — do not serialize every file in one giant context when more than one remains.
3. For each remaining file, in parallel (respect `WORKVM_SANDBOX_MAX` — `~/git/televisao/sandbox/ORCHESTRATION.md`):
   - Create `~/git/bin/workvm-sandbox create --name <unique> --project televisao --profile mutation` when available; else `docker exec -w /srv televisao-backend` (own-card fallback only).
   - Sync dirty `televisao-api` into the sandbox worktree when needed.
   - One subagent (Task) per file (Drift that file if still PHPUnit; mutate; propose ledger row). Subagent must **not** write `mutation-ledger.md`.
4. Parent only appends ledger rows; destroy each sandbox when the row is accepted.
5. When every remaining file has a done row (or the user stops), report the aggregate; if complete, recommend `pest-parallel.md`.

## Prepare

All PHP runs as `docker exec -w /srv televisao-backend <command>`. Do not run `php` on the host.

- If `vendor/bin/pest` is missing inside the container, run `composer install` once. If it is still missing, stop. Do not install Pest.

- If `vendor/pest-plugins.json` is missing inside the container: `composer pest:dump-plugins`.
- If `php -m` does not list `pcov`: install it in the running container only (`pecl install pcov` and `docker-php-ext-enable pcov` as root). Say that a recreated image drops PCOV. Do not change the image or compose files.

Run the chosen file with the normal suite first:

`docker exec -w /srv televisao-backend php artisan test --compact <test-path>`

If that fails, stop. Do not mutate a red file.

## Mutate

Pass changed production FQCNs via `--class=...`. Prefer **one `--class` per mutate run** when a prior multi-`--class` run produced `0 Mutations for 0 Files` (Pest quirk). Do **not** use `--everything`.

Example (escape `\` for the shell):

```bash
docker exec -w /srv televisao-backend vendor/bin/pest --mutate --covered-only --min=100 --ignore-min-score-on-zero-mutations \
  --class=App\\Services\\Example\\ExampleAction \
  <test-path>
```

- `--class` scopes the run (replaces needing committed `covers()` / `mutates()`).
- `--covered-only` keeps mutations on lines this test run executes inside those classes.
- `--ignore-min-score-on-zero-mutations` treats nothing-to-mutate as success.
- Pest may still emit mutations on **pre-existing** lines in a large modified class. That is expected. Split the report into **in-scope** (diff hunks) vs **out-of-scope** (everything else).

### Optional local-only `mutates()`

If `--class` fails for this Pest build, temporarily add `mutates(ChangedClass::class);` for each changed class at the top of the test file and run without `--everything`. Remove those lines before finishing the paste. Never leave them staged or committed.

## Close the file

### In-scope (required)

- Score **in-scope** mutations only (line numbers inside the diff hunks for that class).
- In-scope all tested, or zero in-scope mutations: append a `100%` row (notes: `no mutations` when zero; otherwise list classes + “in-scope only”).
- In-scope untested: tighten assertions in that test file so the mutated behavior fails. Re-run mutate. Do not change production code to satisfy a mutation. If a mutation shows a real product bug, stop and report it.
- In-scope untested that does not change behavior: record `equivalent` and name the mutation id and why. Do not invent an assertion that cannot fail.

### Re-run budget (wall-clock)

Re-running `pest --mutate` without new killable asserts (or without accepting `equivalent`) only repeats the same score. That burns minutes per file for zero ledger progress.

- After **one** mutate report for a `--class` / file: split in-scope survivors into **killable** vs **equivalent** immediately.
- Re-run mutate **only** after you changed the test to kill at least one killable in-scope mutant (or after a tooling fix). Cap: prefer **at most one** re-run per `--class` once killables are addressed; then close with `equivalent` for any remaining behavior-preserving ids.
- Do **not** re-mutate “to confirm” an unchanged tree, to climb Pest’s class-wide `%`, or to re-check mutants you already marked `equivalent`.
- Do **not** invent asserts that cannot fail just to avoid `equivalent`.

Pest’s overall `%` on a fat class may stay below 100%. That is OK. Ledger Result reflects **in-scope**, not Pest’s class-wide score. Put Pest’s raw score in Notes when it differs.

### +1 legacy (optional, once per paste)

After in-scope is done, you may pick **exactly one** out-of-scope untested mutation (prefer same class/file, cheap assertion) and tighten the test so it becomes tested. Do not chase more legacy mutations in the same paste. Note the chosen mutation id in the ledger Notes (`+1 legacy: …`).

Skip +1 if there are no useful out-of-scope untested mutations, or if fixing one would require a large unrelated suite.

- If you added temporary `covers()` / `mutates()`, remove them before writing the ledger row.

After the row is written, report the file, whether it was converted from PHPUnit in this paste, in-scope result, Pest raw score if different, any +1 legacy fix, and how many **changed** test files are still absent from the ledger.

- **Dispatcher mode:** if changed test files remain, continue with the next file in this same run (or the next sandbox shard). Do not ask for another paste.
- **Own-card / alone:** if changed test files remain, say to paste this prompt again (or `next mutation`) for the next file.

When **none** remain:

- **Dispatcher mode:** if mutation reported fixes, write them into the card content (findings only — **Card content vs chat** in `workflow-policy.md`; no prompt paths). Return the aggregate result to `colleague-review.md`. Do **not** apply the funnel move yourself.
- **Develop handoff** (came from coverage-testing): recommend `~/git/televisao/prompts/pest-parallel.md` as the next paste; `pre-qa.md` after a green suite.
- **Alone on colleague stack:** write mutation fixes to the card if any; tell the user to paste `colleague-review.md` for **Colleague review outcome** (do not move the funnel here).
