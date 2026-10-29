# Olie prompts

Card / workday prompts for Olie. Paste into the agent when working this project.

| Path | Role |
| --- | --- |
| `~/git/olie/prompts/` | **This project** (versioned on the meta-repo) |
| `~/git/olie/cards/` | Media analyses per card |
| `~/git/.cursor/rules/` | Meta-repo Cursor rules (automatic) |

Paste-ready: copy one file, replace `{{ code }}`, paste.

In the develop chat, short commands (defined in `workflow-policy.md` / `implementation.md`): `next prompt` runs the recommended next file; `next mutation` continues the personal mutation stack one test file at a time; `try again` resumes or re-runs the current prompt; `to correct` fixes items that failed `implementation-validation.md`.

Referencing another markdown/prompt is fine when the file exists in this meta-repo or in a clone you are working on — prefer an absolute path the agent can open (e.g. `~/git/olie/prompts/workflow-policy.md`, or a path under `~/git/olie/<clone>/`). Do not leave maintainer-only notes (“do not repeat X.md”); the paste is the instruction, not a style guide for editing prompts.

Shared policy: `~/git/olie/prompts/workflow-policy.md` (not usually pasted alone).

Typical develop handoff: `implementation.md` → `implementation-validation.md` (code only) → if the card changed `api-main`, `test-gap-analysis.md` then `mutation-testing.md` (repeat with `next mutation` until the ledger covers every changed test file) → `pre-qa.md` (product PRs + meta-repo commit/push on `main`; moves to 'QA/CR' when checks pass) → colleague 'QA/CR' → later board `validation.md`. When there is no backend change, skip gap analysis and mutation-testing and go straight to `pre-qa.md`.

`test-gap-analysis.md` compares card requirements to written **backend** tests: either **no tests to add**, or a **title + description** list written into the card content. Personal mutation: `mutation-testing.md` on **one** changed `api-main` test file; ledger in `mutation-ledger.md`. Send **`next mutation`** for each remaining file. While files remain, `next prompt` must not jump to `pre-qa.md`. Do not copy mutation into the company repos.
