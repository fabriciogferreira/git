# Correct (use-url-query)

Fix production (or pre-deploy) findings for `{{ feature }}` with **TDD**.

No cards, no PRs. Work on `main`. Shared rules: `~/git/use-url-query/prompts/workflow-policy.md`.

If tooling fails: stop, report, wait for `resolva` / `documente` / `resolva permanentemente`.

## 1. Context

1. Use `{{ feature }}` plus the Fail report from `production-review.md` (or a failed `pre-deploy` check) as the source of truth.
2. Do not treat the list as exhaustive — inspect related paths for the same root cause.
3. Prefer fixing root causes over symptoms.

## 2. Git

1. Confirm `main` and a clean enough tree to work.
2. `git pull --ff-only` when safe.
3. No feature branches, no PRs.

## 3. TDD fix

1. **Red:** reproduce each finding with a failing behavioral test (or confirm an existing failing test).
2. **Green:** minimal production fix so the test passes.
3. **Refactor** if needed; keep tests green.
4. **Static analysis:** `bun run build` (`tsc`). New contract from typing → new **Red** first.
5. Re-run the narrowest tests, then the full suite before hand-off.

## 4. Hand off

When production `src/` changed → recommend `~/git/use-url-query/prompts/coverage-testing.md`, then `mutation-testing.md` (required; no auto-skip), then `pre-deploy.md`.

Otherwise → recommend `~/git/use-url-query/prompts/pre-deploy.md`.

After ship, recommend `production-review.md` again for `{{ feature }}`.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run the next recommended prompt. |
| `try again` | Resume this prompt from the blocked finding. |
