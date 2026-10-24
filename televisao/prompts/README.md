# Televisão prompts

Card / workday prompts for Televisão. Paste into the agent when working this project.

| Path | Role |
| --- | --- |
| `~/git/televisao/prompts/` | **This project** (versioned on the meta-repo) |
| `~/git/televisao/cards/` | Media analyses per card |
| `~/git/.cursor/rules/` | Meta-repo Cursor rules (automatic) |

Paste-ready: copy one file, replace `{{ code }}`, paste.

Referencing another markdown/prompt is fine when the file exists in this meta-repo or in a clone you are working on — prefer an absolute path the agent can open (e.g. `~/git/televisao/prompts/workflow-policy.md`, or a path under `~/git/televisao/<clone>/`). Do not leave maintainer-only notes (“do not repeat X.md”); the paste is the instruction, not a style guide for editing prompts.

Shared policy: `~/git/televisao/prompts/workflow-policy.md` (not usually pasted alone). Board stages resolve live via OlieFlowAi / MCP `olie-flow-ai` — do not hard-code step IDs.

Typical develop handoff: `implementation.md` → `implementation-validation.md` (code only) → `pre-qa.md` (commits/PRs/forms; moves to 'QA/CR' when checks pass) → colleague 'QA/CR' → later board `validation.md`.

Personal, not a card prompt: `~/git/televisao/prompts/mutation-testing.md` runs mutation testing on the next changed `televisao-api` test file when Pest mutate is already installed, and appends it to `~/git/televisao/prompts/mutation-ledger.md`. Paste again to stack the next file. Do not copy that workflow into CI or the company compose.
