# Workflow policy (use-url-query)

Personal WorkVM rules for use-url-query. English for prompt bodies; ledger notes may be short facts.

use-url-query has **no cards**, **no colleague review**, and **no pull requests**. Work on `main`. Publishing is via `npm`/`bun` publish from the package when the user asks (not an automatic deploy.yml in this repo unless one appears later).

## Feature context

Prompts take `{{ feature }}`: a short description of what to build, fix, or verify (pasted by the user). There is no card code or Olie funnel.

## Repos

| Clone | Role |
| --- | --- |
| `~/git/use-url-query/use-url-query` | TypeScript + Next hook library (`bun test`, `bun run build`) |

## Tool preference

Shell with `required_permissions: ["all"]` for Docker / `workvm-sandbox`. Prefer conventions in the clone’s README / `package.json`.

## Sandbox (coverage drain)

Exclusive coverage drain must use:

```bash
~/git/bin/workvm-sandbox --project use-url-query …
```

Do **not** `docker exec` the Card `use-url-query` container for parallel coverage. Contract: `~/git/use-url-query/sandbox/ORCHESTRATION.md`.

Day-to-day `bun test` and `bun run build` run on the normal local compose (`docker compose exec use-url-query …` or the running host-card service).

## Mutation

This package has **no** Pest/Infection mutate. `mutation-testing.md` is a skip step — go to `pre-deploy.md`.

## Chat commands

| Command | Meaning |
| --- | --- |
| `next prompt` | Open and run the next recommended prompt file. |
| `try again` | Retry the current prompt / last failed check. |
| `to correct` | After production review **Fail**: implement listed fixes, then `pre-deploy`. |
| `correct coverages` / `next coverage` | Coverage drain (see `coverage-testing.md`). |
| `correct mutations` / `next mutation` | No-op skip → `pre-deploy` (see `mutation-testing.md`). |
| `resolva` / `documente` / `resolva permanentemente` | Stop-on-broken-tooling (meta-repo rule). |

## Stop on broken tooling

If Docker, sandbox, or bun fails unexpectedly: stop, report the error, wait for `resolva` / `documente` / `resolva permanentemente`.

## Flow (default)

1. `implementation.md` → build `{{ feature }}`
2. Optional: `coverage-testing.md` when `src/` changed; `mutation-testing.md` is skip
3. `pre-deploy.md` → `bun test` + `bun run build` → **commit and push `main`** (publish only if the user asks)
4. `production-review.md` → verify published package / main tip
5. On fail → `correction.md` → `pre-deploy.md` again
