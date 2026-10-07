# televisao-meet-front-e2e

Playwright E2E against `televisao-meet-front`. Outside that repo on purpose (local/meta only).

## Run

```bash
# stack already up (televisao-api compose)
cd ../televisao-api && docker compose up -d

cd ../televisao-meet-front-e2e
./run.sh
./run.sh tests/meet.smoke.spec.ts
```

Smoke coverage in `tests/meet.smoke.spec.ts`:

- App shell loads (theme toggle on `/`)
- Guest meet room `/meet/:id` shows join UI (name field, camera preview controls)
- Participant name field accepts input on the join form

Container uses `network_mode: host` so Chromium `localhost` matches
`VITE_API_BACKEND` / core URLs and the meet front on `:3001`.

Optional overrides: copy `.env.example` → `.env`.
