# Implementation Validation

Use this **after** `~/git/olie/prompts/implementation.md` (or a correction that changed code) and **before** handoff. This is a **code-only** pass while the card is still in `in-progress`. It is not board 'validação', not colleague 'QA/CR', not pre-QA, and not production review.

**Reviewers only** — do **not** run the full Pest suite here. Suite regression is `~/git/olie/prompts/pest-parallel.md` after gap → coverage → mutation.

**Next paste after a pass** depends on whether the card changed the backend (`~/git/olie/api-main`):

1. Backend touched → `~/git/olie/prompts/test-gap-analysis.md`, then `coverage-testing.md`, then `mutation-testing.md`, then `pest-parallel.md`, then `~/git/olie/prompts/pre-qa.md`. Finish coverage (`next coverage` / `correct coverages`) and mutation (`next mutation` / `correct mutations`) before Pest parallel; do not skip to pre-QA via `next prompt` while those stacks or Pest parallel remain.
2. Backend not touched → `~/git/olie/prompts/pre-qa.md` (same as before).

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared modules: `workflow-policy/tools.md` (MCP auth / tooling failures) · index `workflow-policy.md`.

### Chat commands

Same phrases as in `~/git/olie/prompts/workflow-policy/gates.md` (**Chat commands**) and `implementation.md`:

| Command | Do this |
| --- | --- |
| `next prompt` | After **Ready for handoff**, run the next recommended file (`test-gap-analysis.md`, `coverage-testing.md`, `mutation-testing.md`, `pest-parallel.md`, or `pre-qa.md`) without waiting for a paste. Once coverage-testing has started, use `next coverage` / `correct coverages` for remaining production files; once mutation-testing has started, use `next mutation` / `correct mutations` for remaining test files; do not use `next prompt` to open `pre-qa.md` until coverage, mutation, and Pest parallel are complete (when backend changed). |
| `try again` | Re-run **this** validation pass **after** a manual env fix or after `to correct`. Do not re-score an unchanged diff “to confirm”. |
| `to correct` | Leave validation mode: implement every **Needs code fixes** item from this pass’s report, then stop and recommend `try again` (re-run this validation). Do not implement fixes during the scoring pass itself unless the user already sent `to correct`. |

**Re-run budget:** one Ready / Needs code fixes verdict for the current local diff stands until that diff (or requirements/media) changes. Shared rule: **Expensive re-run budget** in `workflow-policy/gates.md`.

## 1. Objective

Decide whether the **local implementation** for card `{{ code }}` is ready for the test/quality stacks. Report one verdict with criterion-by-criterion justification. Do not implement fixes during this pass unless the user sends `to correct` (or otherwise asks to fix).

A card passes this pass only when it clears the five code criteria below and no reviewer raises a blocker.

## 2. Out of scope for this pass

Do **not** require or fail on:

- Pull requests existing or being open
- Commits pushed to remote
- Card forms filled
- Checklist items on the board
- The card being in 'QA/CR' or 'validação'
- Full Pest / suite green (that is `pest-parallel.md`)

Those belong to later prompts (`pest-parallel.md`, `pre-qa.md`, `validation.md`).

Also:

- Do not create commits, push, or open pull requests.
- Do not move the card stage.
- Do not treat this pass as production evidence.

## 3. Context first, code second

Follow these steps in order. If card context is empty, stop and report that validation cannot proceed without guessing.

1. Load the card through OlieFlowAi: description, requirements, acceptance criteria, and attached media (spec, PRD). Forms and PR links may be empty — that is expected here.
2. State the proposal before opening code: what the card asked for, for whom, and which behavior changes in practice.
3. Inspect the **local** branches and working trees for every repository the card changes (card-specific branch from the card / implementation). Review the actual diff against the correct base. Do not invent a PR if none exists.
4. Score the delivery against the five criteria (§4), using the specialized reviewers (§5).

## 4. The five criteria

