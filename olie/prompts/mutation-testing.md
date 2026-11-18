# Mutation testing (personal)

Use this when the card changed `~/git/olie/api-main`. Skip entirely when the change set has no backend.

Three entry points:

1. **Own card (develop handoff)** — after `~/git/olie/prompts/coverage-testing.md` (which follows gap analysis when backend changed). **Default:** drain every remaining changed `*Test.php` in this paste (`correct mutations` / parallel sandboxes). Use **`next mutation`** only when the user asks for one file. When this mutation stack is finished (or the user stops), the next recommended prompt is `~/git/olie/prompts/pest-parallel.md` (`next prompt` runs it) — then `pre-qa.md` after a green suite.
2. **Colleague card via dispatcher** — launched **in parallel** by `~/git/olie/prompts/colleague-review.md` with `colleague-review-core.md` and `test-gap-analysis.md`. **Dispatcher mode:** drain **every** remaining changed `*Test.php` in this run. **Must** shard via `~/git/bin/workvm-sandbox create --project olie --profile mutation --from-commit <card api-main tip>` using a **warm pool** (`N = min(remaining, 4)`, or `2` if RAM is tight) — see `~/git/olie/sandbox/ORCHESTRATION.md`. Do **not** run baseline Pest or `pest --mutate` with `docker exec olie-api-main` (that is the Card VM DB). Do **not** stop after one file. Do **not** recommend `next mutation` / `correct mutations` / `next prompt`. Do **not** apply the funnel move — return Pass/Fixes/Blocked to the dispatcher; it applies **Colleague review outcome**.
3. **Colleague card pasted alone** — same default as own-card (parallel drain); **`next mutation`** only if the user asks for one file; when none remain, tell the user to paste `colleague-review.md` (or finish the dispatcher they already started) so the combined outcome runs. Do not move 'Corrigir' / 'Validação' yourself when the dispatcher owns the card.

**Stack gate (develop handoff / alone):** while any changed `*Test.php` under `tests/` is still missing from the ledger (or has no `100%` / `equivalent` row), this stack is **incomplete**. Do **not** recommend or run `~/git/olie/prompts/pest-parallel.md` or `~/git/olie/prompts/pre-qa.md`. Do **not** treat `next prompt` as permission to leave mutation early. Only when every remaining file is closed (or the user explicitly stops / skips the personal stack) may you recommend `pest-parallel.md`.

Chat commands: `~/git/olie/prompts/workflow-policy.md` → **Chat commands** (includes `next mutation` and `correct mutations`).

**Own-card / alone:** default = **`correct mutations`** (drain **all** remaining change-set test files in this turn — sandbox + subagent per file). **`next mutation`** = one file only when the user asks. Prefer `workvm-sandbox` `--project olie --profile mutation` so Card VM `testing` stays untouched. **Colleague dispatcher:** all remaining files in this run, **required** sandbox shards (`~/git/olie/sandbox/ORCHESTRATION.md`) — same drain shape as `correct mutations`, without the chat command.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

Personal workflow on this VM. Pest mutation testing is not an Olie team practice. Do not add it to `api-main` CI, `phpunit.xml`, Dockerfiles, `docker-workspace`, or Composer. Do not commit `covers()` or `mutates()` into company tests. Do not open a pull request whose purpose is mutation testing. Assertion edits that make a mutation fail are normal test changes in `~/git/olie/api-main`; do not commit or push them unless the user asks in this chat.

**Scope is the user’s local diff, plus a small legacy bonus.** Never walk the whole `tests/` tree. Never use `--everything` (it mutates every covered line the test touches — middleware, models, framework path — and is too slow for this repo).

### Chat commands (this stack)

| Command | Do this |
| --- | --- |
| `next mutation` | Opt-in: one changed `*Test.php` only. Prefer the default parallel drain. Do not open `pest-parallel.md` or `pre-qa.md`. |
| `correct mutations` | **Default own-card / alone drain** (also what opening this prompt does when files remain): process **every** remaining changed `*Test.php` in this turn. Warm sandbox pool + one subagent per **in-flight** file; parent orchestrates. Not `to correct`. Do not open `pest-parallel.md` / `pre-qa.md` until the drain finishes. Details below. |
| `next prompt` | **Blocked** while the change-set stack still has remaining test files. Refuse, list how many files remain (and the next path), and tell the user to send `next mutation` or `correct mutations`. Only after the stack is complete may `next prompt` run `~/git/olie/prompts/pest-parallel.md`. |
| `try again` | Resume or re-run mutation on the **current** (last attempted) test file after a stop or fix. Do not skip ahead to another file or to pre-QA. After a failed `correct mutations` shard, retry that file (or re-send `correct mutations` for all still-missing rows). |

