# Coverage testing (agent)

Personal WorkVM stack for **patch (diff) line coverage** on `api-main`. Skip when there is no backend.

**You do not measure.** The user runs **Coverage** in `~/git/manager.sh` (→ `actions/coverage.sh` → `bin/workvm-host-card-coverage`). That writes the artifact; you only **read it** and, if needed, **implement tests**.

Contract: `~/git/lib/coverage/ARTIFACT.md`  
Ledger: `~/git/olie/prompts/coverage-ledger.md`  
Gates (unchanged): cover 100% of in-scope executable hunks; **new/small** (≤80 executable lines) → File raw `100%`; **large** → File raw ≥ `prev + 1` pp (capped at 100%). Do not change production only to satisfy coverage. Do not commit temporary `covers()`. Do not open a PR whose purpose is coverage reporting.

## What the user does

1. Manager → **Coverage** → project `olie` → card.
2. Script measures (change-set, Via batches, `pest --coverage`, score, ledger upsert for **pass** rows).
3. User pastes the path to `latest.json` / `latest.md` (or asks you to open it).

Default artifact path:

```
~/.local/share/project-card-manager/coverage/olie/<code-lower>/latest.json
```

## What you do

1. Open `latest.json` (or the path the user gave).
2. If `status` is `pass` or `empty` → report clean; recommend mutation next only if that owns the handoff. Stop.
3. If `status` is `needs_work` or `error`:
   - For each `files[]` with `agent_action` not null: implement the **smallest** test change under the card `api-main` worktree that satisfies that action (Via test or sibling). Prefer assertions that execute the named lines.
   - Do **not** create sandboxes, do **not** run `pest --coverage`, do **not** rewrite `coverage-ledger.md` by hand (the next manager run stamps pass rows + `sha:`).
4. Tell the user to re-run **Coverage** in the manager. Repeat until `status=pass`.

## Forbidden (agent)

- `workvm-sandbox create` / `job run` for this stack
- `vendor/bin/pest --coverage` / host-card pest as a substitute for the manager
- Parallel subagent drain / “correct coverages” orchestration
- Treating Pest suite `Total: X%` as the gate
- Jumping to mutation / Pest / `pre-qa.md` while `latest.json` still has `fail` / `blocked` / `no_related_test` (unless the user explicitly skips coverage)

## Chat commands (this stack)

| Command | Do this |
| --- | --- |
| (user ran Coverage / pasted artifact) | Read `latest.json` and follow **What you do**. |
| `try again` | After they re-ran Coverage: read the new `latest.json` and continue implementing remaining `agent_action`s. |
| `skip coverage` | User opt-out: stop this stack; they own the skip. |
| `next prompt` | Only when latest artifact is `pass`/`empty` (or skip). Then `mutation-testing.md` on develop handoff. |

Old commands `next coverage` / `correct coverages` mean: **user runs Coverage in the manager** (full drain). Do not re-enter the old sandbox loop.
