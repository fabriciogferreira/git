# Olie

Adds to `prompts/agent.md`. Does not repeat it. A rule that belongs to one repository goes in `prompts/enterscience/olie/<repository>/`, and that folder wins over this file.

## Context

EnterScience product. Clones live under `~/git/olie/`.

| Repository | Working branch |
| --- | --- |
| `olie-fronts` | `develop` |
| `api-main` | `develop` |
| `backoffice` | `master` |
| `landing` | `develop` |
| `docker-workspace` | `master` |
| `websocket` | `develop` |

The stack starts from the compose at `projects/olie`. Hosts are `*.olie.localhost` (`devframe`, `api`, `landing-page`, `mail`).

The workday order is `workflow.md`.

## Required

- UI copy and user-facing project content are Brazilian Portuguese. Commit messages and pull request titles and bodies are English; see `workflow-policy.md`.
- PHP, Artisan, Composer, Pint, and `api-main` tests: `docker exec olie-api-main <command>`. Do not run `php` on the host.
- Frontend: Yarn 1 in `olie-fronts`. Do not use npm or `package-lock.json`.
- A rule that exists in only one repository (tenant, permissions, an internal package) is not copied here.

## Out of scope

Do not change the `~/git` meta-repo to finish a task for this product.
