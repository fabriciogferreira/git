# Card Validation

Use this for a card in the logical `validation` stage ('validação'). The workday order stays in `workflow.md`. This is the tech-lead pass after colleague 'QA/CR'. It is not `colleague-review.md`, `pre-qa.md`, or `production-review.md`.

Apply this rubric by default on every card-validation request. Do not wait to be reminded of the criteria or the mandatory reviewers.

## 1. Objective

Decide whether card `{{ code }}` may proceed toward merge, or must return for correction. Report one verdict with criterion-by-criterion justification. Do not implement fixes during this pass.

A card passes only when it clears all five criteria below and no reviewer raises a blocker.

## 2. Context first, code second

Follow these steps in order. If card context is empty, stop and report that validation cannot proceed without guessing.

1. Load the card through OlieFlowAi: description, funnel, stage, and answered forms.
2. Load the card media: spec, PRD, attachments, and pull-request links. The agreed behavior comes from these artifacts, not from memory.
3. State the proposal before opening code: what the card asked for, for whom, and which behavior changes in practice.
4. Analyze each pull request on its own. Do not treat a summed diff as one review. A correct PR can still fail to deliver the card.
5. Score the delivery against the five criteria.

## 3. The five criteria

These are a set, not a sequence. Fail any one and the card fails.

| Criterion | Look for |
| --- | --- |
| Security | Vulnerability, exposed sensitive data, authentication or authorization in the wrong place. |
| Integrity | The code does what it claims, without an obvious bug or broken alternate path. |
| Maturity | The delivery is complete and structured, not half-finished. Test coverage counts here. |
| Requirements | Everything the card asked for was delivered — the whole request, not only the easy part. |
| Front / back coherence | API contract, types, and payloads match across repositories. No field that exists on only one side. |

## 4. Specialized reviewers in parallel

Do not review the card in a single pass. Choose the aspects the delivery requires and launch one specialized reviewer per aspect at the same time. Merge their findings into one verdict.

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
| `requisitos` | On demand | Confront each PR with the spec attached to the card, item by item. |
| `front-back` | On demand | Cross-repo contract: payload, type, response shape, errors. |
| `performance` | On demand | When the card touches queries, listings, jobs, or volume. |

Without an attached spec or PRD as card media, the Requirements criterion has nothing solid to check against. Say so explicitly; do not invent acceptance criteria from the title or a vague description.

## 5. Inputs that decide review quality

Flag these gaps in the report when they hurt the review. They are not separate pass/fail criteria today, except where they already sit inside Maturity or Requirements.

- Spec attached as card media — required to judge Requirements. Spec and PRD belong as media, not only in the description.
- Real pull-request description — Brazilian Portuguese prose stating what changed and why. A repeated title, empty body, or raw diff dump does not count.
- Tests with the delivery — scored under Maturity. Explicit coverage as a sixth criterion is a product decision, not this prompt's job.
- Performance impact signal — the `performance` reviewer is optional until the card (or the change) suggests it.

## 6. Out of scope

- Do not implement or push fixes.
- Do not treat colleague 'QA/CR' success as validation success.
- Do not treat local success as the production check. That check is `production-review.md`.
- Do not move the card unless the user asks you to apply the verdict. Recommend the stage from `workflow.md`: approve → 'Revisão de Produção'; reject → `changes-requested` ('corrigir ou melhorar').

## 7. Verdict

Only two outcomes. Always justify item by item. Never answer with a bare pass or fail.

**Approve**  
All five criteria passed and no reviewer raised a blocker. Ready for merge path per `workflow.md`.

**Send for correction**  
List every failure: which criterion, which reviewer, and where in the code or PR — so the author can fix without guessing.

## Done when

The report names card `{{ code }}`, the PRs reviewed, which optional reviewers ran and why, the result for each of the five criteria, the merged findings, and either Approve or Send for correction with actionable locations. Checks that did not run are named with the reason.
