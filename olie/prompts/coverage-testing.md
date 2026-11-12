# Coverage testing (personal)

Use this when the card changed `~/git/olie/api-main` and you want **patch (diff) line coverage** for the change set. Skip entirely when there is no backend.

This is a personal WorkVM stack, same family as `~/git/olie/prompts/mutation-testing.md`. It **measures** whether the lines you touched ran under tests; it does not replace mutation testing. Pest answers “did this line run?”, not “would a bad change fail a test?”.

**Pest has no native “only my diff” flag.** It always reports whole-file %. This stack still runs Pest `--coverage`, then **scores only in-scope lines** (the same hunk idea as mutation). Do **not** require 100% of a fat pre-existing file when the card changed one line.

Three entry points:

1. **Own card (develop handoff)** — after `~/git/olie/prompts/mutation-testing.md` when backend changed (or after `test-gap-analysis.md` when you only want coverage). Continue with **`next coverage`** (one production file) or **`correct coverages`** (drain every remaining file in parallel). When this coverage stack is finished (or the user stops / skips), the next recommended prompt is `~/git/olie/prompts/pre-qa.md` (`next prompt` runs it).
2. **Colleague card via dispatcher** — optional; only if the dispatcher (or user) launched this prompt. **Dispatcher mode:** drain **every** remaining changed `app/**/*.php` in this run. Prefer `~/git/bin/workvm-sandbox create --project olie --profile mutation` (same exclusive Pest DB isolation as mutation — see `~/git/olie/sandbox/ORCHESTRATION.md`). Do **not** recommend `next coverage` / `correct coverages` / `next prompt`. Return Pass/Fixes/Blocked to the dispatcher.
3. **Colleague card pasted alone** — one file per paste (`next coverage`), or drain with `correct coverages`; when none remain, tell the user to return to `colleague-review.md` if that owns the card.

**Stack gate (develop handoff / alone):** while any changed `app/**/*.php` from the card’s `api-main` diff is missing a done row in `coverage-ledger.md` (or fails the Close gates), this stack is **incomplete**. Do **not** recommend or run `~/git/olie/prompts/pre-qa.md`. Do **not** treat `next prompt` as permission to leave coverage early. Only when every remaining file is closed (or the user explicitly stops / skips the personal stack) may you recommend `pre-qa.md`. If there is no `app/` PHP in the change set, the stack is empty — say so and recommend `pre-qa.md`.

Chat commands: `~/git/olie/prompts/workflow-policy.md` → **Chat commands** (includes `next coverage` and `correct coverages`).

**Own-card / alone:** `next coverage` = one changed `api-main` production PHP file per turn; `correct coverages` = drain **all** remaining change-set production files in this turn (sandbox + subagent per file when parallel). Prefer `workvm-sandbox` so Card VM `testing` stays untouched.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

Personal workflow on this VM. Do not add coverage gates to `api-main` CI, `phpunit.xml` thresholds, Dockerfiles, `docker-workspace`, or Composer. Do not commit temporary `covers()` into company tests. Do not open a pull request whose purpose is coverage reporting. Assertion edits that cover in-scope lines are normal test changes; do not commit or push them unless the user asks in this chat.

**Progressive ratchet (goal):** every touch must cover **all changed lines**, then leave the file a bit healthier than before, so repeated edits climb toward 100% without demanding a fat-file rewrite on day one.

Never walk the whole `app/` tree for suite Total. Never treat Pest’s suite-wide `Total: X%` as the gate.

### Chat commands (this stack)

| Command | Do this |
| --- | --- |
| `next coverage` | Continue **this** stack: pick the next changed `app/**/*.php` not yet done in the ledger and run prepare → measure → close for **one** file. Same as re-pasting this prompt. Do not open `pre-qa.md`. |
| `correct coverages` | **Own-card / alone drain:** process **every** remaining changed production file in this turn (not one). Prefer one sandbox **and** one subagent per file; parent orchestrates and writes the ledger. Do not open `pre-qa.md` until the drain finishes (or the user stops). Details below. |
| `next prompt` | **Blocked** while the change-set stack still has remaining production files. Refuse, list how many files remain (and the next path), and tell the user to send `next coverage` or `correct coverages`. Only after the stack is complete may `next prompt` run `~/git/olie/prompts/pre-qa.md`. |
| `try again` | Resume or re-run coverage on the **current** (last attempted) production file after a stop or fix. Do not skip ahead to another file or to pre-QA. After a failed `correct coverages` shard, retry that file (or re-send `correct coverages` for all still-missing rows). |

