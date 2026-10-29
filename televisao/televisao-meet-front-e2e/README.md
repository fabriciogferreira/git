# televisao-meet-front-e2e

Playwright E2E against `televisao-meet-front`. Lives in this meta-repo, not in the company remote, so a card can be checked in the browser without a manual pass.

## Run

```bash
# stack already up (televisao-api compose)
cd ~/git/televisao/televisao-api && docker compose up -d

./run.sh
./run.sh tests/meet.smoke.spec.ts
```

Smoke coverage in `tests/meet.smoke.spec.ts`:

- App shell loads (theme toggle on `/`)
- Guest meet room `/meet/:id` shows join UI (name field, camera preview controls)
- Participant name field accepts input on the join form

Container uses `network_mode: host` so Chromium `localhost` matches
`VITE_API_BACKEND` / core URLs and the meet front on `:3001`.

Cursor Playwright MCP (`workvm-playwright-mcp.sh televisao-meet-front-e2e`) needs
this compose up (`restart: unless-stopped`). The Televisão project boot brings
it up with the main stack; otherwise: `docker compose up -d`.

Optional overrides: copy `.env.example` → `.env`.
