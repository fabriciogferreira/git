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

- UI copy and user-facing project content are Brazilian Portuguese. Commit messages and pull request titles and bodies are English; see `~/git/olie/prompts/workflow-policy.md`.
- Do not edit `en.json` translation files. English strings are filled in later on a schedule. Add or update user-facing keys in `pt-br.json` only (and wire those keys in code).
- Do not post image, video, or audio analysis (or transcriptions) into project content. Save under `~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md`, **commit/push on the meta-repo** `~/git`, and reuse on correction; see `olie-project-image-analysis` and `olie-project-video-conversion`.
- PHP, Artisan, Composer, Pint, and `api-main` tests: `docker exec olie-api-main <command>`. Do not run `php` on the host.
- Frontend: Yarn 1 in `olie-fronts`. Do not use npm or `package-lock.json`.
- A rule that exists in only one repository (tenant, permissions, an internal package) is not copied here.
- If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

## Out of scope

Do not change the `~/git` meta-repo to finish a task for this product (except `olie/cards/` media analyses when the media skills require it).
