# Olie

EnterScience product. Clones live under `~/git/olie/`.

| Repository | Working branch |
| --- | --- |
| `olie-fronts` | `develop` |
| `api-main` | `develop` |
| `backoffice` | `master` |
| `landing` | `develop` |
| `docker-workspace` | `master` |
| `websocket` | `develop` |

The stack starts from the compose at `olie`. Hosts are `*.olie.localhost` (`devframe`, `api`, `landing-page`, `mail`).

Workday order: `~/git/olie/prompts/workflow.md`.

## Required

- UI copy and user-facing project content are Brazilian Portuguese. Commit messages and pull request titles and bodies are English; see **Language** in `workflow-policy/host.md`.
- Do not edit `en.json` translation files. English strings are filled in later on a schedule. Add or update user-facing keys in `pt-br.json` only (and wire those keys in code).
- Do not post image, video, or audio analysis (or transcriptions) into project content. Save under `~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md` and reuse on correction; see `olie-project-image-analysis` and `olie-project-video-conversion`. **Commit/push** those files only in `pre-qa.md` §4.3 (or the closing meta step of colleague-review / production-review) — never during the media pass.
- PHP, Artisan, Composer, Pint, and `api-main` tests: `docker exec olie-api-main <command>`. Do not run `php` on the host.
- Frontend: Yarn 1 in `olie-fronts`. Do not use npm or `package-lock.json`.
- Playwright under the private suite (`olie-e2e` workspace folder on host-card, else `~/git/olie/olie-e2e`) is **owner-only**. Use the resolved in-workspace root; never cite it in card content, Caderno, company repos, or PR bodies — **Private E2E suites** in `workflow-policy/host.md`. (Locav may cite Cypress because it ships in `locav-front`.)
- A rule that exists in only one repository (tenant, permissions, an internal package) is not copied here.
- If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared modules: `workflow-policy/tools.md` (MCP auth / tooling failures) · index `workflow-policy.md`.

## Out of scope

Do not change the shared `~/git` meta-repo to finish a task for this product (except `olie/cards/` media analyses when the media skills require it, and the private Playwright suite when the card needs it — write under the resolved `olie-e2e` root, without citing that suite publicly). On host-card, that suite lives in the card’s meta worktree, not under `~/git/olie/olie-e2e` outside the workspace.
