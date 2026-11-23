# Pest parallel (suite regression)

Run this **after** the personal stacks for the card (when they apply) and **before** `~/git/televisao/prompts/pre-qa.md`.

Own-card order when `televisao-api` changed:

`implementation-validation` → `test-gap-analysis` → `coverage-testing` → `mutation-testing` → **this prompt** → `pre-qa`.

(Televisão also runs `recommendation.md` between implementation/correction and validation — unchanged.)

Skip entirely when the change set has **no** `televisao-api` paths and no front package that needs lint (go to `pre-qa` after validation). Do **not** open `pre-qa.md` while the suite or required lint is red.

Chat commands: `~/git/televisao/prompts/workflow-policy.md` → **Chat commands**.

If tooling fails or stalls too long: stop and report (prompt-health). Exception: `olie-flow-ai` `needsAuth` — **MCP auth** in `workflow-policy.md`. Do not install Pest on this pass.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | After a **green** required check, run `~/git/televisao/prompts/pre-qa.md`. |
| `try again` | Re-run the suite / lint **after a fix** (or unblock). Do not re-run a green suite on an unchanged tree “to confirm”. |
| `to correct` | Fix failures from this pass, then `try again`. |

**Re-run budget:** one green full-suite result in this chat stands until code/tests change or the suite was red and fixed. Shared rule: **Expensive re-run budget** in `workflow-policy.md`.

## 1. Objective

Confirm the **whole** backend suite is green (and front lint when a front changed) after gap / coverage / mutation may have changed tests.

## 2. Host card

Idempotent ensure if needed (**Host card environment** in `workflow-policy.md`):

```bash
~/git/bin/workvm-host-card ensure --project televisao --code '{{ code }}'
```

If this chat is already the card’s Cursor window and the stack is up (`hc-televisao-…-backend-1`), skip ensure — re-running it used to rewrite the workspace / reopen Cursor. Prefer `agent-docker` when resume is enough.

## 3. Backend (`televisao-api` in the change set)

```bash
PROCS="${WORKVM_HOST_CARD_PEST_PROCESSES:-$(nproc 2>/dev/null || echo 8)}"
if [ "$PROCS" -gt 22 ]; then PROCS=22; fi
~/git/bin/workvm-host-card agent-docker --project televisao --code '{{ code }}' --container backend --workdir /srv -- \
  php artisan test --compact --parallel --processes="$PROCS"
```

- Host-card container is `hc-televisao-<slug>-backend-1`, not a shared `televisao-backend` name. `agent-docker` injects `DB_DATABASE=<meta.testing_database>` for Pest.
- Do **not** pass `--ci` to `php artisan test` — Laravel’s test command does **not** accept it (`The "--ci" option does not exist`). Company `televisao-api` does not enable Pest TIA on the card (`PEST_TIA_LOCALLY=1` is sandbox-only); the full suite runs without TIA shrink. If a future Pest build enables local TIA on the card, pass `--no-tia` via `vendor/bin/pest` instead of inventing `--ci` on artisan.
- Parallel workers default to **at most 22** (jarvis `nproc=24`: **23+** can SIGSEGV Pest workers). Override with `WORKVM_HOST_CARD_PEST_PROCESSES` only when intentional.
- Do **not** pass a path filter or `--filter`.
- If `vendor/bin/pest` is missing, stop and report (do not install Pest).
- If `--parallel` is rejected, run `composer pest:dump-plugins` once and retry. If it still fails, stop (prompt-health).
- Silent sandbox / hidden `docker.sock`: **Host card environment** → `agent-docker` (not bare `docker exec`).

## 4. Frontend (`televisao-front` and/or `televisao-meet-front` in the change set)

On the host (clone cwd), run Biome **check** (no `--write`) so the gate does not rewrite the tree:

```bash
cd ~/git/televisao/televisao-front && bunx biome check .
```

Repeat for `televisao-meet-front` when that repo is in the change set. `lint:biome:fix` (`biome check . --write`) is for local fixups, not this gate. If Biome / the script is missing, stop and report.

## 5. Outcome

**Green** — Report counts / lint. Next: `~/git/televisao/prompts/pre-qa.md`.

**Red** — List failures. Do not open pre-QA. `to correct` then `try again`.

## Done when

Card `{{ code }}`, commands run, outcomes, and green → pre-QA or red with actionable failures.
