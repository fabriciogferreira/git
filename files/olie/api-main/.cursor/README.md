# `.cursor` — Cursor agent config for api-main

Companion to `.ai/` (shared Boost source of truth). Cursor-specific wiring lives here.

`.cursor` is gitignored — that is fine for local agent config (including Olie project skills below).

| Path | Purpose |
| --- | --- |
| `mcp.json` | Laravel Boost MCP (via Docker) |
| `rules/*.mdc` | Cursor-native rules (always / glob) |
| `skills/` | Boost skills (`boost:update`) + local Olie project skills |
| `skills/olie-project-image-analysis/` | Analyze card image media; post `pt-BR` analysis to project content |
| `skills/olie-project-content-language/` | Project content written via MCP must be Brazilian Portuguese |

## Enable Boost MCP in Cursor

1. Command palette → `/open MCP Settings` (or MCP settings UI)
2. Ensure `laravel-boost` is enabled
3. Container `olie-api-main` must be running (`../docker-workspace`)

Config uses `docker exec -i` because PHP is not on the host.

## After pulling

```bash
docker exec olie-api-main php artisan boost:update --no-discover
```

That refreshes Boost `skills/` and recomposes `AGENTS.md` / `CLAUDE.md` from `.ai/guidelines`.

If `boost:update` removes the local Olie skills, restore them from `olie-fronts/.cursor/skills/olie-project-*` (keep both repos aligned).

## What to read first

1. `AGENTS.md` — Laravel Boost baseline (Laravel 13, Pest 4, PHP 8.5, …)
2. `.ai/rules/index.md` — path-scoped project rules before editing
3. Matching `.cursor/skills/*` when the task is domain-specific (incl. `olie-project-image-analysis`)
4. `docs/concepts/*` for RoleType, soft-delete, feature flags
