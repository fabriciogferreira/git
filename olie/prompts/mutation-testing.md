# Mutation testing (personal)

Use this **after** `~/git/olie/prompts/implementation-validation.md` passes **and** the card changed `~/git/olie/api-main`. Skip entirely when the change set has no backend.

**Stack gate:** while any changed `*Test.php` under `tests/` is still missing from the ledger (or has no `100%` / `equivalent` row), this stack is **incomplete**. Do **not** recommend or run `~/git/olie/prompts/pre-qa.md`. Do **not** treat `next prompt` as permission to leave mutation early. Only when every remaining file is closed (or the user explicitly stops / skips the personal stack) may you recommend `pre-qa.md`.

Chat commands: `~/git/olie/prompts/workflow-policy.md` → **Chat commands** (includes `next mutation`).

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

Personal workflow on this VM. Pest mutation testing is not an Olie team practice. Do not add it to `api-main` CI, `phpunit.xml`, Dockerfiles, `docker-workspace`, or Composer. Do not commit `covers()` or `mutates()` into company tests. Do not open a pull request whose purpose is mutation testing. Assertion edits that make a mutation fail are normal test changes in `~/git/olie/api-main`; do not commit or push them unless the user asks in this chat.

**Scope is the user’s local diff, plus a small legacy bonus.** Never walk the whole `tests/` tree. Never use `--everything` (it mutates every covered line the test touches — middleware, models, framework path — and is too slow for this repo).

### Chat commands (this stack)

| Command | Do this |
| --- | --- |
| `next mutation` | Continue **this** stack: pick the next changed `*Test.php` not yet done in the ledger and run the full prepare → mutate → close procedure for **one** file. Same as re-pasting this prompt. Do not open `pre-qa.md`. |
| `next prompt` | **Blocked** while the change-set stack still has remaining test files. Refuse, list how many files remain (and the next path), and tell the user to send `next mutation` (or paste this prompt again). Only after the stack is complete may `next prompt` run `~/git/olie/prompts/pre-qa.md`. |
| `try again` | Resume or re-run mutation on the **current** (last attempted) test file after a stop or fix. Do not skip ahead to another file or to pre-QA. |

## Ledger

Progress lives only in `~/git/olie/prompts/mutation-ledger.md` (meta-repo). Create that file if it is missing, with a table:

| Test file | Result | Notes |
| --- | --- | --- |
| `tests/...` | `100%` or `equivalent` | short note; list `--class` targets; note any +1 legacy fix |

A row is done when Result is `100%` or `equivalent` for **in-scope** mutations (see below). `equivalent` means every remaining in-scope untested mutation is a behavior-preserving change (for example a cast the tests already feed as a float) and the Notes column says why. Do not mark a file done to skip a real in-scope gap.

## One changed test file per paste / `next mutation`

Work only in `~/git/olie/api-main`.

1. List changed paths (staged + unstaged + untracked):

   `git status --short` and `git diff --name-only HEAD` plus untracked files.

2. From that list, keep `*Test.php` under `tests/`. Sort by path. Skip paths already done in the ledger.
3. Take the first remaining changed test file. If the user named a test file in the same message, use that path instead (it must still be in the change set, unless they explicitly override).
4. If none remain, say the change-set stack is complete, recommend `~/git/olie/prompts/pre-qa.md` as the next paste (`next prompt` is enough), and stop.
5. Collect production PHP classes from the same change set (`app/**/*.php` added or modified). Map each path to its FQCN (PSR-4 `App\` ← `app/`). Those are the mutation `--class` targets.
6. Compute **in-scope line ranges** per changed `app/` file via `git diff -U0 HEAD -- <path>` (added/modified hunks only). New files: the whole file is in-scope.
7. Prepare, mutate those classes, close the file using the scoring rules below. Stop. Do not start the next test file in this paste / this `next mutation` turn.

If the change set has test files but **no** `app/` PHP changes, stop and say there is nothing to mutate (do not fall back to full-project or `--everything`). That empty case also clears the stack gate for `pre-qa.md`.

## Prepare

All PHP runs as `docker exec -w /var/www/html olie-api-main <command>`. Do not run `php` on the host.

- If `vendor/pest-plugins.json` is missing inside the container: `composer pest:dump-plugins`. (Pest 4 writes this under `vendor/`, not `vendor/bin/`.)
- If `php -m` does not list `pcov`: install it in the running container only (`pecl install pcov` and `docker-php-ext-enable pcov` as root). Say that a recreated image drops PCOV. Do not change the image or compose files.

Run the chosen file with the normal suite first:

`docker exec -w /var/www/html olie-api-main php artisan test --compact <test-path>`

If that fails, stop. Do not mutate a red file.

## Mutate

Pass changed production FQCNs via `--class=...`. Prefer **one `--class` per mutate run** when a prior multi-`--class` run produced `0 Mutations for 0 Files` (Pest quirk). Do **not** use `--everything`.

Example (escape `\` for the shell):

```bash
docker exec -w /var/www/html olie-api-main vendor/bin/pest --mutate --covered-only --min=100 --ignore-min-score-on-zero-mutations \
  --class=App\\Services\\Media\\CreateMediaFromFrameAttachment \
  <test-path>
```

- `--class` is the Pest 4 scope (replaces needing committed `covers()` / `mutates()`).
- `--covered-only` keeps mutations on lines this test run executes inside those classes.
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

Pest’s overall `%` on a fat class may stay below 100%. That is OK. Ledger Result reflects **in-scope**, not Pest’s class-wide score. Put Pest’s raw score in Notes when it differs.

### +1 legacy (optional, once per paste)

After in-scope is done, you may pick **exactly one** out-of-scope untested mutation (prefer same class/file, cheap assertion) and tighten the test so it becomes tested. Do not chase more legacy mutations in the same paste. Note the chosen mutation id in the ledger Notes (`+1 legacy: …`).

Skip +1 if there are no useful out-of-scope untested mutations, or if fixing one would require a large unrelated suite.

- If you added temporary `covers()` / `mutates()`, remove them before writing the ledger row.

### After the row

Report the file, in-scope result, Pest raw score if different, any +1 legacy fix, and how many **changed** test files are still absent from the ledger.

- **Files remain:** list the remaining paths (or at least the next one and the count). Tell the user to send **`next mutation`** (or re-paste this prompt). Do **not** recommend `pre-qa.md`. Do **not** say the stack is ready for `next prompt`.
- **None remain:** say the change-set stack is complete and recommend `~/git/olie/prompts/pre-qa.md` (`next prompt` runs it).
