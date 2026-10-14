# Card Validation (board 'validação')

Use this for a card in the logical `validation` stage ('validação'). This is the tech-lead pass **after** colleague 'QA/CR', when pull requests, forms, and board checklist items should already exist.

**Code** criteria (Security, Integrity, Maturity, Requirements, Front / back coherence) belong to `~/git/olie/prompts/implementation-validation.md`. Do **not** re-score them here unless a PR clearly diverged from what that pass approved — then fail Handoff / packaging and send back for correction.

This is **not**:

- Code-only review after implementation → use `~/git/olie/prompts/implementation-validation.md`
- Commits / PRs / forms creation → use `~/git/olie/prompts/pre-qa.md`
- Colleague 'QA/CR' → use `~/git/olie/prompts/colleague-review.md`
- Production → use `~/git/olie/prompts/production-review.md`

Apply this rubric by default on every board-validation request. Do not wait to be reminded of the criteria.

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

## 1. Objective

Decide whether card `{{ code }}` may proceed toward merge / 'Revisão de Produção', or must return for correction, based on **handoff packaging** (PRs, forms, checklist). Report one verdict with criterion-by-criterion justification. Do not implement fixes during this pass.

## 2. Context first

Follow these steps in order. If card context is empty, stop and report that validation cannot proceed without guessing.

1. Load the card through OlieFlowAi: description, funnel, stage, **answered forms**, and checklist state.
2. Load the card media: spec, PRD, attachments, and **pull-request links**.
3. Confirm each required repository has a PR, that titles/bodies are usable, and that forms/checklist items for this stage are done.
4. Spot-check that the open PRs still match the card (wrong branch, empty PR, or obvious packaging gap). Do not re-run the full code rubric from implementation-validation.

If PRs, forms, or required checklist items are missing, **fail this validation** (or stop as blocked) and say to run or re-run `~/git/olie/prompts/pre-qa.md` — do not pretend this is still implementation-validation.

## 3. Criteria

These are a set, not a sequence. Fail any one and the card fails.

| Criterion | Look for |
| --- | --- |
| Handoff readiness | Required forms answered; board checklist items that belong to this stage are done. |
| PR packaging | Each required repo has a PR; title and body in the required languages/quality; assignees/reviewers/labels sensible; PR targets the correct base and the card branch. |
| Card linkage | PR links (or equivalent) are on the card; the set of PRs matches the repositories the card changed. |
| Packaging integrity | No placeholder/empty PR, raw dump-only body, or PR that clearly does not contain the card work. |

## 4. Specialized checks

Prefer parallel checks when useful:

| Check | When | What it does |
| --- | --- | --- |
| `handoff` | Always | Forms, checklist, missing PR links. |
| `pr-packaging` | Always | Title/body quality, base branch, assignees/reviewers/labels gaps. |
| `card-linkage` | Always | Every changed repo covered; card points at the right PRs. |

Do not launch the implementation-validation code reviewers (`multitenancy`, `segurança`, `requisitos`, `front-back`, …) on this pass unless the user explicitly asks for a code re-review.

## 5. Inputs that decide review quality

Missing items **fail** the matching criterion above:

- Real pull-request description — Brazilian Portuguese prose stating what changed and why. A repeated title, empty body, or raw diff dump does not count.
- Required card forms answered.
- PR links present on the card for each required repository.

## 6. Out of scope

- Do not implement or push fixes.
- Do not re-score Security / Integrity / Maturity / Requirements / Front-back (that was `~/git/olie/prompts/implementation-validation.md`).
- Do not treat colleague 'QA/CR' success as validation success by itself.
- Do not treat local-only success (without PRs) as this validation.
- Do not treat local success as the production check. That check is 'Revisão de Produção' (`~/git/olie/prompts/production-review.md`).
- Do not fail validation for missing or outdated keys in `en.json`.
- Do not move the card unless the user asks you to apply the verdict. Recommend: approve → 'Revisão de Produção'; reject → `changes-requested` ('corrigir ou melhorar').

## 7. Verdict

Only two outcomes. Always justify item by item. Never answer with a bare pass or fail.

**Approve**  
All handoff criteria passed. Ready for the merge path toward 'Revisão de Produção'.

**Send for correction**  
List every failure: which criterion and where in the PR, form, or checklist — so the author can fix without guessing.

## Done when

The report names card `{{ code }}`, the PRs and forms reviewed, the result for each handoff criterion, and either Approve or Send for correction with actionable locations. Checks that did not run are named with the reason.
