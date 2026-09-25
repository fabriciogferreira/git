# olie-e2e

Playwright E2E against management. Outside `olie-fronts` on purpose.

## Run (preferred — one stack)

```bash
cd ../docker-workspace && docker compose up -d
# olie-e2e stays up with the rest of the stack

# run tests:
docker compose exec e2e npx playwright test --project=chromium
# or from this repo:
./run.sh
./run.sh tests/auth.smoke.spec.ts
```

Dockerfile for the workspace build lives at `../docker-workspace/e2e/Dockerfile`
(keep in sync with this repo’s `Dockerfile`). Service definition:
`../docker-workspace/docker-compose.yml` (+ mirror `../docker-workspace/e2e/docker-compose.yml`).

## Standalone (optional)

```bash
# stack already up on docker-workspace_olie-network
docker compose up -d
./run.sh
```

Defaults: `tester@olie.ai` / `password` (api-main seed). Specs create their own project via `quick-store`.

## reCAPTCHA (local)

E2E stubs `grecaptcha` in the browser. `api-main` must skip validation in `local` / `testing`
(`AuthController::Login`) so login does not depend on Google from inside Docker.

## Feature gates (auto-skip)

Specs under `tests/features/` (and OS-505 logs-hide cases) call `requireFeature` /
`requireLogsFilterHidesMessage`. Missing UI on the running front → **skip**, not fail.

Optional overrides: copy `.env.example` → `.env`.
