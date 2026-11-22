# Correct (use-url-query project)

Fix production (or pre-deploy) findings for `{{ feature }}` with **TDD**.

No cards, no PRs. Shared rules: `~/git/use-url-query/prompts/workflow-policy.md`.

Project-scoped (lib + demo-api + demo-web). From the Fail report and `{{ feature }}`, decide which clones to change.

If tooling fails: stop, report, wait for `resolva` / `documente` / `resolva permanentemente`.

## 1. Context

1. Use `{{ feature }}` plus the Fail report from `production-review.md` (or a failed `pre-deploy` check) as the source of truth.
2. Do not treat the list as exhaustive — inspect related paths (and sibling demos/lib) for the same root cause.
3. Prefer fixing root causes over symptoms.

## 2. Git

1. Confirm `main` and a clean enough tree in each clone you will touch.
2. `git pull --ff-only` when safe.
3. No feature branches, no PRs.

## 3. TDD fix

1. **Red:** reproduce each finding with a failing behavioral test in the right clone.
2. **Green:** minimal production fix.
3. **Refactor** if needed; keep tests green.
4. Run that clone’s type / analysis gates (see workflow-policy). New contract → new **Red**.
5. Narrow then full suite for each changed clone.

## 4. Hand off

If lib `src/` and/or demo-api production PHP changed → recommend `coverage-testing.md`, then `mutation-testing.md` (required; no auto-skip), then `pre-deploy.md`.

Otherwise → recommend `pre-deploy.md`.

After ship, recommend `production-review.md` again for `{{ feature }}`.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run the next recommended prompt. |
| `try again` | Resume this prompt from the blocked finding. |
