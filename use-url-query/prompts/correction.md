# Correction (use-url-query)

Fix production (or pre-deploy) findings for `{{ feature }}`.

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

## 3. Fix

1. Reproduce or confirm each finding when possible.
2. Implement the minimal fix; update tests so the defect would fail if reintroduced.
3. Re-run the narrowest tests that cover the change (`bun test`).

## 4. Hand off

Recommend `~/git/use-url-query/prompts/pre-deploy.md` (`bun test`, `bun run build`, then commit + push). After ship, recommend `production-review.md` again for `{{ feature }}`.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run `pre-deploy.md`. |
| `try again` | Resume correction from the blocked finding. |
