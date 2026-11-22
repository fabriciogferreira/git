# Mutation testing (use-url-query)

Use when the change-set for `{{ feature }}` modified `~/git/use-url-query/use-url-query` `src/**/*` (after coverage). Shared rules: `~/git/use-url-query/prompts/workflow-policy.md`.

Mutation is **mandatory**. Do **not** auto-skip or jump to `pre-deploy.md`.

## Tooling

This package has **no** Pest/`--mutate` (or equivalent) runner today. Do **not** invent a mutation tool or run endless adversarial refactors under this prompt name.

## Entry

- **Default:** `correct mutations` / `next mutation` / recommended after `coverage-testing.md`.
- Report **Blocked**: no mutation runner available; list what would be in scope (changed tests / `src` modules).
- **Stop** and wait.
- Recommend `~/git/use-url-query/prompts/pre-deploy.md` **only** when:
  - the user explicitly says `skip mutation`, or
  - a real mutation runner exists and the ledger is done for this change-set.

## Ledger

`~/git/use-url-query/prompts/mutation-ledger.md`. On explicit skip, record a row such as `skipped | user: skip mutation | <sha>`. On Blocked with no skip yet, leave remaining work visible — do not stamp done.

### Chat commands

| Command | Do this |
| --- | --- |
| `correct mutations` / `next mutation` | Re-check for a runner; if still none → stay **Blocked**. |
| `skip mutation` | Record skip in the ledger, then run `pre-deploy.md`. |
| `try again` | Retry after the user adds a runner or clears the block. |
