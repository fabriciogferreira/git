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

## Sandbox (mutation / coverage only)

Exclusive Pest mutate/coverage must use:

```bash
~/git/bin/workvm-sandbox --project opbed …
```

Do **not** `docker exec hc-opbed-*-backend-1` for mutate/coverage. Contract: `~/git/opbed/sandbox/ORCHESTRATION.md`.

Day-to-day `php artisan test`, PHPStan, and PHP CS Fixer run on the normal local compose (`docker compose exec backend …` or the running host-card backend if that is the active stack).

## Chat commands

| Command | Meaning |
| --- | --- |
| `next prompt` | Open and run the next recommended prompt file. |
| `try again` | Retry the current prompt / last failed check. |
| `to correct` | After production review **Fail**: implement listed fixes, then `pre-deploy`. |
| `correct mutations` / `next mutation` | Mutation drain (see `mutation-testing.md`). |
| `correct coverages` / `next coverage` | Coverage drain (see `coverage-testing.md`). |
| `resolva` / `documente` / `resolva permanentemente` | Stop-on-broken-tooling (meta-repo rule). |

## Stop on broken tooling

If Docker, sandbox, Pest, PHPStan, or CS Fixer fails unexpectedly: stop, report the error, wait for `resolva` / `documente` / `resolva permanentemente`.

## Flow (default)

1. `implementation.md` → build `{{ feature }}`
2. Optional: `coverage-testing.md` → `mutation-testing.md` when backend `app/` changed
3. `pre-deploy.md` → tests + PHPStan + PHP CS Fixer → **commit and push `main`** (deploy)
4. `production-review.md` → verify live
5. On fail → `correction.md` → `pre-deploy.md` again
