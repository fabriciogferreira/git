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

Use StrykerJS + Vitest runner (`@stryker-mutator/core`, `@stryker-mutator/vitest-runner`) in the lib clone. Prefer exclusive sandbox (`workvm-sandbox --project use-url-query --profile tests`) so Card `bun`/Vitest jobs do not collide. Use **real Node** (sandbox `:tests` image), not Bun’s `node` fallback.

```bash
# Full suite (stryker.config.json: src/**/*.ts minus index)
bun run test:mutate

# Scoped (one file / glob from the ledger)
npx stryker run --mutate src/sorts.ts
npx stryker run --mutate 'src/use-url-query.ts'
```

Done = mutation score meets `thresholds.break` (100) for **in-scope** mutate globs, or survivors are `equivalent` after review. Kill killables by tightening tests (not production).

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
| `correct mutations` / `next mutation` | Continue the drain (Stryker lib and/or Pest API). |
| `skip mutation` | Record skip in the ledger, then run `pre-deploy.md`. |
| `try again` | Retry the blocked mutate / prepare step. |