## Ledger

Progress lives only in `~/git/olie/prompts/mutation-ledger.md` (meta-repo). Create that file if it is missing, with a table:

| Test file | Result | Notes |
| --- | --- | --- |
| `tests/...` | `100%` or `equivalent` | `sha:<fp>`; `--class` targets; +1 legacy |

A row is done when Result is `100%` or `equivalent` for **in-scope** mutations (see below). `equivalent` means every remaining in-scope untested mutation is a behavior-preserving change (for example a cast the tests already feed as a float) and the Notes column says why. Do not mark a file done to skip a real in-scope gap.

**Cross-chat skip (file@blob):** when closing a row, stamp Notes with `sha:<fingerprint>` from `~/git/bin/workvm-ledger-sha.sh <api-main> <test-path> <each --class production path>` (sorted blobs of the test file + every production file you mutated). On later chats / colleague dispatcher passes, **skip** that test (no sandbox, no mutate) when Result is done **and** Notes contain `sha:…` **and** recomputing the fingerprint matches. Done row with **no** `sha:` → re-run once and stamp (legacy rows). Same tip + same blobs across chats must not recreate sandboxes.

**Personal ledger only:** `mutation-ledger.md` lives in this private meta-repo. Other company authors do **not** have it and cannot stamp `sha:` on their machine. A **first** colleague review of someone else’s card is therefore a **cold** mutate (no skip). The fingerprint win is for **your** retries: 2nd review, `try again`, another chat, or a card you already mutated on this host with the tip unchanged. Bench DOP-1258 (3 stamped files): skip ~70 ms vs cold remutate wall ~29 s (~400×; cold measured without sandbox create — real colleague cold is slower).

## Change-set file list (shared)

Work only in `~/git/olie/api-main`.

1. List changed paths (staged + unstaged + untracked):

   `git status --short` and `git diff --name-only HEAD` plus untracked files.

