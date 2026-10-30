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

These prompt paths are private to this WorkVM. Never recommend them in Olie card content — only in the Cursor chat. See **Card content vs chat (private prompts)** in `workflow-policy.md`.

Shared policy: `~/git/locav/prompts/workflow-policy.md` (not usually pasted alone). Board stages resolve live via OlieFlowAi / MCP `olie-flow-ai` — do not hard-code step IDs.

Typical develop handoff: `implementation.md` → `implementation-validation.md` (code only) → if `LocavApi` and/or `locav-front` changed, `test-gap-analysis.md` → if `LocavApi` changed, `mutation-testing.md` → `pre-qa.md` (product PRs + meta-repo commit/push on `main`; moves to 'QA/CR' when checks pass) → colleague 'QA/CR' → later board `validation.md`. When neither backend nor front changed, skip gap analysis and mutation and go straight to `pre-qa.md`.

`test-gap-analysis.md` compares card requirements to written **backend and frontend** tests (Pest + Cypress): either **no tests to add**, or a **title + description** list written into the card content. Personal mutation: `mutation-testing.md` on changed `LocavApi` tests; ledger in `mutation-ledger.md`. Do not copy mutation into CI or the company compose.
