# Locav prompts

Card / workday prompts for Locav. Paste into the agent when working this project.

| Path | Role |
| --- | --- |
| `~/git/locav/prompts/` | **This project** (versioned on the meta-repo) |
| `~/git/locav/cards/` | Media analyses per card |
| `~/git/.cursor/rules/` | Meta-repo Cursor rules (automatic) |

Paste-ready: copy one file, replace `{{ code }}`, paste.

In the develop chat, short commands (defined in `workflow-policy.md` / `implementation.md`): `next prompt` runs the recommended next file; `try again` resumes or re-runs the current prompt; `to correct` fixes items that failed `implementation-validation.md`.

Referencing another markdown/prompt is fine when the file exists in this meta-repo or in a clone you are working on — prefer an absolute path the agent can open (e.g. `~/git/locav/prompts/workflow-policy.md`, or a path under `~/git/locav/<clone>/`). Do not leave maintainer-only notes (“do not repeat X.md”); the paste is the instruction, not a style guide for editing prompts.

Shared policy: `~/git/locav/prompts/workflow-policy.md` (not usually pasted alone). Board stages resolve live via OlieFlowAi / MCP `olie-flow-ai` — do not hard-code step IDs.

Typical develop handoff: `implementation.md` → `implementation-validation.md` (code only) → if the card changed `LocavApi`, `mutation-testing.md` → `pre-qa.md` (product PRs + meta-repo commit/push on `main`; moves to 'QA/CR' when checks pass) → colleague 'QA/CR' → later board `validation.md`. When there is no backend change, skip mutation-testing and go straight to `pre-qa.md`.

Personal, not a card prompt: `~/git/locav/prompts/mutation-testing.md` converts the next changed `LocavApi` PHPUnit test to Pest 4 with Drift when needed, runs mutation testing on that file, and appends it to `~/git/locav/prompts/mutation-ledger.md`. Paste again to stack the next file. After the change-set stack is done (or the user stops), the next paste is `pre-qa.md`. Do not copy that workflow into CI or the company compose.
