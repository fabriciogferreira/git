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

Typical develop handoff: `implementation.md` → `implementation-validation.md` (code only) → if the card changed `api-main`, `mutation-testing.md` (repeat with `next mutation` until the ledger covers every changed test file) → `pre-qa.md` (product PRs + meta-repo commit/push on `main`; moves to 'QA/CR' when checks pass) → colleague 'QA/CR' → later board `validation.md`. When there is no backend change, skip mutation-testing and go straight to `pre-qa.md`.

Personal, not a card prompt: `~/git/olie/prompts/mutation-testing.md` runs Pest mutation testing on **one** changed `api-main` test file and appends it to `~/git/olie/prompts/mutation-ledger.md`. Send **`next mutation`** (or re-paste the prompt) for each remaining file. While files remain, `next prompt` must not jump to `pre-qa.md`. After the change-set stack is done (or the user explicitly stops), the next paste is `pre-qa.md`. Do not copy that workflow into the company repos.
