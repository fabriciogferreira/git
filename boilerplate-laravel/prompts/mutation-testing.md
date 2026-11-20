# Mutation testing (boilerplate-laravel)

Use when the change-set for `{{ feature }}` modified `~/git/boilerplate-laravel/boilerplate-laravel`. Skip when there is no backend.

**Must** shard exclusive work via:

```bash
~/git/bin/workvm-sandbox create --name <id> --project boilerplate-laravel --profile mutation --from-commit <tip>
~/git/bin/workvm-sandbox job run <id> --service backend -- <command>
```

Do **not** `docker exec` the Card/host backend for mutate. See `~/git/boilerplate-laravel/sandbox/ORCHESTRATION.md` and `~/git/boilerplate-laravel/prompts/workflow-policy.md`.

## Entry

- **Default:** `correct mutations` — drain every remaining changed `*Test.php` in this turn (warm pool + one Task per in-flight file).
- **`next mutation`:** one file only when the user asks.

## Ledger

`~/git/boilerplate-laravel/prompts/mutation-ledger.md`. Done = `100%` or `equivalent` for **in-scope** mutations. Stamp `sha:` via `~/git/bin/workvm-ledger-sha.sh` when closing.

## Change-set

1. List dirty + `main...HEAD` under `boilerplate-laravel`.
2. Keep `*Test.php`; skip done rows with matching `sha:`.
3. Per test, `--class` only FQCNs that test exercises (prefer imports ∩ change-set pool). One `--class` per mutate run.
4. In-scope lines = diff hunks of those classes.

## Warm pool

`N = min(remaining, 4)` (or `2` if RAM tight). Create shortfall with `--from-commit`. Reuse slots; destroy pool when drain ends. Parent writes the ledger; subagents must not.

## Prepare / mutate

```bash
~/git/bin/workvm-sandbox job run <id> --service backend -- \
  php artisan test --compact <test-path>

~/git/bin/workvm-sandbox job run <id> --service backend -- \
  php -d memory_limit=2G vendor/bin/pest --mutate --covered-only --min=100 \
  --ignore-min-score-on-zero-mutations --parallel \
  '--class=App\Services\Example\ExampleService' \
  <test-path>
```

Quoting: prefer `'--class=App\Services\Foo'` (single backslashes inside single quotes).

Baseline flake (DB lock / one-off crash): retry once on the same slot. Stable red assertions → stop; do not mutate.

## Close

Score **in-scope** only. Kill killables by tightening tests (not production). Remaining behavior-preserving → `equivalent` + mutation id. Prefer ≤1 re-mutate per `--class` after real assert changes.

When the change-set mutation stack is done → recommend `~/git/boilerplate-laravel/prompts/pre-deploy.md`.
