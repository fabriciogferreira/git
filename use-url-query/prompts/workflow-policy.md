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

## TDD

`implement.md` and `correct.md` use **TDD**: failing behavioral test first (Red), minimal production code (Green), then Refactor. Do not ship production behavior without a prior red test (except an explicit user-requested throwaway spike).

## Test layers

| Layer | Tool | Role |
| --- | --- | --- |
| Behavioral suite | `bun test` (unit / feature / …) | TDD cycle + ship gate |
| Static analysis | `bun run build` (`tsc`) | Types correct; early feedback + ship gate |
| Type Coverage (Pest) | N/A (not PHP) | — |
| Code coverage | `bun test --coverage` via sandbox | Drain after TDD (`coverage-testing.md`) |
| Mutation | Required step after coverage | Drain (`mutation-testing.md`); **no auto-skip** |

Early `tsc` / suite in the trigger = TDD feedback. The same checks in `pre-deploy.md` = **ship gate** after coverage/mutation may have changed the tree.

If `tsc` (or typing) reveals a new contract/edge: write a **new failing behavioral test** (or type-level assert such as `expectTypeOf`) before more production code.

## Sandbox (coverage drain)

Exclusive coverage drain must use:

```bash
~/git/bin/workvm-sandbox --project use-url-query …
```

Do **not** `docker exec` the Card `use-url-query` container for parallel coverage. Contract: `~/git/use-url-query/sandbox/ORCHESTRATION.md`.

Day-to-day `bun test` and `bun run build` run on the normal local compose (`docker compose exec use-url-query …` or the running host-card service).

## Mutation

Mutation is **mandatory** after coverage when production `src/` changed. There is currently **no** Pest/`--mutate` runner in this package — `mutation-testing.md` reports **Blocked** and waits. Go to `pre-deploy.md` only when mutation is done **or** the user explicitly says `skip mutation`. Never auto-skip.

## Chat commands

| Command | Meaning |
| --- | --- |
| `next prompt` | Open and run the next recommended prompt file. |
| `try again` | Retry the current prompt / last failed check. |
| `to correct` | After production review **Fail**: implement listed fixes, then continue the funnel. |
| `correct coverages` / `next coverage` | Coverage drain (see `coverage-testing.md`). |
| `correct mutations` / `next mutation` | Mutation drain (see `mutation-testing.md`). |
| `skip mutation` | Explicit only: mark mutation skipped for this change-set, then `pre-deploy.md`. |
| `resolva` / `documente` / `resolva permanentemente` | Stop-on-broken-tooling (meta-repo rule). |

## Stop on broken tooling

If Docker, sandbox, or bun fails unexpectedly: stop, report the error, wait for `resolva` / `documente` / `resolva permanentemente`.

## Flow (default)

1. `implement.md` / `correct.md` → TDD for `{{ feature }}` (Red → Green → Refactor → `tsc` → suite)
2. When `src/` changed → `coverage-testing.md` → `mutation-testing.md` (Blocked until tool exists or `skip mutation`)
3. `pre-deploy.md` → `bun test` + `bun run build` → **commit and push `main`** (publish only if the user asks)
4. `production-review.md` → verify published package / main tip
5. On fail → `correct.md` → funnel again
