# Implement (use-url-query)

Implement `{{ feature }}` with **TDD**.

No cards, no board moves, no PRs. Work on `main` in the affected clone(s). Shared rules: `~/git/use-url-query/prompts/workflow-policy.md`.

If Docker, bun, or other assumed tooling fails: stop, report, wait for `resolva` / `documente` / `resolva permanentemente`.

## 1. Context

1. Treat `{{ feature }}` as the source of truth for intended behavior.
2. Inspect the relevant code, tests, and conventions in `~/git/use-url-query/use-url-query`.
3. Prefer the smallest change that satisfies the feature. Do not expand scope.

## 2. Git

1. `git status` / `git diff` in each affected repo. Preserve unrelated local work.
2. Stay on `main` (or report if the tree is not safe to continue).
3. `git pull --ff-only` when the working tree allows it. Stop on divergence.

Do **not** create a feature branch or a pull request.

## 3. TDD

1. Short plan: expected behavior, test files, production files.
2. **Red:** write or update a behavioral test that fails for the right reason. Run it inside Docker:

```bash
docker compose exec use-url-query bun test
```

3. **Green:** smallest production change that makes the test pass. Follow naming helpers in the clone README (`add…` / `clear…` / `get…` / …).
4. **Refactor** if needed; keep tests green.
5. **Static analysis:** `docker compose exec use-url-query bun run build` (`tsc`).
   - New contract/edge from typing → new **Red** test (or `expectTypeOf`) before more production code.
   - Pure type error → fix types/code, re-run `tsc` + tests.
6. Re-run the narrow suite, then the full suite before hand-off.

Do **not** implement production behavior without a prior red test (except an explicit user-requested throwaway spike).

## 4. Hand off

When TDD is green and `tsc` + suite pass:

- If `src/` changed → recommend `~/git/use-url-query/prompts/coverage-testing.md`, then `mutation-testing.md` (required; no auto-skip).
- Otherwise → recommend `~/git/use-url-query/prompts/pre-deploy.md`.

Do **not** commit or push unless the user asks, or unless they explicitly run `pre-deploy` / ask to ship.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run the next recommended prompt. |
| `try again` | Resume this prompt from the blocked step. |
