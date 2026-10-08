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

TV-205 checkout in `tests/tv-205-checkout.smoke.spec.ts` (doctor seed):

- Post-consultation unified receita form + prévia + conclude actions
- Edit consultation keeps `returnTo=checkout`
- Light/dark WCAG AA contrast on checkout chrome (paper preview stays light)

Requires `E2E_CHECKOUT_CONSULTATION_ID` (ended consultation for `doctor1@doctor.test`).

Container uses `network_mode: host` so Chromium `localhost` matches
`NEXT_PUBLIC_API_URL` (`http://localhost:8000`) and the front on `:3000`.

Cursor Playwright MCP (`docker exec televisao-front-e2e …`) needs this
compose up (`restart: unless-stopped`). The Televisão `start.sh` brings it up
with the main stack; otherwise: `docker compose up -d`.

## Defaults

`super@super.super` / `password` (`UserSeeder` local factory password).

Optional overrides: copy `.env.example` → `.env`.