These are a set, not a sequence. Fail any one and this pass fails.

| Criterion | Look for |
| --- | --- |
| Security | Vulnerability, exposed sensitive data, authentication or authorization in the wrong place. |
| Integrity | The code does what it claims, without an obvious bug or broken alternate path. |
| Maturity | The delivery is complete and structured, not half-finished. Test coverage *design* counts here; do not require a green full suite in this pass. |
| Requirements | Everything the card asked for was delivered — the whole request, not only the easy part. |
| Front / back coherence | API contract, types, and payloads match across repositories. No field that exists on only one side. |

## 5. Specialized reviewers in parallel

Do not review in a single pass. Choose the aspects the delivery requires and launch one specialized reviewer per aspect at the same time. Merge their findings into one verdict.

Two reviewers run on every card:

| Reviewer | When | What it does |
| --- | --- | --- |
| `multitenancy` | Always | Hunt queries without `frame_id`, policies without `ensureModelFrameId`, and any path that can leak another tenant's data. When `olie-fronts` changed, also check that new or changed HTTP calls send `frame_id` (or the project's established tenant context) whenever the matching API path scopes by frame — omit/wrong frame is the same class of leak. Highest-severity risk in this codebase. |
| `advogado-do-diabo` | Always | Challenge the card's premises, find ignored edge cases, and ask whether the delivery is actually mature. |

Optional reviewers — add when the delivery needs them:

| Reviewer | When | What it does |
| --- | --- | --- |
| `segurança` | On demand | Auth, authorization, data exposure, new attack surface. |
| `integridade` | On demand | Logic, bugs, error paths, migrations, side effects. |
| `requisitos` | On demand | Confront the local change with the spec attached to the card, item by item. |
| `front-back` | On demand | Cross-repo contract: payload, type, response shape, errors. When both sides changed, confirm the front's request includes every tenant/frame field the backend requires for the new or changed endpoints. |
| `performance` | On demand | When the card touches queries, listings, jobs, or volume. |

Without an attached spec or PRD as card media, the Requirements criterion has nothing solid to check against. Say so explicitly; do not invent acceptance criteria from the title or a vague description.

Do not fail this pass for missing or outdated keys in `en.json`. English translations are resolved later; require user-facing keys in `pt-br.json` when the card adds UI copy.

## 6. Verdict

Only two outcomes. Always justify item by item. Never answer with a bare pass or fail.

**Ready for handoff**  
All five criteria passed and no reviewer raised a blocker. Decide the next paste from the **local** branches/working trees already reviewed in §3:

- **Backend changed** — any added/modified path under `~/git/olie/api-main` (including `app/`, `tests/`, migrations, etc.): next paste is `~/git/olie/prompts/test-gap-analysis.md`, then `coverage-testing.md`, then `mutation-testing.md`, then `pest-parallel.md`, then `pre-qa.md`. Say to continue with **`next coverage`** / **`correct coverages`** until every changed `app/` file is in the coverage ledger, then **`next mutation`** / **`correct mutations`** until every changed test file is in the mutation ledger, then **Pest parallel**, then `pre-qa`. Do not run pre-QA in this same paste.
- **Backend not changed** — no `api-main` paths in the card's local change set: next paste is `~/git/olie/prompts/pre-qa.md` directly.

State which branch you took and why (list whether `api-main` appears in the reviewed diffs).

**Needs code fixes**  
List every failure: which criterion, which reviewer, and where in the code — so the author can fix without guessing. Tell the user they can send `to correct` to have those items fixed in this chat, then `try again` to re-run this validation. Do not run gap, coverage, mutation, Pest parallel, or pre-QA yet.

## Done when

The report names card `{{ code }}`, the local branches/diffs reviewed, which optional reviewers ran and why, the result for each of the five criteria, the merged findings, and either Ready for handoff (with the next paste: gap → coverage → mutation → Pest parallel → pre-QA, or pre-QA only) or Needs code fixes with actionable locations.
