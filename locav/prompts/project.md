# Locav

EnterScience product. Clones live under `~/git/locav/`.

| Repository | Working branch |
| --- | --- |
| `LocavApi` | `preview` |
| `locav-front` | `preview` |

The stack starts from the compose at `~/git/locav/LocavApi`. Containers: `locav-backend` (Laravel Sail), `locav-frontend` (Bun / Next.js). Hosts: `http://localhost` (API, default port 80) and `http://localhost:3000` (front). Wait URL: `http://localhost/api/hello`. Production: `https://locav.enterscience.com.br/`.

Workday order: `~/git/locav/prompts/workflow.md`.

## Required

- UI copy and user-facing project content are Brazilian Portuguese. Commit messages and pull request titles and bodies are English; see `~/git/locav/prompts/workflow-policy.md`.
- Do not post image, video, or audio analysis (or transcriptions) into project content. Save under `~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md`, **commit/push on the meta-repo** `~/git`, and reuse on correction.
- PHP, Artisan, Composer, Pint, and `LocavApi` tests: `docker exec locav-backend <command>`. Do not run `php` on the host.
- Frontend: Bun in `locav-front` (container `locav-frontend`). Prefer Bun over npm; do not introduce `package-lock.json` when the repo uses `bun.lock`.
- E2E: Cypress under `~/git/locav/locav-front/cypress` (`bun run test-ui` in that repo / container when needed).
- A rule that exists in only one repository (permissions, an internal package) is not copied here.
- If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Shared detail: `~/git/locav/prompts/workflow-policy.md`.

## Out of scope

Do not change the `~/git` meta-repo to finish a task for this product (except `locav/cards/` media analyses when needed).
