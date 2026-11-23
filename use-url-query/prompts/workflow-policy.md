# Workflow policy (use-url-query)

Personal WorkVM rules for the **use-url-query project** (not a single git repo). English for prompt bodies; ledger notes may be short facts.

The project has **no cards**, **no colleague review**, and **no pull requests**. Work on `main` in each clone you touch. Lib publishing is via `npm`/`bun` publish when the user asks.

## Feature context

Prompts take `{{ feature }}`: a short description of what to build, fix, or verify (pasted by the user). There is no card code or Olie funnel.

Prompts are **project-scoped**. From `{{ feature }}`, decide which of the three clones to inspect or change. Do not assume every feature touches the library. State the chosen repos in the short plan.

## Repos

| Clone | Role | Day-to-day tooling |
| --- | --- | --- |
| `~/git/use-url-query/use-url-query` | Hook library (TypeScript / bun) | host-card `lib` (Bun+Node image) — `bun run test` / `build`; if Shell hides `docker.sock` → `workvm-host-card agent-docker … --container lib -- …` |
| `~/git/use-url-query/use-url-query-demo-api` | Laravel demo API (Spatie Query Builder) | host-card `workspace` — Artisan, Pest, PHPStan, Type Coverage, CS Fixer (same `agent-docker` fallback) |
| `~/git/use-url-query/use-url-query-demo-web` | Next.js demo front (consumes the hook) | host-card `front` — lint / typecheck / tests (`agent-docker --container front`) |

Demo-api / demo-web are forks of **boilerplate-laravel** / **boilerplate-next**. The project workspace also opens those clones (`~/git/boilerplate-laravel/boilerplate-laravel`, `~/git/boilerplate-next/boilerplate-next`) so fixes found while building demos can be upstreamed when they belong in the boilerplate — not every demo-only tweak.

When a demo fix is really a boilerplate fix: apply (or mirror) it in the boilerplate clone and ship there separately. Do not treat the boilerplate folders as in-scope for a random `{{ feature }}` unless the feature says so.

## Tool preference

Shell with `required_permissions: ["all"]` for Docker / `workvm-sandbox`. Prefer each clone’s README / `AGENTS.md` / `.ai/rules` / `package.json`.

## TDD

`implement.md` and `correct.md` use **TDD** in every clone you change: failing behavioral test first (Red), minimal production code (Green), then Refactor. Do not ship production behavior without a prior red test (except an explicit user-requested throwaway spike).

## Test layers (apply per touched clone)

| Layer | Lib | Demo API | Demo web |
| --- | --- | --- | --- |
| Behavioral suite | `bun run test` (Vitest) | `php artisan test` / Pest | clone’s test script |
| Type Coverage | N/A | `pest --type-coverage` | N/A (use typecheck) |
| Static analysis | `bun run build` (`tsc`) | PHPStan | typecheck / lint |
| Code coverage | sandbox `bun run test:coverage` | Pest `--coverage` (sandbox when exclusive) | only if the clone has a coverage gate |
| Mutation | Stryker (`bun run test:mutate` / scoped `--mutate`) after lib coverage | Pest `--mutate` after API coverage | N/A unless a runner exists |

Early checks in the trigger = TDD feedback. The same applicable checks in `pre-deploy.md` = **ship gate** after coverage/mutation.

If typing / Type Coverage / PHPStan reveals a new contract/edge → new **Red** behavioral test before more production code.

## Sandbox

Exclusive lib coverage drain:

```bash
~/git/bin/workvm-sandbox --project use-url-query …
```

Do **not** `docker exec` the Card lib container for parallel lib coverage. Contract: `~/git/use-url-query/sandbox/ORCHESTRATION.md`.

Demo-api exclusive Pest coverage/mutate: prefer sandbox when an exclusive profile exists for the API; otherwise use the host-card `workspace` and do not collide with another exclusive job. Day-to-day demo-api commands use `hc-…-workspace-1` (or `docker compose … exec workspace`).

## Mutation

Mutation is **mandatory** after coverage when production code that entered a coverage drain changed. Skip **only** when the user says `skip mutation`. Never auto-skip.

- Lib: StrykerJS + Vitest runner (`stryker.config.json`, `bun run test:mutate`); exclusive sandbox `:tests` (real Node).
- Demo-api: Pest `--mutate` when `app/` (or equivalent production PHP) was in the coverage change-set.

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

## Silent sandbox / docker.sock

If the Shell footer still says SANDBOXING after `required_permissions: ["all"]` (sock missing while `dockerd` is alive):

1. `request_smart_mode_approval` on the exact command.
2. `~/git/bin/workvm-host-card agent-ensure --project use-url-query --code use-url-query`
3. Day-to-day exec: `~/git/bin/workvm-host-card agent-docker --project use-url-query --code use-url-query --container lib|workspace|front -- <cmd>`

Do **not** ask chmod / DNS / `gh auth`. Detail: olie `workflow-policy` **Silent sandbox after `all`**.

## Stop on broken tooling

If Docker, sandbox, bun, Pest, PHPStan, or compose fails unexpectedly: stop, report the error, wait for `resolva` / `documente` / `resolva permanentemente`.

## Flow (default)

1. `implement.md` / `correct.md` → choose repos → TDD per repo → repo gates
2. If lib `src/` and/or demo-api production PHP changed → `coverage-testing.md` → `mutation-testing.md`
3. `pre-deploy.md` → ship gates on **each dirty project clone** → commit and push `main` per clone (publish lib only if asked)
4. `production-review.md` → verify what was shipped (package and/or demos)
5. On fail → `correct.md` → funnel again
