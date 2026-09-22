# olie-e2e

Playwright E2E against management. Outside `olie-fronts` on purpose.

## Run (no Node on host)

```bash
cd ../docker-workspace && docker compose up -d
cd ../olie-e2e
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
