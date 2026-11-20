# Coverage testing (boilerplate-laravel)

Use when the change-set for `{{ feature }}` modified `~/git/boilerplate-laravel/boilerplate-laravel` `app/**/*.php`. Measures **in-scope (diff) lines**, not suite Total %.

**Must** use sandbox:

```bash
~/git/bin/workvm-sandbox create --name <id> --project boilerplate-laravel --profile tests --from-commit <tip>
~/git/bin/workvm-sandbox job run <id> --service backend -- <command>
```

Do **not** `docker exec` the Card/host backend for coverage. See `~/git/boilerplate-laravel/sandbox/ORCHESTRATION.md`.

## Entry

- **Default:** `correct coverages` — drain remaining production files (warm pool + Task).
- **`next coverage`:** one file when the user asks.
- When complete → recommend `mutation-testing.md`.

## Ledger

`~/git/boilerplate-laravel/prompts/coverage-ledger.md`. Done when in-scope lines are covered. Stamp `sha:`.

## Measure

```bash
~/git/bin/workvm-sandbox job run <id> --service backend -- \
  php artisan test --compact --coverage --min=100 \
  --coverage-filter=<app/relative/path.php> \
  <via-test-path>
```

For a single-class gate, restrict PHPUnit `<source>` to that file in the sandbox worktree (or use an equivalent filter) so `--min=100` applies to that FQCN, not the whole `app/` tree.

Score only in-scope hunks from the change-set. Do not require 100% of an untouched fat file.

## Warm pool

Same as mutation: `N = min(remaining, 4)` (or `2`). Parent writes ledger; destroy pool when drain ends.