## Ledger

Progress lives only in `~/git/olie/prompts/coverage-ledger.md` (meta-repo). Create that file if it is missing, with a table:

| File | Last measured | In-scope | Uncovered (in-scope) | File raw | Via test | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `app/...` | `YYYY-MM-DD HH:MM TZ` | `100%` | `—` or `29` | `12.5%` | `tests/...` | FQCN; hunks; +1 legacy |

A row is **done** when the **Close the file** gates pass (in-scope + ratchet / small-file rules below). Update the same row on re-measure (do not duplicate paths). The previous **File raw** on that row is the baseline for the next card’s +1pp ratchet.

- **File** — path under `app/` (repo-relative from `api-main`).
- **Last measured** — local VM clock when this row was written (`date '+%Y-%m-%d %H:%M %Z'`).
- **In-scope** — covered in-scope executable lines ÷ in-scope executable lines. New files: whole file is in-scope.
- **Uncovered (in-scope)** — in-scope line numbers still red after the run (`29`, `52..60`, or `—`).
- **File raw** — Pest’s whole-file % for that path after this pass (also the ratchet baseline for the next touch).
- **Via test** — the `*Test.php` path used (comma-separate if several).
- **Notes** — FQCN; hunks; ratchet target (`raw 12.5% → ≥13.5%`); `+1 legacy` / lines added for the ratchet; small-file / new-file `100%` note; PCOV.

## Change-set file list (shared)

Work only in `~/git/olie/api-main`.

1. List changed paths (staged + unstaged + untracked):

   `git status --short` and `git diff --name-only HEAD` plus untracked files.

