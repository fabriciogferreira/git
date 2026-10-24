# Televisão

EnterScience product. Clones live under `~/git/televisao/`.

| Repository | Working branch |
| --- | --- |
| `televisao-api` | `preview` |
| `televisao-front` | `preview` |
| `televisao-meet-front` | `preview` |
| `televisao-meet-core` | `preview` |

The stack starts from the compose at `~/git/televisao/televisao-api`. PHP runs in `televisao-backend`. Hosts: `http://localhost:8000` (API; wait `http://localhost:8000/up`; docs `http://localhost:8000/docs`), `http://localhost:3000` (`televisao-front`), `http://localhost:3001` (`televisao-meet-front`). The production host comes from the card. Do not guess one.

Workday order: `~/git/televisao/prompts/workflow.md`.

## Required

- UI copy and user-facing project content are Brazilian Portuguese. Commit messages and pull request titles are English. The pull request body is the filled `.github/pull_request_template.md` of that repository; see `~/git/televisao/prompts/workflow-policy.md`.
- Do not post image, video, or audio analysis (or transcriptions) into project content. Save under `~/git/televisao/cards/{CARD_CODE}/{MEDIA_ID}.md`, **commit/push on the meta-repo** `~/git`, and reuse on correction; see `televisao-project-image-analysis` and `televisao-project-video-conversion`.
- PHP, Artisan, Composer, Pint, and `televisao-api` tests: `docker exec -w /var/www/html televisao-backend <command>`. Do not run `php` on the host.
- Use the test runner already installed in `televisao-backend`. When `vendor/bin/pest` exists, new tests and any test file this card edits are written with that Pest. Convert an edited PHPUnit file with Drift inside the container: `vendor/bin/pest --drift <that-file>`. Do not pass `tests/`. Do not convert files this card does not touch. If Pest or Drift is not already installed, stop and report. Do not `composer require` them and do not bump PHP to match another product. Personal mutation testing is `~/git/televisao/prompts/mutation-testing.md`. Do not add that workflow to CI, Dockerfiles, or compose.
- Frontends: `televisao-front` and `televisao-meet-front`. Use the package manager and lint script each repository already has. Do not introduce a second lockfile.
- E2E: Playwright in the meta-repo. `televisao-front` → `~/git/televisao/televisao-front-e2e`. `televisao-meet-front` → `~/git/televisao/televisao-meet-front-e2e`. Run with **Running Playwright** in `~/git/televisao/prompts/workflow-policy.md`. When a change touches one of those fronts, create or edit a spec in the matching suite. Extend an existing spec when it already covers that flow. Specs stay in the meta-repo; they do not ship on the company branch.
- A rule that exists in only one repository (permissions, an internal package) is not copied here.
- If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Shared detail: `~/git/televisao/prompts/workflow-policy.md`.

## Out of scope

Do not change the `~/git` meta-repo to finish a task for this product, except `televisao/cards/` media analyses and the Playwright suites `televisao/televisao-front-e2e/` and `televisao/televisao-meet-front-e2e/` when the card changes that front.
