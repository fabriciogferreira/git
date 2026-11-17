# Pest parallel (suite regression)

Run this **after** the personal stacks for the card (when they apply) and **before** `~/git/locav/prompts/pre-qa.md`.

Own-card order when `LocavApi` changed:

`implementation-validation` → `test-gap-analysis` → `coverage-testing` → `mutation-testing` → **this prompt** → `pre-qa`.

When only `locav-front` changed (no `LocavApi`): after gap analysis, run this prompt’s frontend lint section (skip backend suite if no backend), then `pre-qa`. Skip entirely when neither backend nor front changed.

Do **not** open `pre-qa.md` from here while the suite or required lint is red.

Chat commands: `~/git/locav/prompts/workflow-policy.md` → **Chat commands**.

If tooling fails or stalls too long: stop and report (prompt-health). Exception: `olie-flow-ai` `needsAuth` — **MCP auth** in `workflow-policy.md`.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | After a **green** required check, run `~/git/locav/prompts/pre-qa.md`. |
| `try again` | Re-run the suite / lint **after a fix** (or unblock). Do not re-run a green suite on an unchanged tree “to confirm”. |
| `to correct` | Fix failures from this pass, then `try again`. |

**Re-run budget:** one green full-suite result in this chat stands until code/tests change or the suite was red and fixed. Shared rule: **Expensive re-run budget** in `workflow-policy.md`.

## 1. Objective

Confirm the **whole** backend suite is green (and front lint when the front changed) after gap / coverage / mutation may have changed tests.

## 2. Backend (`LocavApi` in the change set)

```bash
docker exec -w /var/www/html locav-backend php artisan test --compact --parallel
```

- Do **not** pass a path filter or `--filter`.
- If `--parallel` is rejected, run `composer pest:dump-plugins` once in that container and retry. If it still fails, stop (prompt-health).

## 3. Frontend (`locav-front` in the change set)

```bash
docker exec locav-frontend bun run lint
```

## 4. Outcome

**Green** — Report counts / lint. Next: `~/git/locav/prompts/pre-qa.md`.

**Red** — List failures. Do not open pre-QA. `to correct` then `try again`.

## Done when

Card `{{ code }}`, commands run, outcomes, and green → pre-QA or red with actionable failures.
