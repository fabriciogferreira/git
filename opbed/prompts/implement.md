# Implement (Opbed)

Implement `{{ feature }}` with **TDD**.

No cards, no board moves, no PRs. Work on `main` in the affected clone(s). Shared rules: `~/git/opbed/prompts/workflow-policy.md`.

If Docker, Artisan, or other assumed tooling fails: stop, report, wait for `resolva` / `documente` / `resolva permanentemente`.

## 1. Context

1. Treat `{{ feature }}` as the source of truth for intended behavior.
2. Inspect the relevant code, tests, and conventions in `opbed-backend` and/or `opbed-frontend`.
3. Prefer the smallest change that satisfies the feature. Do not expand scope.

## 2. Git

1. `git status` / `git diff` in each affected repo. Preserve unrelated local work.
2. Stay on `main` (or report if the tree is not safe to continue).
3. `git pull --ff-only` when the working tree allows it. Stop on divergence.

Do **not** create a feature branch or a pull request.

## 3. TDD

1. Short plan: expected behavior, test files, production files.
2. **Red:** write or update a behavioral test that fails for the right reason. Backend Pest/Artisan inside Docker `backend` (project Environment rules).
3. **Green:** smallest production change that makes the test pass. Follow each repo’s `AGENTS.md` / `.ai/rules` / skills.
4. **Refactor** if needed; keep tests green.
5. **Backend — Type Coverage** (when `opbed-backend` production PHP changed):

```bash
docker compose exec backend ./vendor/bin/pest --type-coverage --compact
```

Complete missing `pa` / `rt` / `pr` declarations in the change-set. Use `@pest-ignore-type` only when justified. If typing narrows a contract → new **Red** first.

6. **Static analysis (backend):**

```bash
docker compose exec backend vendor/bin/phpstan analyse --memory-limit=1G
```

New edge from analysis → new **Red** first. Pure type error → fix and re-run PHPStan + tests.

7. Frontend (if changed): follow that clone’s typecheck / tests after the same Red → Green rule.
8. Re-run the narrow suite, then the full backend suite (`php artisan test --compact`) before hand-off.

Do **not** implement production behavior without a prior red test (except an explicit user-requested throwaway spike).

## 4. Hand off

When TDD is green and Type Coverage / PHPStan / suite pass:

- If `opbed-backend` `app/` changed → recommend `~/git/opbed/prompts/coverage-testing.md`, then `mutation-testing.md` (required; no auto-skip).
- Otherwise → recommend `~/git/opbed/prompts/pre-deploy.md`.

Do **not** commit or push unless the user asks, or unless they explicitly run `pre-deploy` / ask to ship.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run the next recommended prompt. |
| `try again` | Resume this prompt from the blocked step. |
