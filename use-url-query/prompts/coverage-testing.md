# Coverage testing (use-url-query)

Use when the change-set for `{{ feature }}` modified `~/git/use-url-query/use-url-query` `src/**/*`. Measures **in-scope (diff) lines**, not suite Total %.

**Must** use sandbox for drain/parallel:

```bash
~/git/bin/workvm-sandbox create --name <id> --project use-url-query --profile tests --from-commit <tip>
~/git/bin/workvm-sandbox job run <id> --service backend -- <command>
```

Do **not** `docker exec` the Card/host bun container for coverage drain. See `~/git/use-url-query/sandbox/ORCHESTRATION.md`.

## Entry

- **Default:** `correct coverages` — drain remaining production files (warm pool + Task).
- **`next coverage`:** one file when the user asks.
- When complete → recommend `mutation-testing.md` (required; no auto-skip).

## Ledger

`~/git/use-url-query/prompts/coverage-ledger.md`. Done when in-scope lines are covered. Stamp `sha:` via `~/git/bin/workvm-ledger-sha.sh` when closing.

## Measure

```bash
~/git/bin/workvm-sandbox job run <id> --service backend -- \
  bun test --coverage
```

Score only in-scope hunks from the change-set under `src/`. Do not require 100% of an untouched fat file. Prefer adding/narrowing tests under `tests/` that exercise the changed lines.

## Warm pool

`N = min(remaining, 4)` (or `2` if RAM tight). Parent writes ledger; destroy pool when drain ends.
