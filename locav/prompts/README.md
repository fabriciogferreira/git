# Locav prompts

Card / workday prompts for Locav. Paste into the agent when working this project.

| Path | Role |
| --- | --- |
| `~/git/locav/prompts/` | **This project** (versioned on the meta-repo) |
| `~/git/locav/cards/` | Media analyses per card |
| `~/git/.cursor/rules/` | Meta-repo Cursor rules (automatic) |

Paste-ready: copy one file, replace `{{ code }}`, paste.

Referencing another markdown/prompt is fine when the file exists in this meta-repo or in a clone you are working on — prefer an absolute path the agent can open (e.g. `~/git/locav/prompts/workflow-policy.md`, or a path under `~/git/locav/<clone>/`). Do not leave maintainer-only notes (“do not repeat X.md”); the paste is the instruction, not a style guide for editing prompts.

Shared policy: `~/git/locav/prompts/workflow-policy.md` (not usually pasted alone). Board stages resolve live via OlieFlowAi / MCP `olie-flow-ai` — do not hard-code step IDs.

Typical develop handoff: `implementation.md` → `implementation-validation.md` (code only) → `pre-qa.md` (commits/PRs/forms) → 'QA/CR' → later board `validation.md`.
