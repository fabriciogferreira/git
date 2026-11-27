# Colleague Card Review — coordinator

Review card `{{ code }}` while it sits in 'QA/CR'. **You review product code and e2e** (`colleague-review-core.md`). You do **not** measure coverage/mutation/Pest and do **not** MCP-dump the card spec.

Shared outcome: **Colleague review outcome** in `~/git/olie/prompts/workflow-policy/gates.md`.

If tooling this prompt needs **fails or stalls**: stop, report, offer `resolva` / `documente` / `resolva permanentemente` — treat it as a signal that **this prompt needs updating**. Exception: `olie-flow-ai` `needsAuth` with desktop already authenticated → **MCP auth** (no `mcp_auth`; `workflow-policy/tools.md`). Host-card sandbox cluster → **Shell permissions** in `workflow-policy/host.md`.

## 0. Preconditions (user / manager — stop if missing)

| Need | Where |
| --- | --- |
| Host-card open | Manager **Open** (or already this Cursor window) |
| Spec dump | Manager **Card Spec** → `~/git/olie/cards/{{ code }}/` (`README.md`, `project.md`, `media.md`, `notebook/`) |
| Gap (if backend) | Manager **Gap** → `…/gap/olie/<code>/latest.json` (or `olie/cards/{{ code }}/gap-seed.md`) |
| Coverage (if backend) | Manager **Coverage** → `…/coverage/olie/<code>/latest.json` |
| Mutation (if backend) | Manager **Mutation** → `…/mutation/olie/<code>/latest.json` |
| Pest full (if backend, before Pass) | Manager **Pest** → `…/pest/olie/<code>/latest.json` / `pest-ledger.md` |

1. If Card Spec dump is missing → **stop**; tell the user to run **Card Spec**.
2. Do **not** call `get-project-details-tool`, `get-notebook-tool`, `read-notebook-page-tool`, or `get-project-media-tool` to rebuild that dump.
3. Do **not** run `workvm-sandbox`, `pest --mutate`, `pest --coverage`, or full-suite Pest. Those are manager gates.
4. If backend changed and Coverage/Mutation/Pest artifacts are missing, mark those gates **pending (user)** on the scoreboard — do **not** invent Clean. Pass → 'Validação' only when those are `pass`/`empty`/`skipped` (or user explicitly skips).

## 1. Bootstrap (light)

1. Read `~/git/olie/cards/{{ code }}/project.md`, `media.md`, and `notebook/` (via `notebook/index.md`). That is the source of truth.
2. Confirm the card is in 'QA/CR' from `project.md` funnel steps (or one MCP details read **only** if the dump is stale and the user asked to re-check the board).
3. Classify **bounce vs first pass** from `media.md` system logs (**Return from production / merged bounce** in `workflow-policy/gates.md`). Record `bounce=yes/no` + path + post-deploy media ids.
4. Detect backend touch from dump/PRs/forms/change-set (**Backend change-set** in `workflow-policy/gates.md` if needed). Empty `develop...HEAD` alone is not “no backend”.
5. Prefer the host-card checkout already set by **Open**. Do not destroy the unit when this paste ends.
6. Record `started_at` (UTC).

## 2. Product review (agent)

Run `~/git/olie/prompts/colleague-review-core.md` for `{{ code }}` (same chat or one subagent). Pass bounce packet + that the spec is on disk under `olie/cards/{{ code }}/`.

Optional: `~/git/olie/prompts/test-gap-analysis.md` when backend touched — read manager **Gap** seed only; report list in chat. Skip if no backend, seed `skip_no_backend`, or user skips gap.

**Forbidden here:** dispatching `coverage-testing.md` / `mutation-testing.md` / `pest-parallel.md` as measure loops.

## 3. Collect gates

| Gate | Source |
| --- | --- |
| Colleague core | This paste / core prompt |
| Gap | Manager seed + this paste (or **skipped**) |
| Coverage | User manager artifact (or pending/skipped) |
| Mutation | User manager artifact (or pending/skipped) |
| Pest | User manager artifact (or pending/skipped) |

If core returns Fail findings → those are product fails (Corrigir path). If Coverage/Mutation `needs_work` → **reviewer-fix** (stay QA/CR); agent may implement `agent_action` only when the user asks; user re-runs the manager action.

## 4. Combined outcome

Apply **Colleague review outcome** once gates above are decided (or user skips pending manager gates):

- **Corrigir** only if colleague core failed (or failure outside gap/coverage/mutation/Pest).
- **Reviewer-fix:** core Pass but gap/coverage/mutation/Pest open → stay 'QA/CR'; no author dump of personal gates on the card.
- **Pass** (approve PRs via GitHub MCP; move 'Validação') only if core Pass **and** gap clean/skipped **and** coverage/mutation/Pest pass/empty/skipped.
- Evidence table on Pass or Corrigir via `save-media-tool` — **Evidence table** in `workflow-policy/evidence.md`. Not while reviewer-fix with open personal gates.

Card notes: **Card content vs chat** (findings only; no VM/sandbox/ledger jargon).

## 5. Scoreboard (required)

| Field | Content |
| --- | --- |
| Card | {{ code }} |
| Owner(s) | from `project.md` |
| Started / ended (UTC) | timestamps |
| Duration | wall-clock |
| Backend touched | yes / no |
| Spec dump | path `olie/cards/{{ code }}/` |
| Colleague core | Pass / Fail — short reason |
| Bounce | yes / no — path; media ids if yes |
| Gap | clean / N titles / Skipped / Blocked |
| Coverage | pass / needs_work / pending / skipped (artifact path) |
| Mutation | pass / needs_work / pending / skipped (artifact path) |
| Pest | pass / needs_work / pending / skipped (artifact path) |
| Contrast / Feedback / Comportamento / E2E / CAPTCHA | from core |
| PRs | approved / not / deferred |
| Funnel | QA/CR (reviewer-fix) / Corrigir / Validação |
| Incidents | tooling / skips |

Do not call the card ready for 'Validação' while core failed or a required manager gate is still `needs_work`/`pending` (unless user skipped).
