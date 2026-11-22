# Workflow policy (Opbed)

Personal WorkVM rules for Opbed. English for prompt bodies; ledger notes may be short facts.

Opbed has **no cards**, **no colleague review**, and **no pull requests**. Work on `main`. Every push to `main` deploys (GitHub Actions → Coolify).

## Feature context

Prompts take `{{ feature }}`: a short description of what to build, fix, or verify (pasted by the user). There is no card code or Olie funnel.

## Repos

| Clone | Role |
| --- | --- |
| `~/git/opbed/opbed-backend` | Laravel API (Artisan inside Docker `backend`) |
| `~/git/opbed/opbed-frontend` | Next.js UI |

## Tool preference

Shell with `required_permissions: ["all"]` for Docker / `workvm-sandbox`. Prefer project conventions in each clone’s `AGENTS.md` / `.ai/rules`.

## TDD

`implement.md` and `correct.md` use **TDD**: failing behavioral test first (Red), minimal production code (Green), then Refactor. Do not ship production behavior without a prior red test (except an explicit user-requested throwaway spike).

## Test layers

| Layer | Tool | Role |
| --- | --- | --- |
| Behavioral suite | `php artisan test` / Pest (feature, unit, arch, …) | TDD cycle + ship gate |
| Type Coverage | `./vendor/bin/pest --type-coverage` ([pest-plugin-type-coverage](https://github.com/pestphp/pest-plugin-type-coverage)) | Declaration completeness (`pa` / `rt` / `pr`); early + ship gate `--min=100` |
| Static analysis | PHPStan | Types correct; early + ship gate |
| Code coverage | Pest/PHPUnit `--coverage` via sandbox | Drain (`coverage-testing.md`) |
| Mutation | Pest `--mutate` via sandbox | Drain (`mutation-testing.md`); **no auto-skip** |

Type Coverage does **not** require new tests — add missing declarations (or `@pest-ignore-type` only when justified). If typing narrows a contract → new **Red** behavioral test first.

Early Type Coverage / PHPStan / suite in the trigger = TDD feedback. The same checks in `pre-deploy.md` = **ship gate** after coverage/mutation may have changed the tree. PHP CS Fixer runs at pre-deploy only.

## Sandbox (mutation / coverage only)

Exclusive Pest mutate/coverage must use:

```bash
~/git/bin/workvm-sandbox --project opbed …
```

Do **not** `docker exec hc-opbed-*-backend-1` for mutate/coverage. Contract: `~/git/opbed/sandbox/ORCHESTRATION.md`.

Day-to-day `php artisan test`, Type Coverage, PHPStan, and PHP CS Fixer run on the normal local compose (`docker compose exec backend …` or the running host-card backend if that is the active stack).

## Pest TIA (local)

Owned clone: `tests/Pest.php` has `pest()->tia()->locally()` + `directory('.pest/tia')`; `/.pest/` is gitignored; backend image includes `git` (+ PCOV). **Full-suite gates** (`pre-deploy`) pass `--ci`. Opt out once: `--no-tia`. Sandbox compose also sets `PEST_TIA_LOCALLY=1` as belt-and-suspenders.

## Mutation

Mutation is **mandatory** after coverage when backend changed. Skip **only** when the user explicitly says `skip mutation`. Never auto-skip (including “no backend file touched” guesses — if `mutation-testing.md` was recommended, complete it or wait for explicit skip).

## Chat commands

| Command | Meaning |
| --- | --- |
| `next prompt` | Open and run the next recommended prompt file. |
| `try again` | Retry the current prompt / last failed check. |
| `to correct` | After production review **Fail**: implement listed fixes, then continue the funnel. |
| `correct mutations` / `next mutation` | Mutation drain (see `mutation-testing.md`). |
| `correct coverages` / `next coverage` | Coverage drain (see `coverage-testing.md`). |
| `skip mutation` | Explicit only: mark mutation skipped for this change-set, then `pre-deploy.md`. |
| `resolva` / `documente` / `resolva permanentemente` | Stop-on-broken-tooling (meta-repo rule). |

## Stop on broken tooling

If Docker, sandbox, Pest, Type Coverage, PHPStan, or CS Fixer fails unexpectedly: stop, report the error, wait for `resolva` / `documente` / `resolva permanentemente`.

## Flow (default)

1. `implement.md` / `correct.md` → TDD for `{{ feature }}` (Red → Green → Refactor → Type Coverage → PHPStan → suite)
2. When backend `app/` changed → `coverage-testing.md` → `mutation-testing.md`
3. `pre-deploy.md` → suite + Type Coverage `--min=100` + PHPStan + PHP CS Fixer → **commit and push `main`** (deploy)
4. `production-review.md` → verify live
5. On fail → `correct.md` → funnel again
