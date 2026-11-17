# Implementation Validation

Use this **after** `~/git/televisao/prompts/recommendation.md`. That paste follows `~/git/televisao/prompts/implementation.md` (or `~/git/televisao/prompts/correction.md` when that pass changed code). Run this **before** handoff. This is a **code-only** pass while the card is still in `in-progress`. It is not board 'Validação', not colleague 'QA/CR', not pre-QA, and not production review.

**Reviewers only** — do **not** run the full Pest suite here. Suite regression is `~/git/televisao/prompts/pest-parallel.md` after gap → coverage → mutation (when those apply).

**Next paste after a pass** depends on whether the card changed the backend (`~/git/televisao/televisao-api`):

1. Backend touched → `~/git/televisao/prompts/test-gap-analysis.md`, then `coverage-testing.md`, then `mutation-testing.md`, then `pest-parallel.md`, then `pre-qa.md`.
2. Backend not touched → `~/git/televisao/prompts/pre-qa.md` (if a front changed, still run lint via `pest-parallel.md` before pre-QA when that front is in the change set).

If tooling fails or stalls too long: stop and report (prompt-health). Exception: `olie-flow-ai` `needsAuth` — **MCP auth** in `~/git/televisao/prompts/workflow-policy.md`.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | After **Ready for handoff**, run the next recommended file without waiting for a paste. |
| `try again` | Re-run **this** validation pass **after** a fix / unblock. Do not re-score an unchanged diff “to confirm”. |
| `to correct` | Implement **Needs code fixes** from this pass, then recommend `try again`. |

**Re-run budget:** one Ready / Needs code fixes verdict for the current local diff stands until that diff (or requirements/media) changes. Shared rule: **Expensive re-run budget** in `workflow-policy.md`.

## 1. Objective

Decide whether the **local implementation** for card `{{ code }}` is ready for the test/quality stacks. Report one verdict with criterion-by-criterion justification. Do not implement fixes during this pass unless the user sends `to correct`.

## 2. Out of scope for this pass

Do **not** require PRs, commits, forms, checklist, stage moves, or a green full suite (that is `pest-parallel.md`). Do not create commits, push, or open PRs. Do not move the card stage.

## 3. Context first, code second

1. Load the card through OlieFlowAi: description, requirements, acceptance criteria, and attached media (spec, PRD).
2. Read every project thread and the latest version of each one (**Reading the project notebook** in `~/git/televisao/prompts/workflow-policy.md`).
3. State the proposal before opening code.
4. Inspect the **local** branches and working trees for every repository the card changes. Review the diff against the correct base.
5. Score against the five criteria (§4) using specialized reviewers (§5).

## 4. The five criteria

| Criterion | Look for |
| --- | --- |
| Security | Vulnerability, exposed sensitive data, authentication or authorization in the wrong place. |
| Integrity | The code does what it claims, without an obvious bug or broken alternate path. |
| Maturity | Complete and structured, not half-finished. Do not require a green full suite in this pass. |
| Requirements | Everything the card asked for was delivered. |
| Front / back coherence | API contract, types, and payloads match across repositories. |

## 5. Specialized reviewers in parallel

Launch specialized reviewers at the same time; merge findings.

| Reviewer | When | What it does |
| --- | --- | --- |
| `autorizacao` | Always | Hunt auth/authorization gaps, missing ownership checks (clinic, doctor, patient, consultation), and any path that can leak another account's data. When `televisao-front` or `televisao-meet-front` changed, also check HTTP calls send the ownership/auth identifiers the API requires. |
| `advogado-do-diabo` | Always | Challenge premises, edge cases, maturity. |

Optional: `segurança`, `integridade`, `requisitos`, `front-back`, `performance` when needed.

Without an attached spec or PRD as card media, say so for Requirements; do not invent acceptance criteria from the title alone.

## 6. Verdict

**Ready for handoff** — all five criteria passed, no reviewer blocker.

- **Backend changed** — next: `test-gap-analysis.md` → `coverage-testing.md` → `mutation-testing.md` → `pest-parallel.md` → `pre-qa.md`.
- **Backend not changed** — next: `pre-qa.md` (or `pest-parallel.md` first if a front in the change set needs lint).

**Needs code fixes** — list criterion, reviewer, location. `to correct` then `try again`. Do not run gap / coverage / mutation / Pest parallel / pre-QA yet.

## Done when

Card `{{ code }}`, diffs reviewed, reviewers used, five criteria, and Ready for handoff (gap → coverage → mutation → Pest parallel → pre-QA when applicable) or Needs code fixes.
