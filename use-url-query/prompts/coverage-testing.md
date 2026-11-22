# Coverage testing (use-url-query project)

Use when the change-set for `{{ feature }}` modified production code in:

- lib: `~/git/use-url-query/use-url-query` `src/**/*`, and/or
- demo-api: `~/git/use-url-query/use-url-query-demo-api` `app/**/*.php` (or equivalent production PHP)

Measures **in-scope (diff) lines**, not suite Total %. Shared rules: `~/git/use-url-query/prompts/workflow-policy.md`.

## Entry

- **Default:** `correct coverages` — drain remaining production files (warm pool + Task).
- **`next coverage`:** one file when the user asks.
- When complete → recommend `mutation-testing.md` (required; no auto-skip).

## Ledger

`~/git/use-url-query/prompts/coverage-ledger.md`. One row per production file (note which clone). Done when in-scope lines are covered. Stamp `sha:` via `~/git/bin/workvm-ledger-sha.sh` when closing.

## Lib measure (exclusive sandbox)

```bash
~/git/bin/workvm-sandbox create --name <id> --project use-url-query --profile tests --from-commit <tip>
~/git/bin/workvm-sandbox job run <id> --service backend -- \
  bun run test:coverage
```

Do **not** `docker exec` the Card lib container for lib coverage drain. See `~/git/use-url-query/sandbox/ORCHESTRATION.md`.

## Demo-api measure

Prefer exclusive sandbox when available for the API. Otherwise host-card `workspace`:

```bash
php artisan test --compact --coverage --min=100 \
  --coverage-filter=<app/relative/path.php> \
  <via-test-path>
```

Score only in-scope hunks. Do not require 100% of an untouched fat file.

## Warm pool

`N = min(remaining, 4)` (or `2` if RAM tight). Parent writes ledger; destroy pool when drain ends.