2. From that list, keep `*Test.php` under `tests/`. Sort by path. Skip a path only when its ledger row is done **and** its `sha:` fingerprint still matches (`workvm-ledger-sha.sh` on the test + `--class` production paths). Path-only skip without `sha:` is not enough across chats.
3. Collect production PHP classes from the same change set (`app/**/*.php` added or modified). Map each path to its FQCN (PSR-4 `App\` ← `app/`). That list is the **change-set pool** only — **not** the `--class` list for every test.
4. **Per-test `--class` scope (required):** for each `*Test.php`, mutate **only** the pool FQCNs that test actually exercises. Prefer `use App\…` imports that intersect the pool; add FQCNs the test clearly drives via HTTP/jobs/observers when imports are missing. Do **not** pass the whole pool to every file — `--covered-only` still burns wall-clock on transitively covered classes (bench DOP-1281: `ChannelMessageTemplatesTest` full pool 21 classes ~657s vs scoped 8 ~416s ≈ **1.6×**; light file ~4.7×).
5. Compute **in-scope line ranges** per changed `app/` file via `git diff -U0 HEAD -- <path>` (added/modified hunks only). New files: the whole file is in-scope.

If the change set has test files but **no** `app/` PHP changes, still run mutation on those tests (coverage may have been empty earlier). If the change set has **no** test files to mutate, say the mutation stack is empty and recommend `~/git/olie/prompts/pest-parallel.md` next.

## One changed test file / `next mutation`

1. Take the first remaining changed test file from the shared list. If the user named a test file in the same message, use that path instead (it must still be in the change set, unless they explicitly override).
2. If none remain: **dispatcher mode** → return clean/complete to the dispatcher and stop. **Own-card** → say the change-set stack is complete, recommend `~/git/olie/prompts/pest-parallel.md` as the next paste, and stop. **Alone on colleague stack** → say complete and tell the user to use `colleague-review.md` for the combined outcome.
3. Prepare, mutate those classes, close the file using the scoring rules below. **Own-card / alone (`next mutation`):** stop — do not start the next test file in this paste. **Dispatcher mode:** after the ledger row, continue with the next remaining file (or the next sandbox shard).

## `correct mutations` (parallel drain)

**Default** for own-card / alone when this prompt opens (or the user sends `correct mutations`). Same prepare → mutate → close **scoring** as a single file; different **orchestration**.

Problem this solves: N remaining `*Test.php` files as N× `next mutation` pastes dominated wall-clock (bench DOP-1258: ~472s sequential → ~230s parallel for 3 files).

**Warm pool size:** `N = min(remaining_files, 4)`. Use **`2`** when host RAM is tight (`free` available ≲ 8 GiB before create, or another heavy card/compose already up). Do **not** open one sandbox per file when remaining ≫ 4 — bench DOP-1258 (8 files, tip `cc57e847`): pools **2 / 4 / 6 / 8** all ~**387–406s** wall; **8** made the heaviest shard slower (~349s vs ~178s) via contention. Reuse pays more as file count grows (2nd+ wave on a warm slot ~4–20s vs ~150–180s cold).

1. Build the remaining-file list (shared steps 1–2). If empty, say the stack is complete and recommend `pest-parallel.md` (`next prompt`).
2. **Parent (this chat agent) orchestrates.** Do **not** process every file serially in one giant context when more than one remains.
3. Create a **warm pool** of `N` sandboxes. Resolve the card’s `api-main` tip (`host-card` `meta.json` → `api_worktree` / `…/worktree/api-main`, `git rev-parse HEAD`) and **always** pass it: `~/git/bin/workvm-sandbox create --name <unique> --project olie --profile mutation --from-commit <tip>`. **Forbidden:** bare create (no `--from-commit`) — that detaches at `~/git/olie/api-main` `HEAD` (usually `develop`), not the card tip (bench DOP-1183 / DOP-1281 recreate). Optionally set `WORKVM_SANDBOX_MAX=N` for this drain. Sync the card’s dirty `api-main` into each pool worktree once (uncommitted DOP changes must be copied in). Prefer **rsync dirty** on reuse, not full recreate.
4. Drain remaining files with at most **N** in flight: when a slot frees, assign the next file to that **same** sandbox (do not destroy between files of this drain). Launch **one subagent (Task) per in-flight file**. Pass at least: test path, sandbox id, **that file’s** scoped `--class` FQCNs (step 4 — not the whole change-set pool), in-scope hunk summary (or instruct the worker to compute `git diff -U0` in the synced tree), scoring rules (in-scope only; tighten tests not production; `equivalent` with mutation ids).
5. Each subagent runs baseline Pest → mutate → tighten if needed → returns a **proposed ledger row** (Result + Notes). It may edit **only** that `*Test.php` under the card working tree (or sync assertion edits back). It must **not** write `mutation-ledger.md` itself.
6. **Parent only** appends rows to `~/git/olie/prompts/mutation-ledger.md` (avoid races). Destroy the **pool** when the drain finishes (or destroy a slot on hard failure after reporting).
7. When every remaining file has a `100%` / `equivalent` row (or the user stops), report the aggregate and — if complete — recommend `pest-parallel.md`. If a shard is Blocked (red baseline, product bug, tooling), leave that path out of the ledger, keep the stack incomplete, and list retries (`try again` on that file or `correct mutations` again).

Not for colleague **dispatcher** mode (that drain is already mandatory without this phrase). Do not confuse with `to correct`.

## Prepare

**Dispatcher / exclusive:** run PHP inside the sandbox app container via
`~/git/bin/workvm-sandbox job run <id> -- <command>` (working dir is already
`/var/www/html`). Use the warm pool (`N = min(remaining, 4)`, or `2` if RAM-tight) —
reuse slots across files; destroy the pool when the drain finishes.

**Own-card fallback only** (no sandbox create possible): `docker exec -w /var/www/html olie-api-main <command>`. Do not use that path while colleague gates run in parallel on the Card VM.

Do not run `php` on the host.

- If `vendor/pest-plugins.json` is missing inside the container: `composer pest:dump-plugins`. (Pest 4 writes this under `vendor/`, not `vendor/bin/`.)
- If `php -m` does not list `pcov`: install it in the running container only (`pecl install pcov` and `docker-php-ext-enable pcov` as root). Say that a recreated image drops PCOV. Do not change the image or compose files.

Run the chosen file with the normal suite first (sandbox job, or own-card fallback):

```bash
~/git/bin/workvm-sandbox job run <sandbox-id> -- php artisan test --compact <test-path>
```

If that fails, stop. Do not mutate a red file.

## Mutate

Pass **only that test’s scoped** production FQCNs via `--class=...` (see change-set step 4). Prefer **one `--class` per mutate run** when a prior multi-`--class` run produced `0 Mutations for 0 Files` (Pest quirk). Do **not** use `--everything`. Do **not** re-run the full change-set pool “for safety” on every file.

Example (escape `\` for the shell):

```bash
~/git/bin/workvm-sandbox job run <sandbox-id> -- \
  vendor/bin/pest --mutate --covered-only --min=100 --ignore-min-score-on-zero-mutations \
  --class=App\\Services\\Media\\CreateMediaFromFrameAttachment \
  <test-path>
```

- `--class` is the Pest 4 scope (replaces needing committed `covers()` / `mutates()`).
- `--covered-only` keeps mutations on lines this test run executes inside those classes — still expensive if you pass unrelated pool classes the test happens to touch.
- `--ignore-min-score-on-zero-mutations` treats nothing-to-mutate as success.
- Pest may still emit mutations on **pre-existing** lines in a large modified class. That is expected. Split the report into **in-scope** (diff hunks) vs **out-of-scope** (everything else).

### Optional local-only `mutates()`

If `--class` fails for a given Pest build, temporarily add `mutates(ChangedClass::class);` for each changed class at the top of the test file and run without `--everything`. Remove those lines before finishing the paste. Never leave them staged or committed.

## Close the file

### In-scope (required)

- Score **in-scope** mutations only (line numbers inside the diff hunks for that class).
- In-scope all tested, or zero in-scope mutations: append a `100%` row (notes: `no mutations` when zero; otherwise list classes + “in-scope only”).
- In-scope untested: tighten assertions in that test file so the mutated behavior fails. Re-run mutate. Do not change production code to satisfy a mutation. If a mutation shows a real product bug, stop and report it.
- In-scope untested that does not change behavior: record `equivalent` and name the mutation id and why. Do not invent an assertion that cannot fail.

### Re-run budget (wall-clock)

Re-running `pest --mutate` without new killable asserts (or without accepting `equivalent`) only repeats the same score. On jarvis that burns minutes per file for zero ledger progress.

- After **one** mutate report for a `--class` / file: split in-scope survivors into **killable** vs **equivalent** immediately.
- Re-run mutate **only** after you changed the test to kill at least one killable in-scope mutant (or after a tooling fix). Cap: prefer **at most one** re-run per `--class` once killables are addressed; then close with `equivalent` for any remaining behavior-preserving ids.
- Do **not** re-mutate “to confirm” an unchanged tree, to climb Pest’s class-wide `%`, or to re-check mutants you already marked `equivalent`.
- Do **not** invent asserts that cannot fail just to avoid `equivalent`.

Pest’s overall `%` on a fat class may stay below 100%. That is OK. Ledger Result reflects **in-scope**, not Pest’s class-wide score. Put Pest’s raw score in Notes when it differs.

### +1 legacy (optional, once per paste)

After in-scope is done, you may pick **exactly one** out-of-scope untested mutation (prefer same class/file, cheap assertion) and tighten the test so it becomes tested. Do not chase more legacy mutations in the same paste. Note the chosen mutation id in the ledger Notes (`+1 legacy: …`).

Skip +1 if there are no useful out-of-scope untested mutations, or if fixing one would require a large unrelated suite.

- If you added temporary `covers()` / `mutates()`, remove them before writing the ledger row.

### After the row

Report the file, in-scope result, Pest raw score if different, any +1 legacy fix, and how many **changed** test files are still absent from the ledger.

- **Dispatcher mode:** if changed test files remain, continue with the next file in this same run (or the next sandbox shard). Do not ask for another paste.
- **Own-card / alone after `next mutation`:** if changed test files remain, say to send `next mutation` (one more file) or `correct mutations` (drain the rest). Do **not** recommend `pest-parallel.md` or `pre-qa.md`. Do **not** say the stack is ready for `next prompt`. Do **not** move a colleague card out of 'QA/CR'.
- **Own-card / alone after `correct mutations`:** if every shard closed, treat as stack complete for the after-row “none remain” branch. If some failed, list missing paths and offer `try again` / `correct mutations` — still do **not** open `pest-parallel.md` / `pre-qa.md`.

When **none** remain:

- **Dispatcher mode:** return Pass/Fixes/Blocked to `colleague-review.md` in chat (findings only — **Card content vs chat**). Do **not** bounce the author for mutation-only work — **reviewer-fix** in **Colleague review outcome**. Write into the card only when the combined outcome moves to 'Corrigir' (colleague core fail) and the author still needs those fixes. If the gate is clean or only local test asserts were tightened, return Clean in chat only. Do **not** apply the funnel move yourself.
- **Develop handoff** (came from coverage-testing / test-gap-analysis): recommend `~/git/olie/prompts/pest-parallel.md` as the next paste (`next prompt` runs it). Do **not** jump to `pre-qa.md` yet.

- **Alone on colleague stack:** keep mutation fixes in Cursor chat; tell the user to paste `colleague-review.md` for **Colleague review outcome** (do not move the funnel or write the card here).
