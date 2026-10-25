# Mutation testing (personal)

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/televisao/prompts/workflow-policy.md`.

Personal workflow on this VM. Run it only when `televisao-backend` already has Pest and `pest-plugin-mutate`. If either is missing, stop. Do not install them and do not bump PHP to match another product.

Do not add mutation testing to CI, `phpunit.xml`, Dockerfiles, or compose. Do not commit `covers()` or `mutates()` into company tests. Do not open a pull request whose purpose is mutation testing. Converting the one file below to Pest, and assertion edits that make a mutation fail, are normal test changes in `~/git/televisao/televisao-api`; do not commit or push them unless the user asks in this chat.

**Scope is the user’s local diff, plus a small legacy bonus.** Never walk the whole `tests/` tree. Never use `--everything` (it mutates every covered line the test touches — middleware, models, framework path — and is too slow for this repo).

## Ledger

Progress lives only in `~/git/televisao/prompts/mutation-ledger.md` (meta-repo). Create that file if it is missing, with a table:

| Test file | Result | Notes |
| --- | --- | --- |
| `tests/...` | `100%` or `equivalent` | short note; list `--class` targets; note any +1 legacy fix |

A row is done when Result is `100%` or `equivalent` for **in-scope** mutations (see below). `equivalent` means every remaining in-scope untested mutation is a behavior-preserving change (for example a cast the tests already feed as a float) and the Notes column says why. Do not mark a file done to skip a real in-scope gap.

## One changed test file per paste

Work only in `~/git/televisao/televisao-api`.

1. List changed paths (staged + unstaged + untracked):

   `git status --short` and `git diff --name-only HEAD` plus untracked files.

2. From that list, keep `*Test.php` under `tests/`. Sort by path. Skip paths already done in the ledger. Skip a file that is a trait or helper and not a test case.
3. Take the first remaining changed test file. If the user named a test file in the same message, use that path instead (it must still be in the change set, unless they explicitly override).
4. If none remain, say the change-set stack is complete and stop.
5. If that file is still a PHPUnit test case (`extends TestCase`) and Drift is already installed, convert **that file only** before mutating: `docker exec -w /var/www/html televisao-backend vendor/bin/pest --drift <that-file>`. Do not pass `tests/` or any other file. If Drift is missing, stop and report. Do not install it. If Drift leaves that file as PHPUnit, finish only that file by hand. If a data provider or shared trait cannot be expressed without rewriting unrelated files, stop and report that limit.
6. Collect production PHP classes from the same change set (`app/**/*.php` added or modified). Map each path to its FQCN (PSR-4 `App\` ← `app/`). Those are the mutation `--class` targets.
7. Compute **in-scope line ranges** per changed `app/` file via `git diff -U0 HEAD -- <path>` (added/modified hunks only). New files: the whole file is in-scope.
8. Prepare, mutate those classes, close the file using the scoring rules below. Stop. Do not start the next test file in this paste.

If the change set has test files but **no** `app/` PHP changes, stop and say there is nothing to mutate (do not fall back to full-project or `--everything`).

## Prepare

All PHP runs as `docker exec -w /var/www/html televisao-backend <command>`. Do not run `php` on the host.

- If `vendor/bin/pest` is missing inside the container, run `composer install` once. If it is still missing, stop. Do not install Pest.

- If `vendor/pest-plugins.json` is missing inside the container: `composer pest:dump-plugins`.
- If `php -m` does not list `pcov`: install it in the running container only (`pecl install pcov` and `docker-php-ext-enable pcov` as root). Say that a recreated image drops PCOV. Do not change the image or compose files.

Run the chosen file with the normal suite first:

`docker exec -w /var/www/html televisao-backend php artisan test --compact <test-path>`

If that fails, stop. Do not mutate a red file.

## Mutate

Pass changed production FQCNs via `--class=...`. Prefer **one `--class` per mutate run** when a prior multi-`--class` run produced `0 Mutations for 0 Files` (Pest quirk). Do **not** use `--everything`.

Example (escape `\` for the shell):

```bash
docker exec -w /var/www/html televisao-backend vendor/bin/pest --mutate --covered-only --min=100 --ignore-min-score-on-zero-mutations \
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

Pest’s overall `%` on a fat class may stay below 100%. That is OK. Ledger Result reflects **in-scope**, not Pest’s class-wide score. Put Pest’s raw score in Notes when it differs.

### +1 legacy (optional, once per paste)

After in-scope is done, you may pick **exactly one** out-of-scope untested mutation (prefer same class/file, cheap assertion) and tighten the test so it becomes tested. Do not chase more legacy mutations in the same paste. Note the chosen mutation id in the ledger Notes (`+1 legacy: …`).

Skip +1 if there are no useful out-of-scope untested mutations, or if fixing one would require a large unrelated suite.

- If you added temporary `covers()` / `mutates()`, remove them before writing the ledger row.

After the row is written, report the file, whether it was converted from PHPUnit in this paste, in-scope result, Pest raw score if different, any +1 legacy fix, and how many **changed** test files are still absent from the ledger.
