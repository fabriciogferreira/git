# Olie prompts

Card / workday prompts for Olie. Paste into the agent when working this project.

| Path | Role |
| --- | --- |
| `~/git/olie/prompts/` | **This project** (versioned on the meta-repo) |
| `~/git/olie/cards/` | Media analyses per card |
| `~/git/.cursor/rules/` | Meta-repo Cursor rules (automatic) |

Do not save `{{ code }}` → real card code into the versioned file. In chat:

- `colleague review DOP-1285` (agent loads the template, substitutes in memory, runs)
- or `@colleague-review.md` + the code in the same message

Optional clipboard: `~/git/bin/workvm-paste-prompt olie colleague-review DOP-1285`. See **Prompt templates** / **Chat commands** in `workflow-policy.md`.

In the develop chat, short commands (defined in `workflow-policy.md` / `implementation.md`): `next prompt` runs the recommended next file; `next mutation` continues the personal mutation stack one test file at a time; `correct mutations` drains every remaining mutation test file in parallel (sandbox + subagent each); `next coverage` / `correct coverages` continue the personal coverage stack (`coverage-testing.md`); `try again` resumes or re-runs the current prompt; `add` implements **Tests to add** from `test-gap-analysis.md`; `to correct` fixes **Needs code fixes** from `implementation-validation.md` (or Pest parallel failures) — not the same as `add` or `correct mutations`.

Referencing another markdown/prompt is fine when the file exists in this meta-repo or in a clone you are working on — prefer an absolute path the agent can open (e.g. `~/git/olie/prompts/workflow-policy.md`, or a path under `~/git/olie/<clone>/`). Do not leave maintainer-only notes (“do not repeat X.md”); the paste is the instruction, not a style guide for editing prompts.

These prompt paths are private to this WorkVM. Never recommend them in Olie card content — only in the Cursor chat. See **Card content vs chat (private prompts)** in `workflow-policy.md`.

Shared policy: `~/git/olie/prompts/workflow-policy.md` (not usually pasted alone).

Typical develop handoff: `implementation.md` → `implementation-validation.md` (reviewers only; no full suite) → if the card changed `api-main`, `test-gap-analysis.md` → `coverage-testing.md` (`next coverage` / `correct coverages`) → `mutation-testing.md` (`next mutation` / `correct mutations`) → `pest-parallel.md` (full suite) → `pre-qa.md` (product PRs + meta-repo commit/push on `main`; moves to 'QA/CR' when checks pass) → colleague 'QA/CR' → later board `validation.md`. When there is no backend change, skip gap / coverage / mutation / Pest parallel and go straight to `pre-qa.md`.

`test-gap-analysis.md` compares card requirements to written **backend** tests: either **no tests to add**, or a **title + description** list. On own-card develop handoff the list stays in chat — send **`add`** to implement those tests, then `try again` on gap; close before coverage / PRs. On colleague review the list is also written into the card content.

Personal coverage (line %): `coverage-testing.md`; ledger in `coverage-ledger.md` — runs **after** gap. Send **`next coverage`** / **`correct coverages`**. While coverage files remain, `next prompt` must not jump to mutation / Pest parallel / `pre-qa.md`.

Personal mutation: `mutation-testing.md`; ledger in `mutation-ledger.md` — runs **after** coverage. Send **`next mutation`** / **`correct mutations`**. While mutation files remain, `next prompt` must not jump to `pest-parallel.md` or `pre-qa.md`.

Suite regression: `pest-parallel.md` runs the **full** parallel Pest suite **after** mutation and **before** `pre-qa.md`. Do not copy mutation/coverage gates into company CI.
