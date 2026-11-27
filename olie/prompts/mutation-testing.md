# Mutation testing (agent)

Personal WorkVM stack for **in-scope mutation** on `api-main`. Skip when there is no backend.

**You do not measure.** The user runs **Mutation** in `~/git/manager.sh` (→ `actions/mutation.sh` → `bin/workvm-host-card-mutation`). That writes the artifact; you only **read it** and, if needed, **tighten tests** (or record true `equivalent`s).

Contract: `~/git/lib/mutation/ARTIFACT.md`  
Ledger: `~/git/olie/prompts/mutation-ledger.md`  
Gates (unchanged): score **in-scope** mutants only (diff hunks). All killed or zero in-scope → `100%`. Behavior-preserving survivors → `equivalent` with mutation ids + why. Do not change production only for mutation. Do not commit temporary `mutates()` / `covers()`. Do not open a PR whose purpose is mutation testing. Pest class-wide `%` may stay below 100% — that is OK.

## What the user does

1. Manager → **Mutation** → project `olie` → card.
2. Script: change-set `*Test.php` → baseline → `pest --mutate --covered-only` (one `--class` per run) → score in-scope UNTESTED → `latest.json` / upsert **pass** rows.
3. User pastes the path (or asks you to open it).

Default artifact:

```
~/.local/share/project-card-manager/mutation/olie/<code-lower>/latest.json
```

## What you do

1. Open `latest.json`.
2. If `status` is `pass` or `empty` → report clean; next handoff is manager **Pest** (then `pre-qa.md`) when that owns the chain. Stop.
3. If `needs_work` / `error`:
   - For each `files[]` with `agent_action`: implement the **smallest** assertion change in that `*Test.php` to kill listed in-scope mutants, **or** if a mutant is truly behavior-preserving, note `equivalent` + id/why (update ledger Notes / Result when closing — or leave for the next manager pass after you document it in chat and the user accepts).
   - Do **not** create sandboxes, do **not** run `pest --mutate`, do **not** chase out-of-scope survivors or Pest raw `%`.
4. Tell the user to re-run **Mutation** in the manager until `status=pass`.

## Forbidden (agent)

- `workvm-sandbox create` / `job run` for this stack
- `vendor/bin/pest --mutate` / host-card mutate as a substitute for the manager
- Parallel subagent drain / “correct mutations” orchestration
- `--everything` or whole change-set pool on every file
- Jumping to Pest / `pre-qa.md` while `latest.json` still has `fail` / `blocked` (unless the user explicitly skips mutation)

## Chat commands (this stack)

| Command | Do this |
| --- | --- |
| (user ran Mutation / pasted artifact) | Read `latest.json` and follow **What you do**. |
| `try again` | After they re-ran Mutation: read the new artifact and continue. |
| `skip mutation` | User opt-out: stop this stack. |
| `next prompt` | Only when latest artifact is `pass`/`empty` (or skip). Then tell the user to run **Pest** in the manager (develop handoff). |

Old commands `next mutation` / `correct mutations` mean: **user runs Mutation in the manager** (full drain). Do not re-enter the old sandbox loop.
