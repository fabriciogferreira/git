# Implementation (boilerplate-laravel)

Implement `{{ feature }}`.

No cards, no board moves, no PRs. Work on `main` in the affected clone(s). Shared rules: `~/git/boilerplate-laravel/prompts/workflow-policy.md`.

If Docker, Artisan, or other assumed tooling fails: stop, report, wait for `resolva` / `documente` / `resolva permanentemente`.

## 1. Context

1. Treat `{{ feature }}` as the source of truth for intended behavior.
2. Inspect the relevant code, tests, and conventions in `~/git/boilerplate-laravel/boilerplate-laravel`.
3. Prefer the smallest change that satisfies the feature. Do not expand scope.

## 2. Git

1. `git status` / `git diff` in each affected repo. Preserve unrelated local work.
2. Stay on `main` (or report if the tree is not safe to continue).
3. `git pull --ff-only` when the working tree allows it. Stop on divergence.

Do **not** create a feature branch or a pull request.

## 3. Plan then implement

1. Short plan: files to touch, behavior, tests to add/update.
2. Implement. Follow each repo’s `AGENTS.md` / `.ai/rules` / skills.
3. Backend Artisan and Pest: inside the Docker `workspace` service (see project Environment rules).
4. Add or update tests for the changed behavior and important failure modes.

## 4. Hand off

When the feature works locally and targeted tests pass:

- If `boilerplate-laravel` `app/` changed → recommend `~/git/boilerplate-laravel/prompts/coverage-testing.md`, then `mutation-testing.md`.
- Otherwise → recommend `~/git/boilerplate-laravel/prompts/pre-deploy.md`.

Do **not** commit or push unless the user asks, or unless they explicitly run `pre-deploy` / ask to ship.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run the next recommended prompt. |
| `try again` | Resume this implementation from the blocked step. |
