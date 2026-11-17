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

## 2. Backend (`televisao-api` in the change set)

```bash
docker exec -w /srv televisao-backend php artisan test --compact --parallel
```

- Do **not** pass a path filter or `--filter`.
- If `vendor/bin/pest` is missing, stop and report (do not install Pest).
- If `--parallel` is rejected, run `composer pest:dump-plugins` once and retry. If it still fails, stop (prompt-health).

## 3. Frontend (`televisao-front` and/or `televisao-meet-front` in the change set)

Run the lint script each changed front repository already has. If unknown, stop and report.

## 4. Outcome

**Green** — Report counts / lint. Next: `~/git/televisao/prompts/pre-qa.md`.

**Red** — List failures. Do not open pre-QA. `to correct` then `try again`.

## Done when

Card `{{ code }}`, commands run, outcomes, and green → pre-QA or red with actionable failures.
