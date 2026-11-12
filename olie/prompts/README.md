# Olie prompts

Card / workday prompts for Olie. Paste into the agent when working this project.

| Path | Role |
| --- | --- |
| `~/git/olie/prompts/` | **This project** (versioned on the meta-repo) |
| `~/git/olie/cards/` | Media analyses per card |
| `~/git/.cursor/rules/` | Meta-repo Cursor rules (automatic) |

Paste-ready: copy one file, replace `{{ code }}`, paste. Do that only in the chat paste — never commit or push a prompt where `{{ code }}` was replaced by a real card code (see **Prompt templates** in `workflow-policy.md`).

In the develop chat, short commands (defined in `workflow-policy.md` / `implementation.md`): `next prompt` runs the recommended next file; `next mutation` continues the personal mutation stack one test file at a time; `correct mutations` drains every remaining mutation test file in parallel (sandbox + subagent each); `next coverage` / `correct coverages` continue the personal coverage stack (`coverage-testing.md`); `try again` resumes or re-runs the current prompt; `to correct` fixes items that failed `implementation-validation.md` (not the same as `correct mutations`).

Referencing another markdown/prompt is fine when the file exists in this meta-repo or in a clone you are working on — prefer an absolute path the agent can open (e.g. `~/git/olie/prompts/workflow-policy.md`, or a path under `~/git/olie/<clone>/`). Do not leave maintainer-only notes (“do not repeat X.md”); the paste is the instruction, not a style guide for editing prompts.

These prompt paths are private to this WorkVM. Never recommend them in Olie card content — only in the Cursor chat. See **Card content vs chat (private prompts)** in `workflow-policy.md`.

Shared policy: `~/git/olie/prompts/workflow-policy.md` (not usually pasted alone).

Typical develop handoff: `implementation.md` → `implementation-validation.md` (code only) → if the card changed `api-main`, `test-gap-analysis.md` then `mutation-testing.md` (continue with `next mutation` and/or one `correct mutations` drain until the mutation ledger covers every changed test file) then `coverage-testing.md` (continue with `next coverage` and/or one `correct coverages` drain until the coverage ledger covers every changed `app/` file) → `pre-qa.md` (product PRs + meta-repo commit/push on `main`; moves to 'QA/CR' when checks pass) → colleague 'QA/CR' → later board `validation.md`. When there is no backend change, skip gap analysis, mutation-testing, and coverage-testing and go straight to `pre-qa.md`.

`test-gap-analysis.md` compares card requirements to written **backend** tests: either **no tests to add**, or a **title + description** list. On own-card develop handoff the list stays in chat (fix before PRs); on colleague review it is also written into the card content. Personal mutation: `mutation-testing.md`; ledger in `mutation-ledger.md`. Send **`next mutation`** for one remaining file, or **`correct mutations`** to drain all remaining (sandbox + subagent per file). While mutation files remain, `next prompt` must not jump to coverage or `pre-qa.md`. Do not copy mutation into the company repos.

Personal coverage (line %): `coverage-testing.md`; ledger in `coverage-ledger.md`. Send **`next coverage`** for one changed `app/` file, or **`correct coverages`** to drain the rest. Measures with Pest `--coverage` + PCOV. On own-card develop handoff this stack runs **after** mutation and **blocks** `pre-qa.md` until done (or the user explicitly stops/skips). Do not copy coverage gates into company CI.
