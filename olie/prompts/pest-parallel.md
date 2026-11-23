# Pest parallel (suite regression)

Run this **after** the personal stacks for the card (when they apply) and **before** `~/git/olie/prompts/pre-qa.md`.

Own-card order when `api-main` changed:

`implementation-validation` → `test-gap-analysis` → `coverage-testing` → `mutation-testing` → **this prompt** → `pre-qa`.

Skip entirely when the change set has **no** `api-main` paths (go straight to `pre-qa` after validation). Do **not** open `pre-qa.md` from here while the suite is red.

Chat commands: `~/git/olie/prompts/workflow-policy.md` → **Chat commands**.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | After a **green** suite, run `~/git/olie/prompts/pre-qa.md`. Do not open pre-QA while this pass is red. |
| `try again` | Re-run the full parallel suite **after a fix** (or unblock). Do not re-run a green suite on an unchanged tree “to confirm”. |
| `to correct` | Fix failures from this pass’s report, then `try again`. |

**Re-run budget:** one green full-suite result in this chat stands until code/tests change or the suite was red and fixed. Shared rule: **Expensive re-run budget** in `workflow-policy.md`.

## 1. Objective

Confirm the **whole** backend suite is green on the host-card stack after gap / coverage / mutation may have changed tests. This is the regression gate before packaging (pre-QA).

## 2. Host card

Idempotent ensure if needed (**Host card environment** in `workflow-policy.md`):

```bash
~/git/bin/workvm-host-card ensure --project olie --code '{{ code }}'
```

If this chat is already the card’s Cursor window and the stack is up (`hc-olie-…-app-1`), skip ensure — re-running it used to rewrite the `.code-workspace` / reopen Cursor and feel like the workspace was “resetting”. Prefer `workvm-host-card-pest` directly when resume is enough.
## 3. Run the full suite in parallel

```bash
~/git/bin/workvm-host-card-pest --project olie --code '{{ code }}'
```

Defaults: `--compact --parallel --recreate-databases --processes=min(nproc, 22)`.

- Do **not** pass `--ci` to `php artisan test` — Laravel rejects it (`The "--ci" option does not exist`). The wrapper forces `PEST_TIA_LOCALLY=0` on the exec so Pest TIA (enabled via that env on sandbox/slim compose without touching company `Pest.php`) does **not** shrink this full-suite gate.
- Parallel workers default to **at most 22** (`workvm-host-card-pest`): on the jarvis host (`nproc=24`), **23+** kills Pest workers with SIGSEGV (exit 139). Override with `WORKVM_HOST_CARD_PEST_PROCESSES` only when intentional.
- Do **not** pass a path filter or `--filter` — the point is the whole suite.
- Do **not** use `docker exec olie-api-main` / another card’s container.
- If the command fails or stalls too long: stop and report (prompt-health). Do not invent a smaller subset to “pass”.

## 4. Frontend (only if `olie-fronts` is in the change set)

Run management lint on the host-card front container. Red lint from this change set fails this pass the same way as a red suite.

## 5. Outcome

**Green** — Report pass/fail counts (and lint if run). Next paste: `~/git/olie/prompts/pre-qa.md` (`next prompt`).

**Red** — List failing tests / lint. Do not open pre-QA. Tell the user they can send `to correct`, then `try again`.

## Done when

The report names card `{{ code }}`, the command(s) run, the suite outcome (counts), lint if applicable, and either green → pre-QA or red with actionable failures.
