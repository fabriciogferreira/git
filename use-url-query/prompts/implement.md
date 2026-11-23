# Implement (use-url-query project)

Implement `{{ feature }}` with **TDD**.

No cards, no board moves, no PRs. Shared rules: `~/git/use-url-query/prompts/workflow-policy.md`.

This prompt is **project-scoped** (lib + demo-api + demo-web). From `{{ feature }}`, decide which clones to touch; name them in the plan. Work on `main` only in those clones.

If Docker, bun, Pest, or other assumed tooling fails: stop, report, wait for `resolva` / `documente` / `resolva permanentemente`.

## 1. Context

1. Treat `{{ feature }}` as the source of truth for intended behavior.
2. Map the feature to one or more of: library, demo-api, demo-web. Inspect only what you need.
3. Prefer the smallest change that satisfies the feature. Do not expand scope across repos “just in case”.

## 2. Git

1. `git status` / `git diff` in each clone you may change. Preserve unrelated local work.
2. Stay on `main` (or report if a tree is not safe to continue).
3. `git pull --ff-only` when the working tree allows it. Stop on divergence.

Do **not** create a feature branch or a pull request.

## 3. TDD (per chosen clone)

1. Short plan: repos, expected behavior, test files, production files.
2. **Red:** failing behavioral test for the right reason (tooling for that clone — see workflow-policy).
3. **Green:** smallest production change that passes.
4. **Refactor** if needed; keep tests green.
5. **Types / analysis for that clone:**
   - Lib: `bun run build` (`tsc`).
   - Demo-api: Type Coverage (`pest --type-coverage --compact`) then PHPStan when production PHP changed.
   - Demo-web: `npm run lint` and `npm run typecheck` (`tsc --noEmit`).
   - New contract/edge → new **Red** first.
6. Narrow suite, then full suite for each changed clone before hand-off.

Do **not** implement production behavior without a prior red test (except an explicit user-requested throwaway spike). Dependency-only installs still need a smoke assertion when feasible (e.g. class loads / route responds).

## 4. Hand off

When TDD and per-repo gates pass:

- If lib `src/` and/or demo-api production PHP (`app/` etc.) changed → recommend `~/git/use-url-query/prompts/coverage-testing.md`, then `mutation-testing.md` (required; no auto-skip).
- Otherwise → recommend `~/git/use-url-query/prompts/pre-deploy.md`.

Do **not** commit or push unless the user asks, or unless they explicitly run `pre-deploy` / ask to ship.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run the next recommended prompt. |
| `try again` | Resume this prompt from the blocked step. |
