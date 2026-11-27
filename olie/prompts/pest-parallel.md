# Pest parallel (agent)

Full-suite regression gate **before** `~/git/olie/prompts/pre-qa.md` when `api-main` changed.

**You do not run the suite.** The user runs **Pest** in `~/git/manager.sh` (→ `actions/pest.sh` → `bin/workvm-host-card-pest`). That writes the artifact and upserts `pest-ledger.md` on green.

Contract: `~/git/lib/pest/ARTIFACT.md`  
Ledger: `~/git/olie/prompts/pest-ledger.md`  
**Pest Changed** is smoke only — it does **not** close this gate.

## What the user does

1. Manager → **Pest** → card.
2. Paste path to `latest.json` / `latest.md` (or ask you to open it).

```
~/.local/share/project-card-manager/pest/<project>/<code-lower>/latest.json
```

## What you do

1. Open `latest.json` (and ledger row for this card@tip if useful).
2. If `status=pass` → report green; next is `pre-qa.md` when the handoff owns it. Stop.
3. If `needs_work`:
   - Fix the listed `failures` (smallest change). Optional: skim the `log` path.
   - Do **not** re-run `workvm-host-card-pest` / full suite in chat.
4. Tell the user to re-run **Pest** in the manager until `pass`.

## Forbidden (agent)

- Full-suite Pest / `workvm-host-card-pest` as a substitute for the manager
- Inventing a smaller `--filter` to “pass” the gate
- Opening `pre-qa.md` while `latest.json` is `needs_work` (unless user skips)

## Chat commands

| Command | Do this |
| --- | --- |
| (user ran Pest / pasted artifact) | Read `latest.json` and follow **What you do**. |
| `to correct` | Fix failures from the latest red artifact; user re-runs Pest. |
| `try again` | After they re-ran Pest: read the new artifact. |
| `next prompt` | Only when artifact is `pass` (or skip). Then `pre-qa.md`. |
