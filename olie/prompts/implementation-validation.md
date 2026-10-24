# Implementation Validation

Use this **after** `~/git/olie/prompts/implementation.md` (or a correction that changed code) and **before** `~/git/olie/prompts/pre-qa.md`. This is a **code-only** pass while the card is still in `in-progress`. It is not board 'validação', not colleague 'QA/CR', not pre-QA, and not production review.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy. Do not call `mcp_auth` and do not ask the user to sign in again. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

## 1. Objective

Decide whether the **local implementation** for card `{{ code }}` is ready for pre-QA (commits, PRs, forms). Report one verdict with criterion-by-criterion justification. Do not implement fixes during this pass unless the user asks.

A card passes this pass only when it clears the five code criteria below and no reviewer raises a blocker.

## 2. Out of scope for this pass

Do **not** require or fail on:

- Pull requests existing or being open
- Commits pushed to remote
- Card forms filled
- Checklist items on the board
- The card being in 'QA/CR' or 'validação'

Those belong to `~/git/olie/prompts/pre-qa.md` and later to `~/git/olie/prompts/validation.md`.

Also:

- Do not create commits, push, or open pull requests.
- Do not move the card stage.
- Do not treat this pass as production evidence.

## 3. Context first, code second

Follow these steps in order. If card context is empty, stop and report that validation cannot proceed without guessing.

1. Load the card through OlieFlowAi: description, requirements, acceptance criteria, and attached media (spec, PRD). Forms and PR links may be empty — that is expected here.
2. State the proposal before opening code: what the card asked for, for whom, and which behavior changes in practice.
3. Inspect the **local** branches and working trees for every repository the card changes (card-specific branch from the card / implementation). Review the actual diff against the correct base. Do not invent a PR if none exists.
4. Score the delivery against the five criteria.

## 4. The five criteria

These are a set, not a sequence. Fail any one and this pass fails.

| Criterion | Look for |
| --- | --- |
| Security | Vulnerability, exposed sensitive data, authentication or authorization in the wrong place. |
| Integrity | The code does what it claims, without an obvious bug or broken alternate path. |
| Maturity | The delivery is complete and structured, not half-finished. Test coverage counts here. |
| Requirements | Everything the card asked for was delivered — the whole request, not only the easy part. |
| Front / back coherence | API contract, types, and payloads match across repositories. No field that exists on only one side. |

## 5. Specialized reviewers in parallel

Do not review in a single pass. Choose the aspects the delivery requires and launch one specialized reviewer per aspect at the same time. Merge their findings into one verdict.

Two reviewers run on every card:

| Reviewer | When | What it does |
| --- | --- | --- |
| `multitenancy` | Always | Hunt queries without `frame_id`, policies without `ensureModelFrameId`, and any path that can leak another tenant's data. Highest-severity risk in this codebase. |
| `advogado-do-diabo` | Always | Challenge the card's premises, find ignored edge cases, and ask whether the delivery is actually mature. |

Optional reviewers — add when the delivery needs them:

| Reviewer | When | What it does |
| --- | --- | --- |
| `segurança` | On demand | Auth, authorization, data exposure, new attack surface. |
| `integridade` | On demand | Logic, bugs, error paths, migrations, side effects. |
| `requisitos` | On demand | Confront the local change with the spec attached to the card, item by item. |
| `front-back` | On demand | Cross-repo contract: payload, type, response shape, errors. |
| `performance` | On demand | When the card touches queries, listings, jobs, or volume. |

Without an attached spec or PRD as card media, the Requirements criterion has nothing solid to check against. Say so explicitly; do not invent acceptance criteria from the title or a vague description.

Do not fail this pass for missing or outdated keys in `en.json`. English translations are resolved later; require user-facing keys in `pt-br.json` when the card adds UI copy.

## 6. Verdict

Only two outcomes. Always justify item by item. Never answer with a bare pass or fail.

**Ready for pre-QA**  
All five criteria passed and no reviewer raised a blocker. Next paste: `~/git/olie/prompts/pre-qa.md`.

**Needs code fixes**  
List every failure: which criterion, which reviewer, and where in the code — so the author can fix without guessing. Stay on implementation/correction until fixed; do not run pre-QA yet.

## Done when

The report names card `{{ code }}`, the local branches/diffs reviewed, which optional reviewers ran and why, the result for each of the five criteria, the merged findings, and either Ready for pre-QA or Needs code fixes with actionable locations. Checks that did not run are named with the reason.
