# televisao-front-e2e

Playwright E2E against `televisao-front`. Outside that repo on purpose (local/meta only).

## Run

```bash
# stack already up (televisao-api compose)
cd ../televisao-api && docker compose up -d

cd ../televisao-front-e2e
./run.sh
./run.sh tests/auth.smoke.spec.ts
```

Auth coverage in `tests/auth.smoke.spec.ts`:

- Login page heading, empty-field validation, invalid credentials toast
- Successful login (seed `super@super.super` / `password`) → `/dashboard`
- Clinic / doctor signup links and forgot-password link
- Logout back to `/login`

TV-205 checkout:

- `tests/tv-205-checkout.flow.spec.ts` — end-to-end: land on checkout → edit
  consultation (`returnTo=checkout`) → create receita → conclude → reopen
- `tests/tv-205-checkout.smoke.spec.ts` — lighter UI/contrast smoke

`./run.sh` seeds a fresh ended consultation for `doctor1@doctor.test` via
`scripts/seed-ended-consultation.sh` (override with `E2E_CHECKOUT_CONSULTATION_ID`,
disable reseed with `E2E_SEED_CHECKOUT=0`).

Signing with Autentique is out of scope for local E2E (external provider).

Container uses `network_mode: host` so Chromium `localhost` matches
`NEXT_PUBLIC_API_URL` (`http://localhost:8000`) and the front on `:3000`.

Cursor Playwright MCP (`docker exec televisao-front-e2e …`) needs this
compose up (`restart: unless-stopped`). The Televisão `start.sh` brings it up
with the main stack; otherwise: `docker compose up -d`.

## Defaults

`super@super.super` / `password` (`UserSeeder` local factory password).

Optional overrides: copy `.env.example` → `.env`.
