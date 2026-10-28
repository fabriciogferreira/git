# Locav

EnterScience product. Clones live under `~/git/locav/`.

| Repository | Working branch |
| --- | --- |
| `LocavApi` | `preview` |
| `locav-front` | `preview` |

The stack starts from the compose at `~/git/locav/LocavApi`. Containers: `locav-backend` (Laravel Sail), `locav-frontend` (Bun / Next.js). Hosts: `http://localhost` (API, default port 80) and `http://localhost:3000` (front). Wait URL: `http://localhost/api/hello`. Production: `https://locav.enterscience.com.br/`.

Workday order: `~/git/locav/prompts/workflow.md`.

## Required

- UI copy and user-facing project content are Brazilian Portuguese. Commit messages and pull request titles are English. The pull request body is the filled `.github/pull_request_template.md` of that repository; see `~/git/locav/prompts/workflow-policy.md`.
- Do not post image, video, or audio analysis (or transcriptions) into project content. Save under `~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md`, **commit/push on the meta-repo** `~/git`, and reuse on correction; see `locav-project-image-analysis` and `locav-project-video-conversion`.
- PHP, Artisan, Composer, PHP CS Fixer, and `LocavApi` tests: `docker exec -w /var/www/html locav-backend <command>`. Do not run `php` on the host. Format with `./vendor/bin/php-cs-fixer fix` (config `.php-cs-fixer.php`). Same idea as Olie Pint: only in pre-QA (or when asked), and formatting-only changes go in a dedicated commit.
- `LocavApi` dev dependencies include Pest 4 (`pestphp/pest:^4.0`, `pestphp/pest-plugin-mutate:^4.0`) and PHPUnit 12 (`phpunit/phpunit:^12.5`) on PHP 8.3. Existing tests are still PHPUnit classes. New tests, and any PHPUnit test file a change edits, are written in Pest 4. Convert that file with Drift, not by rewriting the class by hand: inside `locav-backend`, `vendor/bin/pest --drift <that-file>`. If `pestphp/pest-plugin-drift` is missing, `composer require pestphp/pest-plugin-drift:^4.1 --dev --no-interaction`. Do not install Drift 5. Do not pass `tests/`. Drift does not convert every case; finish only the leftovers in that file by hand and say what remained. Do not convert `tests/` files the change does not touch. Traits and helpers that are not test cases stay until a test that uses them is converted. Pest 5 needs PHP 8.4. Do not bump PHP or PHPUnit to install it now. When the PHP version is raised, try Pest 5. Personal mutation testing is `~/git/locav/prompts/mutation-testing.md`. Do not add that workflow to CI, Dockerfiles, or compose.
- Frontend: Bun in `locav-front` (container `locav-frontend`). Prefer Bun over npm; do not introduce `package-lock.json` when the repo uses `bun.lock`.
- E2E: Cypress under `~/git/locav/locav-front/cypress`. Run it on the host with **Running Cypress** in `~/git/locav/prompts/workflow-policy.md`. The Alpine `locav-frontend` image cannot start the Cypress binary. When a change touches `locav-front`, create or edit specs in `cypress/e2e` for the frontend behavior that change introduces or alters. Extend an existing spec when it already covers that flow. The specs ship on the same `locav-front` branch as the UI change.
- A rule that exists in only one repository (permissions, an internal package) is not copied here.
- If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/locav/prompts/workflow-policy.md`.

## Out of scope

Do not change the `~/git` meta-repo to finish a task for this product (except `locav/cards/` media analyses when the media skills require it).
