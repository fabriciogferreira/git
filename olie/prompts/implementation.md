# Card Development Workflow

Implement card `{{ code }}`. Read Card Spec → plan → code. Shared policy: open only the module you need (`workflow-policy.md` index).

If tooling fails/stalls: stop, offer `resolva` / `documente` / `resolva permanentemente` (**Tooling failures** in `workflow-policy/tools.md`) — treat it as a signal that **this prompt needs updating**. Exception: `olie-flow-ai` `needsAuth` with desktop authenticated → **MCP auth** (no `mcp_auth`).

### Chat commands

| Command | Do this |
| --- | --- |
| `next` | Next checklist item (controlled mode). |
| `next prompt` | After this paste: run `implementation-validation.md`. |
| `try again` | Resume this prompt from the blocked item. |
| `to correct` | Only after validation **Needs code fixes**. |
| `add` | Only after gap **Tests to add**. |
| `finish card` | Destroy host-card (**Host** in `workflow-policy/host.md`). |

Full table: `workflow-policy/gates.md`.

### 0. Host-card + Card Spec

1. `~/git/bin/workvm-host-card ensure --project olie --code '{{ code }}'` with `required_permissions: ["all"]` (Ask → `request_smart_mode_approval`; still sandboxed → `agent-ensure`). Detail: `workflow-policy/host.md`. Do **not** destroy when this paste ends.
2. Spec must exist at `~/git/olie/cards/{{ code }}/` (`README.md`, `project.md`, `media.md`, `notebook/`). Missing → **stop**; user runs manager **Card Spec**. Do not MCP-rebuild.
3. Read `project.md`, `media.md`, `notebook/` (from `index.md`). **Deferred decisions** (`workflow-policy/card-context.md`): stop, ask, recommend + why; read parent/children dumps when listed.
4. Media: reuse `olie/cards/{CODE}/{MEDIA_ID}.md` or analyze via skills; never post analysis to card content; no commit in this pass.

### 1. Stage

MCP move: `not-started` → `in-progress` only (`workflow-policy/board.md`). Already there → continue. Other stage → report and wait. No project execution.

### 2. Git

Per repo the card touches: preserve dirty work; update base (`project.md`); create/checkout the **exact** card branch from the form. Never implement on the base branch.

### 3. Plan (Plan mode)

`SwitchMode` → **plan**. Investigate read-only. `CreatePlan` (or ignored local dir — not a product doc). Include: objective, AC, codebase findings, interference, test gaps (private e2e root per **Private E2E** in `workflow-policy/host.md`), ordered checklist, risks, **Issues encountered during development**. Front/API cards also: means, request/perf impacts, screens+why, foreseen problems (plan/chat only — not card content).

**Stop.** Do not code until the user sends `next` (or explicitly waives controlled mode).

### 4. Implement

Default: one checklist item per `next`. Mark complete only after that item’s verification. Update the plan/issues log. On new scope/risk, stop and adjust the plan before continuing.

Quality (short): smallest correct change; no unrelated refactors; `pt-br.json` only (no `en.json`); tests for behavior; UX contraste/feedback/comportamento when UI touched; gradual JS→TS and Options→Composition when blast radius fits (track reasons for evidence). **No Pint** unless asked (Pre-QA exception — `workflow-policy/host.md` **Formatting**).

reCAPTCHA local bypass: **Temporary E2E CAPTCHA** in `workflow-policy/host.md` (or Cursor rule) — env only.

### 5. Done

Checklist complete + report (files, tests, open issues). **Do not** commit/push/PR or hint at it — next is `implementation-validation.md` (`next prompt`). Evidence table is Pre-QA’s job (`workflow-policy/evidence.md`).
