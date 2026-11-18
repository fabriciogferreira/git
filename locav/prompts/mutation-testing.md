# Mutation testing (personal)

Use this **after** `~/git/locav/prompts/coverage-testing.md` **and** the card changed `~/git/locav/LocavApi`. Skip entirely when the change set has no backend.

Two entry points:

1. **Own card (develop handoff)** — after `coverage-testing.md` (which follows gap when `LocavApi` applies). **Default:** drain every remaining changed `*Test.php` in this paste (`correct mutations` / parallel subagents). Use **`next mutation`** only when the user asks for one file. When finished (or the user stops), next is `~/git/locav/prompts/pest-parallel.md`, then `pre-qa.md`.
2. **Colleague card in 'QA/CR'** — after gap/coverage when `LocavApi` changed (Locav colleague stack may be sequential). Same default drain; leave the card in 'QA/CR' until mutation finishes, then run `pest-parallel.md` before the combined outcome when applicable.

Chat commands: `~/git/locav/prompts/workflow-policy.md` → **Chat commands** (`correct mutations` default; `next mutation` opt-in).

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/locav/prompts/workflow-policy.md`.

Personal workflow on this VM. `LocavApi` dev dependencies are Pest 4 (`pestphp/pest:^4.0`, `pestphp/pest-plugin-mutate:^4.0`) and PHPUnit 12 on PHP 8.3. Existing tests are still PHPUnit classes until converted. Pest 5 needs PHP 8.4. Do not bump PHP or PHPUnit to install it now. When the PHP version is raised, try Pest 5.

Do not add mutation testing to CI, `phpunit.xml`, Dockerfiles, or compose. Do not commit `covers()` or `mutates()` into company tests. Do not open a pull request whose purpose is mutation testing. Converting the one file below to Pest, and assertion edits that make a mutation fail, are normal test changes in `~/git/locav/LocavApi`; do not commit or push them unless the user asks in this chat.

**Scope is the user’s local diff, plus a small legacy bonus.** Never walk the whole `tests/` tree. Never use `--everything` (it mutates every covered line the test touches — middleware, models, framework path — and is too slow for this repo).

## Ledger

Progress lives only in `~/git/locav/prompts/mutation-ledger.md` (meta-repo). Create that file if it is missing, with a table:

| Test file | Result | Notes |
| --- | --- | --- |
| `tests/...` | `100%` or `equivalent` | `sha:<fp>`; `--class` targets; +1 legacy |

A row is done when Result is `100%` or `equivalent` for **in-scope** mutations (see below). `equivalent` means every remaining in-scope untested mutation is a behavior-preserving change (for example a cast the tests already feed as a float) and the Notes column says why. Do not mark a file done to skip a real in-scope gap.

**Cross-chat skip (file@blob):** when closing a row, stamp Notes with `sha:<fingerprint>` from `~/git/bin/workvm-ledger-sha.sh <LocavApi> <test-path> <each --class production path>`. Later chats skip that test (no sandbox/mutate) when Result is done **and** `sha:` still matches. Done row with **no** `sha:` → re-run once and stamp.

**Personal ledger only:** `mutation-ledger.md` lives in this private meta-repo. Other company authors do **not** have it and cannot stamp `sha:`. A **first** colleague review of someone else’s card is a **cold** mutate. Skip helps **your** retries (2nd review / `try again` / another chat) when the tip is unchanged. Olie bench DOP-1258: skip ~70 ms vs cold remutate wall ~29 s (~400×; without sandbox create).

## Change-set file list (shared)

Work only in `~/git/locav/LocavApi`. Resolve paths with **Backend change-set** in `~/git/locav/prompts/workflow-policy.md` (dirty + `<base>...HEAD`; if three-dot empty and the card still has backend, merge-parent / `--grep=<CODE>`).

1. Build the changed-path list from that recipe (not `git diff HEAD` alone on a merged tip).

2. From that list, keep `*Test.php` under `tests/`. Sort by path. Skip a path only when its ledger row is done **and** its `sha:` fingerprint still matches (`workvm-ledger-sha.sh` on the test + `--class` production paths). Path-only skip without `sha:` is not enough across chats. Skip a file that is a trait or helper and not a test case.
3. Collect production PHP classes from the same change set (`app/**/*.php` added or modified). Map each path to its FQCN (PSR-4 `App\` ← `app/`). That list is the **change-set pool** only — **not** the `--class` list for every test.
4. **Per-test `--class` scope (required):** for each `*Test.php`, mutate **only** the pool FQCNs that test actually exercises. Prefer `use App\…` imports that intersect the pool; add FQCNs the test clearly drives via HTTP/jobs when imports are missing. Do **not** pass the whole pool to every file (Olie bench DOP-1281: heavy test ~1.6× faster scoped; light ~4.7×).
5. Compute **in-scope line ranges** per changed `app/` file from the same recipe’s hunk source (added/modified hunks only). New files: the whole file is in-scope.

If the change set has test files but **no** `app/` PHP changes, stop and say there is nothing to mutate (do not fall back to full-project or `--everything`).

## One changed test file / `next mutation`

Opt-in one-file path (user asked for `next mutation`).

1. Take the first remaining changed test file from the shared list (or the path the user named).
2. If none remain, say the change-set mutation stack is complete, recommend `~/git/locav/prompts/pest-parallel.md`, and stop.
3. If that file is still a PHPUnit test case (`extends TestCase`), convert **that file only** with Drift before mutating: `docker exec -w /var/www/html locav-backend vendor/bin/pest --drift <that-file>`. If `pestphp/pest-plugin-drift` is missing, `composer require pestphp/pest-plugin-drift:^4.1 --dev --no-interaction` in that container. Do not install Drift 5. Do not pass `tests/`.
4. Prepare, mutate **that file’s scoped** `--class` targets (step 4), close the file. Stop — do not start the next test file in this paste.

## `correct mutations` (parallel drain)

**Default** for own-card / alone when this prompt opens (or the user sends `correct mutations`). Locav has no mutation sandbox profile yet — use parallel **subagents** and `docker exec -w /var/www/html locav-backend` (serialize only if the shared testing DB cannot take concurrent Pest mutate).

**Concurrency:** keep at most `N = min(remaining_files, 4)` mutate jobs in flight (or **`2`** if the shared DB / host is already loaded). Same warm-pool idea as Olie sandboxes: more than ~4 concurrent mutates rarely shortens wall and can thrash. Olie bench DOP-1258: pools 2/4/6/8 ≈ same wall.

1. Build the remaining-file list (shared steps 1–2). If empty, say complete and recommend `pest-parallel.md`.
2. Parent orchestrates. Prefer one subagent (Task) per **in-flight** file (queue the rest; Drift if needed; mutate; propose ledger row). Subagent must **not** write `mutation-ledger.md`.
3. Parent only appends ledger rows.
4. When every remaining file has a done row (or the user stops), report the aggregate; if complete, recommend `pest-parallel.md`.

## Prepare

All PHP runs as `docker exec -w /var/www/html locav-backend <command>`. Do not run `php` on the host.

- If `vendor/bin/pest` is missing inside the container, run `composer install`. Do not install Pest 3 or Pest 5. Pest is already declared as `pestphp/pest:^4.0` and `pestphp/pest-plugin-mutate:^4.0`.

- If `vendor/pest-plugins.json` is missing inside the container: `composer pest:dump-plugins`.
- If `php -m` does not list `pcov`: install it in the running container only (`pecl install pcov` and `docker-php-ext-enable pcov` as root). Say that a recreated image drops PCOV. Do not change the image or compose files.

Run the chosen file with the normal suite first:

`docker exec -w /var/www/html locav-backend php artisan test --compact <test-path>`

**Baseline / infra flake (required before Blocked):** transient MySQL deadlock / lock wait (`Deadlock found`, `Lock wait timeout`, `model_has_permissions`), connection reset, or one-off Pest crash with no product assertion failure → **retry the same command once** on the same container (no open-ended loop). Retry green → continue. Same flake again → Blocked. Do **not** count this against the mutate re-run budget. Stable red assertions → stop; do not mutate.

## Mutate

Pass **only that test’s scoped** production FQCNs via `--class=...` (change-set step 4). Prefer **one `--class` per mutate run** when a prior multi-`--class` run produced `0 Mutations for 0 Files` (Pest quirk). Do **not** use `--everything`. Do **not** re-run the full change-set pool on every file.

**`--class` quoting (required):** `docker exec` passes argv without an inner shell. Pest must see `App\Services\Foo` (one `\`). Canonical: `'--class=App\Services\Foo'`. **Wrong:** `'--class=App\\Services\\Foo'` (double `\` → often `0 Mutations`); unquoted `App\…` (bash eats `\`).

```bash
docker exec -w /var/www/html locav-backend vendor/bin/pest --mutate --covered-only --min=100 --ignore-min-score-on-zero-mutations \
  '--class=App\Services\Example\ExampleAction' \
  <test-path>
