# Mutation testing (use-url-query project)

Use after coverage when the change-set for `{{ feature }}` modified lib `src/**/*` and/or demo-api production PHP. Shared rules: `~/git/use-url-query/prompts/workflow-policy.md`.

Mutation is **mandatory**. Do **not** auto-skip or jump to `pre-deploy.md`.

## Entry

- **Default:** `correct mutations` / `next mutation` / recommended after `coverage-testing.md`.
- Drain every remaining in-scope unit for this change-set (per clone below).
- Recommend `pre-deploy.md` only when the ledger is done **or** the user says `skip mutation`.

## Ledger

`~/git/use-url-query/prompts/mutation-ledger.md`. Note which clone each row belongs to. On explicit skip: `skipped | user: skip mutation | <sha>`.

## Lib

No Pest/`--mutate` (or equivalent) runner today. For lib rows: report **Blocked**, list in-scope modules/tests, **stop**. Do **not** invent a mutation tool. Clear lib Blocked only with a real runner or `skip mutation`.

## Demo-api

Use Pest mutate on changed `*Test.php` / `--class` FQCNs in scope (host-card `workspace` or exclusive sandbox when available):

```bash
php -d memory_limit=2G vendor/bin/pest --mutate --covered-only --min=100 \
  --ignore-min-score-on-zero-mutations --parallel \
  '--class=App\…' \
  <test-path>
```

Done = `100%` or `equivalent` for **in-scope** mutations. Kill killables by tightening tests (not production).

## Close

When all clone rows for this change-set are done (or explicitly skipped) → recommend `~/git/use-url-query/prompts/pre-deploy.md`.

### Chat commands

| Command | Do this |
| --- | --- |
| `correct mutations` / `next mutation` | Continue the drain (or re-check lib Blocked). |
| `skip mutation` | Record skip in the ledger, then run `pre-deploy.md`. |
| `try again` | Retry the blocked mutate / prepare step. |
