# Televisão prompts

Card / workday prompts for Televisão. Paste into the agent when working this project.

| Path | Role |
| --- | --- |
| `~/git/televisao/prompts/` | **This project** (versioned on the meta-repo) |
| `~/git/televisao/cards/` | Media analyses per card |
| `~/git/.cursor/rules/` | Meta-repo Cursor rules (automatic) |

Paste-ready: copy one file, replace `{{ code }}`, paste.

In the develop chat, short commands (defined in `workflow-policy.md` / `implementation.md`): `next prompt` runs the recommended next file; `try again` resumes or re-runs the current prompt; `to correct` fixes items that failed `implementation-validation.md`.

Referencing another markdown/prompt is fine when the file exists in this meta-repo or in a clone you are working on — prefer an absolute path the agent can open (e.g. `~/git/televisao/prompts/workflow-policy.md`, or a path under `~/git/televisao/<clone>/`). Do not leave maintainer-only notes (“do not repeat X.md”); the paste is the instruction, not a style guide for editing prompts.

Shared policy: `~/git/televisao/prompts/workflow-policy.md` (not usually pasted alone). Board stages resolve live via OlieFlowAi / MCP `olie-flow-ai` — do not hard-code step IDs.

Typical develop handoff: `implementation.md` → `recommendation.md` (related improvements, no code) → `implementation-validation.md` (code only) → if the card changed `televisao-api`, `test-gap-analysis.md` then `mutation-testing.md` → `pre-qa.md` (product PRs + meta-repo commit/push on `main`; moves to 'QA/CR' when checks pass) → colleague 'QA/CR' → later board `validation.md`. When there is no backend change, skip gap analysis and mutation-testing and go straight to `pre-qa.md`. On colleague 'QA/CR', run `colleague-review.md` then (if backend) `test-gap-analysis.md` then `mutation-testing.md`; move to 'Corrigir' only after all applicable gates and if at least one failed; full pass sets 'Revisado' before tech lead `validation.md`.

`test-gap-analysis.md` compares card requirements to written backend tests: either **no tests to add**, or a **title + description** list written into the card content (no implementation unless asked). Personal mutation: `mutation-testing.md` on the next changed `televisao-api` test file when Pest mutate is already installed, ledger in `mutation-ledger.md`. After that stack (or the user stops), the next paste is `pre-qa.md`. Do not copy mutation into CI or the company compose.
