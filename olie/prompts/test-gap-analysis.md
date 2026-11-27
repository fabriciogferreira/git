# Test gap analysis (agent)

Review card {{ code }}. Compare the card’s requirements with the tests already written for this change set.

**You do not collect the seed.** The user runs **Gap** in `~/git/manager.sh` (→ `actions/gap.sh` → `bin/workvm-host-card-gap`). That needs **Open** + **Card Spec** first. You only **read** the artifact and report one of two exits.

Contract: `~/git/lib/gap/ARTIFACT.md`

This prompt has **exactly two exits**:

1. **No tests to add** — every card-related use case already has automated coverage in the change set.
2. **Tests to add** — a list of missing tests, each with a **title** and a **description** (Brazilian Portuguese; no prompt paths — **Card content vs chat** in `~/git/olie/prompts/workflow-policy/card-context.md`).

**Where the list goes** depends on the entry point:

- **Own card (develop handoff)** — chat only. Do **not** write the list into the project/card content. The author closes those gaps in the same handoff before `pre-qa.md` / pull requests.
- **Colleague stack** — Cursor chat / scoreboard only by default. Write into the project/card **only** when **Colleague review outcome** moves to 'Corrigir' for a failure outside gap/mutation/coverage (see **Project content (gap / mutation / coverage)** in `workflow-policy/gates.md`).

Do **not** invent a third exit. Do **not** implement the missing tests in this paste unless the user explicitly asks (`add`). Do not run mutation / coverage measure here.

## What the user does

1. Manager → **Card Spec** (if missing) → **Gap** → project `olie` → card.
2. Script writes change-set tests + `project.md` excerpt.
3. User pastes the path to `latest.json` / `latest.md` (or asks you to open it).

Default paths:

```
~/.local/share/project-card-manager/gap/olie/<code-lower>/latest.json
~/git/olie/cards/{{ code }}/gap-seed.md
```

## What you do

1. Open `latest.json` (or `gap-seed.md` / the path the user gave).
2. If `status` is `error` → **stop**; tell the user to run **Card Spec** (and Open) then re-run **Gap**. Do **not** MCP-rebuild.
3. If `status` is `skip_no_backend` or `empty` → report **No tests to add** / skipped (no backend in change-set). Stop.
4. If `status` is `ready`:
   - Read `requirements` (excerpt + notebook titles) and, if needed, files under `spec_dir` (`project.md`, `notebook/`).
   - Skim `tests[]` (paths + `it`/`test`/`describe` titles). Optionally open those PHP files under `api_main` for detail.
   - Derive card use cases vs covered scenarios. Do **not** mark covered because production “looks right”.
   - Exit with **No tests to add** or **Tests to add** (title + description each).
5. Do **not** call `get-project-details-tool` / notebook / media MCP to rebuild the dump. Do **not** re-derive `develop...HEAD` when `tests[]` / `app_files[]` are already in the artifact (unless the user says the seed is stale — then ask them to re-run **Gap**).

Out of scope: unrelated areas, full `tests/` inventory, mutation score, frontend e2e.

## Chat commands (this prompt)

| Command | Meaning |
| --- | --- |
| (user ran Gap / pasted artifact) | Read seed and report one exit. |
| `add` | After **Tests to add**: implement every listed missing test. Then recommend `try again` (user re-runs **Gap**, you re-read). |
| `try again` | After `add` or a new Gap run: read the new seed / re-judge. Do not re-scan an unchanged seed “to confirm”. |
| `next prompt` | After **No tests to add**, recommend Coverage (manager) when backend applies. While **Tests to add** remain, refuse until `add` / closed. |
| `to correct` | Not for this list — use `add`. |

**Re-run budget:** if this pass already reported for the current seed tip in this chat, do not re-derive until requirements or tests change. Shared: **Expensive re-run budget** in `workflow-policy/gates.md`.

If tooling fails: stop, report, offer `resolva` / `documente` / `resolva permanentemente`. Exception: `olie-flow-ai` `needsAuth` with desktop authenticated → **MCP auth**. Shared: `workflow-policy/tools.md`.

## Report

- Card {{ code }}.
- Backend branch / tip from seed.
- Exactly one of the two exits.
- Checks that did not run, and why.

## Outcome

1. **No tests to add** — Say so. Recommend manager **Coverage** next on develop handoff when backend applies.
2. **Tests to add** — List title + description. Do not approve / move funnel. User may `add` then `try again`.

Never invent a third exit. Shared index: `~/git/olie/prompts/workflow-policy.md` (open only the named module).
