# Locav prompts

Card / workday prompts for Locav. Paste into the agent when working this project.

| Path | Role |
| --- | --- |
| `~/git/locav/prompts/` | **This project** (versioned on the meta-repo) |
| `~/git/locav/cards/` | Media analyses per card |
| `~/git/.cursor/rules/` | Meta-repo Cursor rules (automatic) |

Paste-ready: copy one file, replace `{{ code }}`, paste. Do that only in the chat paste — never commit or push a prompt where `{{ code }}` was replaced by a real card code (see **Prompt templates** in `workflow-policy.md`).

In the develop chat, short commands (defined in `workflow-policy.md` / `implementation.md`): `next prompt` runs the recommended next file; `try again` resumes or re-runs the current prompt; `to correct` fixes items that failed `implementation-validation.md`.

Referencing another markdown/prompt is fine when the file exists in this meta-repo or in a clone you are working on — prefer an absolute path the agent can open (e.g. `~/git/locav/prompts/workflow-policy.md`, or a path under `~/git/locav/<clone>/`). Do not leave maintainer-only notes (“do not repeat X.md”); the paste is the instruction, not a style guide for editing prompts.

These prompt paths are private to this host. Never recommend them in Olie card content — only in the Cursor chat. See **Card content vs chat (private prompts)** in `workflow-policy.md`.

Shared policy: `~/git/locav/prompts/workflow-policy.md` (not usually pasted alone). Board stages resolve live via OlieFlowAi / MCP `olie-flow-ai` — do not hard-code step IDs.

Typical develop handoff: `implementation.md` → `implementation-validation.md` (reviewers only) → if `LocavApi` and/or `locav-front` changed, `test-gap-analysis.md` → if `LocavApi` changed, `coverage-testing.md` → `mutation-testing.md` → `pest-parallel.md` → `pre-qa.md`. When neither backend nor front changed, skip those gates and go straight to `pre-qa.md`.

`test-gap-analysis.md` compares card requirements to written **backend and frontend** tests (Pest + Cypress): either **no tests to add**, or a **title + description** list. On own-card develop handoff the list stays in chat (fix before PRs); on colleague review it is also written into the card content. Personal mutation: `mutation-testing.md` on changed `LocavApi` tests; ledger in `mutation-ledger.md`. Personal coverage: `coverage-testing.md`; ledger in `coverage-ledger.md`. On colleague 'QA/CR', after gap (+ mutation + coverage when `LocavApi`), apply the combined outcome. Do not copy mutation/coverage into CI or the company compose.