```

- `--class` scopes the run (replaces needing committed `covers()` / `mutates()`).
- `--covered-only` keeps mutations on lines this test run executes inside those classes — still expensive if you pass unrelated pool classes the test happens to touch.
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
- Infra/deadlock retry (Prepare) is separate: at most **one** automatic retry, then Blocked.

Pest’s overall `%` on a fat class may stay below 100%. That is OK. Ledger Result reflects **in-scope**, not Pest’s class-wide score. Put Pest’s raw score in Notes when it differs.

### +1 legacy (optional, once per paste)

After in-scope is done, you may pick **exactly one** out-of-scope untested mutation (prefer same class/file, cheap assertion) and tighten the test so it becomes tested. Do not chase more legacy mutations in the same paste. Note the chosen mutation id in the ledger Notes (`+1 legacy: …`).

Skip +1 if there are no useful out-of-scope untested mutations, or if fixing one would require a large unrelated suite.

- If you added temporary `covers()` / `mutates()`, remove them before writing the ledger row.

After the row is written, report the file, whether it was converted from PHPUnit in this paste, in-scope result, Pest raw score if different, any +1 legacy fix, and how many **changed** test files are still absent from the ledger.

- **Files remain:** say to paste this prompt again (or send `next mutation`) for the next changed test file. Do **not** recommend `pre-qa.md`. Do **not** move a colleague card out of 'QA/CR'.
- **None remain:**
  - **Develop handoff:** recommend `~/git/locav/prompts/pest-parallel.md` as the next paste (`next prompt` runs it); `pre-qa.md` comes after a green suite.
  - **Colleague QA/CR stack:** keep mutation fixes in Cursor chat for the scoreboard / **reviewer-fix** path (do not bounce for mutation-only). Write into the card only when the combined outcome moves to 'Corrigir' (colleague review fail) and the author still needs those fixes. Recommend `pest-parallel.md` next when applicable; **Colleague review outcome** after that stack (or an explicit skip).