2. From that list, keep production PHP under `app/` (`*.php`). Sort by path. Skip paths that already have a done ledger row **for this card pass** unless the user asked to re-measure.
3. From the same change set, keep `*Test.php` under `tests/` as candidate runners.
4. Map each production path to its FQCN (PSR-4 `App\` ← `app/`).
5. Compute **in-scope line ranges** per changed `app/` file via `git diff -U0 HEAD -- <path>` (added/modified hunks only). New files: the whole file is in-scope. Deleted-only hunks are not coverage targets.

If the change set has **no** `app/` PHP changes, stop and say there is nothing to measure for coverage (tests-only diffs do not get production coverage rows). That empty case clears the stack gate for `pre-qa.md` on own-card.

## One production file / `next coverage`

1. Take the first remaining changed production file from the shared list. If the user named an `app/` path in the same message, use that path instead (it must still be in the change set, unless they explicitly override).
2. If none remain: **dispatcher mode** → return clean/complete to the dispatcher and stop. **Own-card / alone** → say the coverage stack is complete, recommend `~/git/olie/prompts/pre-qa.md` as the next paste, and stop.
3. Prepare, measure that file, close using the scoring rules below. **Own-card / alone (`next coverage`):** stop — do not start the next production file in this paste. **Dispatcher mode:** after the ledger row, continue with the next remaining file.

## `correct coverages` (parallel drain)

Own-card / alone chat command. Same prepare → measure → close scoring as a single file; different orchestration.

1. Build the remaining-file list (shared steps 1–2). If empty, say the stack is complete and recommend `pre-qa.md` (`next prompt`).
2. **Parent (this chat agent) orchestrates.** Do not process every file serially in one giant context when more than one remains.
3. For each remaining file, in parallel up to `WORKVM_SANDBOX_MAX` (queue the rest — `~/git/olie/sandbox/ORCHESTRATION.md`):
   - Prefer `~/git/bin/workvm-sandbox create --name <unique> --project olie --profile mutation`.
   - Sync the card’s dirty `api-main` working tree into that sandbox worktree when needed.
   - Launch **one subagent (Task) per file**. Pass at least: production path, FQCN, in-scope hunks (`git diff -U0`), sandbox id (if any), candidate test paths, and the scoring/ledger rules.
4. Each subagent runs baseline Pest (if a test is used) → coverage measure → tighten if in-scope gaps remain → returns a **proposed ledger row**. It may edit **only** test files under the card working tree. It must **not** write `coverage-ledger.md` itself.
5. **Parent only** appends/updates rows in `~/git/olie/prompts/coverage-ledger.md` (avoid races). Destroy each sandbox when that shard’s row is accepted (or on hard failure after reporting).
6. When every remaining file has a done row (or the user stops), report the aggregate and — if complete — recommend `pre-qa.md`. If a shard is Blocked, leave that path incomplete and list retries (`try again` / `correct coverages`).

## Prepare

**Sandbox / exclusive:** run PHP inside the sandbox app container via
`~/git/bin/workvm-sandbox job run <id> -- <command>` (working dir is already
`/var/www/html`).

**Own-card fallback only** (no sandbox create possible): `docker exec -w /var/www/html olie-api-main <command>`. Do not use that path while colleague exclusive gates share the Card VM.

Do not run `php` on the host.

- If `php -m` does not list `pcov`: install it in the running container only (`pecl install pcov` and `docker-php-ext-enable pcov` as root). Say that a recreated image drops PCOV. Do not change the image or compose files. Xdebug 3+ with `XDEBUG_MODE=coverage` is an alternative; prefer PCOV here.
- `phpunit.xml` already includes `<source><include>app</include></source>` — do not edit it for this stack.

Pick a **Via test** runner:

1. Prefer a changed `*Test.php` that clearly targets this class (same feature folder, imports the FQCN, or named after it).
2. Else the smallest existing test under `tests/` that boots the class (search `use <FQCN>` / class basename). Prefer change-set tests over unrelated suite files.
3. If none exists: record In-scope `n/a`, Uncovered `—`, File raw `—`, Via test `—`, Notes `no related test` — then stop for this file (do not invent a full new suite unless the user asked).

If a Via test is chosen, run it green first:

```bash
~/git/bin/workvm-sandbox job run <sandbox-id> -- php artisan test --compact <test-path>
```

If that fails, stop. Do not measure coverage on a red file.

## Measure

Focus Pest’s coverage report on the target class with a **temporary** `covers(<FQCN>::class);` at the top of the Via test. Remove it before finishing the paste. Never leave it staged or committed.

Run:

```bash
~/git/bin/workvm-sandbox job run <sandbox-id> -- \
  vendor/bin/pest --coverage \
  <test-path>
```

Read the report line for the target path (e.g. `Services/AI/Credits/ConvertCostToCredits .... 29 / 83.3%`):

- **File raw** = that whole-file % (`83.3%`).
- Pest’s red line list = uncovered executable lines in the file.

Then intersect with **in-scope** hunks from the shared list:

- In-scope uncovered = uncovered lines whose numbers sit inside the diff hunks.
- In-scope covered = in-scope executable lines not in that uncovered set.
- **In-scope %** = covered ÷ (covered + uncovered) among in-scope executable lines. If the hunk only touched comments/whitespace/non-executable tokens Pest does not count, treat as In-scope `100%` with Notes `no executable in-scope lines`.

If `covers()` is unavailable or ignored, run without it and pick the target file’s line from the report manually (ignore suite Total and unrelated 0% noise).

Do **not** use Pest `--min` / `--exactly` against suite Total. File raw is scored by the **Close the file** ratchet / small-file rules, not by Pest’s `--min` flag.

## Close the file

### 1) In-scope — always required

- Cover **100%** of in-scope executable lines (the diff hunks). New file → whole file is in-scope → File raw must also be `100%`.
- In-scope uncovered: tighten or add assertions in the Via test (or a sibling change-set test) so those lines **run**. Re-measure. Do not change production code only to satisfy coverage. If hitting an in-scope line exposes a real product bug, stop and report it.
- Prefer the smallest test change that executes the touched path. Do not rewrite the suite for the whole pre-existing class unless a rule below requires File raw `100%`.
- No executable in-scope lines (comment/whitespace-only hunk): In-scope `100%`, Notes `no executable in-scope lines` — still apply the ratchet / small-file rules when they apply.

### 2) File-size / complexity band

Count **executable** lines Pest considers for that file (from the coverage report: covered + uncovered). Choose one band:

| Band | When | Extra gate after in-scope `100%` |
| --- | --- | --- |
| **New file** | Path did not exist at `HEAD` (untracked or added) | File raw **`100%`** (same as in-scope). |
| **Small** | ≤ **80** executable lines | File raw **`100%`**. Cheap enough to finish in one touch. |
| **Large** | \> **80** executable lines | **Ratchet** below (do **not** demand whole-file `100%` this paste). |

80 is a WorkVM heuristic (roughly one focused service/action). If the file is a known fat God-object just under 80 but finishing it would be a multi-hour suite, treat it as **Large** and say so in Notes.

### 3) Ratchet (+1 percentage point) — Large files

Goal of your example: file at `0%`, add a route → cover the new route **and** leave the file at least **+1pp** healthier so the next person climbs further.

1. Read the previous ledger **File raw** for this path (if any). Call it `prev`.
2. After in-scope is green, read the new Pest whole-file % → `raw`.
3. **Target** = `min(100, prev + 1)` when a previous row exists. Round Pest % to one decimal like Pest prints (`12.5`).
4. If **no previous row** (first measure on this VM): in-scope `100%` alone closes the row; record `raw` as the baseline. Covering the new route often already jumps `0 → N%` — that jump *is* the first progress; do not invent an extra +1pp beyond in-scope on the first ever row unless it is free.
5. If a previous row exists and `raw < target`: cover additional **out-of-scope** uncovered lines in the **same file** (nearest cheap branches) until `raw ≥ target` or the file hits `100%`. Note which lines/tests did the ratchet (`ratchet 12.5%→13.5%: L40,L55`).
6. If reaching `target` would need a large unrelated suite (heavy HTTP matrix, flaky deps): stop, keep the row **not done**, and report Blocked with what remains — do not fake the %.

Do **not** use a bare “+1% of the diff” or “+1 random line” as the Large-file rule when a ledger baseline exists — the **file-level +1pp** is what makes coverage climb across cards. A single legacy line is only a tool to help hit that +1pp (or the first-row optional nudge below).

### 4) First-row nudge (optional)

On the **first** ledger row for a Large file, after in-scope `100%`, you may cover **one** cheap out-of-scope line (`+1 legacy: L173`) if it is free. Skip if not cheap. This is optional; the mandatory climb starts on the **second** touch via the ratchet.

### Done criteria (summary)

| Situation | Done when |
| --- | --- |
| New or Small file | In-scope `100%` **and** File raw `100%` |
| Large, first ledger row | In-scope `100%` (optional +1 legacy) |
| Large, ledger already had File raw `prev` | In-scope `100%` **and** File raw ≥ `min(100, prev + 1)` |
| No related test | In-scope `n/a` + Notes `no related test` (stack incomplete for that path until a test exists or the user skips) |

Remove temporary `covers()` before writing the ledger row.

### After the row

Report the file, in-scope %, file raw %, ratchet target vs result, any legacy/ratchet lines, and how many changed production files are still absent or failing the gate.

- **Dispatcher mode:** if files remain, continue with the next one in this run.
- **Own-card / alone after `next coverage`:** if files remain, say to send `next coverage` (one more file) or `correct coverages` (drain the rest). Do **not** recommend `pre-qa.md`. Do **not** say the stack is ready for `next prompt`.
- **Own-card / alone after `correct coverages`:** if every shard closed, treat as stack complete for the after-row “none remain” branch. If some failed, list missing paths and offer `try again` / `correct coverages` — still do **not** open `pre-qa.md`.

When **none** remain:

- **Dispatcher mode:** return Clean/complete to the dispatcher in chat only. Do **not** apply the funnel move yourself.
- **Develop handoff** (came from mutation-testing / implementation-validation): recommend `~/git/olie/prompts/pre-qa.md` as the next paste (`next prompt` runs it).
- **Alone on colleague stack:** tell the user to return to `colleague-review.md` if that owns the card.

Do not move Olie funnel steps from this prompt.
