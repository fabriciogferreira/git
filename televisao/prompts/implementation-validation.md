# Implementation Validation

Use this **after** `~/git/televisao/prompts/recommendation.md`. That paste follows `~/git/televisao/prompts/implementation.md` (or `~/git/televisao/prompts/correction.md` when that pass changed code). Run this **before** handoff. This is a **code-only** pass while the card is still in `in-progress`. It is not board 'Validação', not colleague 'QA/CR', not pre-QA, and not production review.

**Next paste after a pass** depends on whether the card changed the backend (`~/git/televisao/televisao-api`):

1. Backend touched → `~/git/televisao/prompts/test-gap-analysis.md`, then `mutation-testing.md`, then `pre-qa.md`.
2. Backend not touched → `~/git/televisao/prompts/pre-qa.md` (same as before).

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/televisao/prompts/workflow-policy.md`.

### Chat commands

Same phrases as in `~/git/televisao/prompts/workflow-policy.md` (**Chat commands**) and `implementation.md`:

| Command | Do this |
| --- | --- |
| `next prompt` | After **Ready for handoff**, run the next recommended file (`test-gap-analysis.md`, `mutation-testing.md`, or `pre-qa.md`) without waiting for a paste. |
| `try again` | Re-run **this** validation pass (e.g. after a manual env fix or after `to correct`). |
| `to correct` | Leave validation mode: implement every **Needs code fixes** item from this pass’s report, then stop and recommend `try again` (re-run this validation). Do not implement fixes during the scoring pass itself unless the user already sent `to correct`. |

## 1. Objective

Decide whether the **local implementation** for card `{{ code }}` is ready for handoff. Report one verdict with criterion-by-criterion justification. Do not implement fixes during this pass unless the user sends `to correct` (or otherwise asks to fix).

A card passes this pass only when it clears the five code criteria below and no reviewer raises a blocker.

## 2. Out of scope for this pass

Do **not** require or fail on:

- Pull requests existing or being open
- Commits pushed to remote
- Card forms filled
- Checklist items on the board
- The card being in 'QA/CR' or 'Validação'

Those belong to `~/git/televisao/prompts/pre-qa.md` and later to `~/git/televisao/prompts/validation.md`.

Also:

- Do not create commits, push, or open pull requests.
- Do not move the card stage.
- Do not treat this pass as production evidence.

## 3. Context first, code second

Follow these steps in order. If card context is empty, stop and report that validation cannot proceed without guessing.

1. Load the card through OlieFlowAi: description, requirements, acceptance criteria, and attached media (spec, PRD). Forms and PR links may be empty — that is expected here.
2. Read every project thread and the latest version of each one (**Reading the project notebook** in `~/git/televisao/prompts/workflow-policy.md`). Those texts are part of what the card asked for.
3. State the proposal before opening code: what the card asked for, for whom, and which behavior changes in practice.
4. Inspect the **local** branches and working trees for every repository the card changes (card-specific branch from the card / implementation). Review the actual diff against the correct base. Do not invent a PR if none exists.
5. **Run the automated checks** in §4 (required — do not score without them when the change set needs them).
6. Score the delivery against the five criteria (§5), using the check results and the specialized reviewers (§6).

## 4. Automated checks (required)

Scoring without a green suite lets regressions slip. Run these **before** (or **in parallel with**) the specialized reviewers. Do not skip because implementation already ran a subset.

### Host card / stack

Idempotent ensure if the unit may be down (**Host card environment** in `~/git/televisao/prompts/workflow-policy.md`):

```bash
~/git/bin/workvm-host-card ensure --project televisao --code '{{ code }}'
```

Use the Televisão compose stack for this card (`televisao-backend`). Do not run PHP on the host.

### Backend (`televisao-api` in the local change set)

Run the **full** suite in **parallel** inside the backend container (Pest must already be installed — do not `composer require` it here):

```bash
docker exec -w /srv televisao-backend php artisan test --compact --parallel
```

- Do **not** pass a path filter or `--filter` on this pass — the point is the whole suite.
- If `vendor/bin/pest` is missing, stop and report (do not install Pest on this pass).
- If `--parallel` is rejected (`Unknown option "--parallel"`), run `docker exec -w /srv televisao-backend composer pest:dump-plugins` once and retry the same full parallel command. If it still fails, stop and report (prompt-health) — do not invent a smaller subset to “make validation pass”.
- Any failed test → this pass is **Needs code fixes** (Integrity and/or Maturity). List the failing file/name in the report. Do not dismiss failures as “unrelated” without evidence; investigate.

### Frontend (`televisao-front` and/or `televisao-meet-front` in the local change set)

Run the lint script each changed front repository already has. Do not assume Bun or a container named `televisao-frontend`. If the command is unknown, stop and report. Red lint from this change set → **Needs code fixes**.

### No backend / no front

If the change set has neither `televisao-api` nor a front package, say so and skip the matching check. Still run reviewers on whatever did change.

### Private e2e

Do **not** fail this pass solely because private Playwright specs were not executed here. If you do run them for confidence, keep suite paths out of card/Caderno/PR text (**Private E2E suites** / **Running Playwright** in `workflow-policy.md`).

## 5. The five criteria

These are a set, not a sequence. Fail any one and this pass fails.

| Criterion | Look for |
| --- | --- |
| Security | Vulnerability, exposed sensitive data, authentication or authorization in the wrong place. |
| Integrity | The code does what it claims, without an obvious bug or broken alternate path. A red required suite (§4) fails this. |
| Maturity | The delivery is complete and structured, not half-finished. Test coverage counts here. Required automated checks (§4) must have been run and green when applicable. |
| Requirements | Everything the card asked for was delivered — the whole request, not only the easy part. |
| Front / back coherence | API contract, types, and payloads match across repositories. No field that exists on only one side. |

## 6. Specialized reviewers in parallel

Do not review in a single pass. Choose the aspects the delivery requires and launch one specialized reviewer per aspect at the same time. Merge their findings into one verdict. Prefer launching reviewers **while** §4 tests/lint are running so wall-clock stays short.

Two reviewers run on every card:

| Reviewer | When | What it does |
| --- | --- | --- |
| `autorizacao` | Always | Hunt auth/authorization gaps, missing ownership checks (clinic, doctor, patient, consultation), and any path that can leak another account's data. When `televisao-front` or `televisao-meet-front` changed, also check that new or changed HTTP calls send the ownership/auth identifiers the matching API path requires — omit/wrong scope is the same class of leak. |
| `advogado-do-diabo` | Always | Challenge the card's premises, find ignored edge cases, and ask whether the delivery is actually mature. |

Optional reviewers — add when the delivery needs them:

| Reviewer | When | What it does |
| --- | --- | --- |
| `segurança` | On demand | Auth, authorization, data exposure, new attack surface. |
| `integridade` | On demand | Logic, bugs, error paths, migrations, side effects. |
| `requisitos` | On demand | Confront the local change with the spec attached to the card, item by item. |
| `front-back` | On demand | Cross-repo contract: payload, type, response shape, errors. When both sides changed, confirm the front's request includes every ownership/auth field the backend requires for the new or changed endpoints. |
| `performance` | On demand | When the card touches queries, listings, jobs, or volume. |

Without an attached spec or PRD as card media, the Requirements criterion has nothing solid to check against. Say so explicitly; do not invent acceptance criteria from the title or a vague description.

## 7. Verdict

Only two outcomes. Always justify item by item. Never answer with a bare pass or fail.

**Ready for handoff**  
All five criteria passed, required §4 checks ran and were green when applicable, and no reviewer raised a blocker. Decide the next paste from the **local** branches/working trees already reviewed in §3:

- **Backend changed** — any added/modified path under `~/git/televisao/televisao-api` (including `app/`, `tests/`, migrations, etc.): next paste is `~/git/televisao/prompts/test-gap-analysis.md`, then `mutation-testing.md`, then `pre-qa.md`. Do not run pre-QA in this same paste.
- **Backend not changed** — no `televisao-api` paths in the card's local change set: next paste is `~/git/televisao/prompts/pre-qa.md` directly.

State which branch you took and why (list whether `televisao-api` appears in the reviewed diffs). Include §4 command results (pass/fail counts or lint outcome).

**Needs code fixes**  
List every failure: which criterion, which reviewer or §4 check, and where in the code — so the author can fix without guessing. Tell the user they can send `to correct` to have those items fixed in this chat, then `try again` to re-run this validation (including §4). Do not run mutation-testing or pre-QA yet.

## Done when

The report names card `{{ code }}`, the local branches/diffs reviewed, **which §4 automated checks ran and their outcomes** (full parallel suite and/or lint — or why a check was N/A), which optional reviewers ran and why, the result for each of the five criteria, the merged findings, and either Ready for handoff (with the next paste: test-gap-analysis then mutation-testing then pre-QA, or pre-QA only) or Needs code fixes with actionable locations. Checks that did not run are named with the reason — skipping a required §4 check without a tool failure is not allowed.
