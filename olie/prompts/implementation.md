# Card Development Workflow

If MCP (any configured server), requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: **stop this prompt**, report the objective error, and offer **`resolva` / `documente` / `resolva permanentemente`** (see **Chat commands** / **Tooling failures** in `workflow-policy.md`) and wait. Do not silently work around it, swap tools to hide the break, or keep implementing. If the failure looks like a wrong assumption in this prompt (bad command or missing step), also say that **this prompt may need updating**. Exception: `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is **MCP auth** in the shared workflow policy — do not call `mcp_auth` and do not ask the user to sign in again for that case only. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

### Chat commands

Recognize these user messages in this develop flow (shared table: `~/git/olie/prompts/workflow-policy.md` → **Chat commands**). Distinct from checklist `next` in §5.

| Command | Do this |
| --- | --- |
| `next prompt` | Run the next recommended prompt file (after this paste finishes: `~/git/olie/prompts/implementation-validation.md`). Open that file and execute it; do not wait for another paste. |
| `try again` | Resume or re-run **this** implementation prompt after a stop or a manual fix. Continue from the blocked checklist item when safe. |
| `to correct` | Only after implementation-validation reported **Needs code fixes**: implement those listed failures, then recommend re-running validation. If validation has not failed yet, say so and do not invent a correction list. |
| `add` | Only after `test-gap-analysis.md` reported **Tests to add**: implement those listed missing tests, then recommend `try again` on gap. Not for validation failures (`to correct`). |
| `finish card` | Destroy the host-card unit for this code (**Host card environment** in `workflow-policy.md`). Not the end of a normal implementation day. |

### Host card environment (required first)

Before media review, stage moves, or git work, run **Host card environment** in `~/git/olie/prompts/workflow-policy.md`:

```bash
~/git/bin/workvm-host-card ensure --project olie --code '{{ code }}'
```

**Shell (mandatory on the first call):** `required_permissions: ["all"]`. Do **not** probe ensure in the default sandbox “to see if it works” — that always fails with Permission denied on `~/.cursor/mcp.json` / `meta.json` / overlay (sandbox symptom, not a broken host). If Auto-review **Ask**/blocks that unrestricted call, retry the **exact same** command with `request_smart_mode_approval` (expected for ensure/open/destroy). If the footer still says SANDBOXING after `all`, use `workvm-host-card agent-ensure` (bridge). Detail: **Host card environment** / **Silent sandbox after `all`** in `workflow-policy.md`.

Idempotent: first paste creates the unit; a later day resumes it. Do **not** `destroy` when this paste ends or when the user stops for the day — only on `finish card` or when the card reaches `done` (see production-review). Report `id` / `workspace` / `port_base` in chat.

## 1. Context and Objective

Implement the card identified by `{{ code }}`. Its requirements, business rules, dependencies, and implementation context are available through the MCP OlieFlowAi.

Also read every project thread and the latest version of each one, using **Reading the project notebook** in `~/git/olie/prompts/workflow-policy.md`. The card text and those thread texts together are the source of truth for the intended behavior. Before making implementation decisions, inspect the relevant codebase, existing tests, and dependencies to understand the current behavior and identify potential side effects.

While reading the card (and again before locking the plan): apply **Deferred decisions on the card** in `~/git/olie/prompts/workflow-policy.md`. If the card defers a choice to the implementer — including alternatives joined by **ou** / **or** — **stop**, list the options, ask the user what to choose, and **end each question with your recommendation + why**. Before recommending, also read the **parent** and **children** cards (content + Caderno) when they exist. Do not apply the recommendation until they confirm.

### Card media review (required before the plan)

Before the planning phase, **review the card's media**. Spec screenshots, screencasts, and attachments are part of the source of truth — do not plan from text alone when media shows the intended UI or flow.

1. `git pull` the meta-repo if needed, then list media via MCP `get-project-media-tool` with **`filter: "default"`** (required — see **Project media** in `workflow-policy.md`; do not use the tool default `content`).
2. For each image, video, or audio item that belongs to this card and is part of the specification (or is cited by the description):
   - If `~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md` exists and is non-empty → **Read** it. Do not re-analyze.
   - If that file is **missing** → analyze now: `olie-project-image-analysis` for images, `olie-project-video-conversion` for video (API first; agent-local fallback when vid2agent is unreachable). Write the `.md` under `~/git/olie/cards/{CARD_CODE}/`.
3. Re-analyze or call vid2agent again **only** when the user asks to redo a specific media id (overwrite that file).
4. Use those analyses in the plan and checklist. Cite the media id when a requirement comes from a screenshot or screencast.
5. **Never** post image, video, or audio analysis to project content (`save-media-tool` or any MCP write of that markdown).
6. After writing **new** analysis files, commit and push them on the meta-repo `~/git` when you finish this media pass (or when the user asks).

## 2. Update the Card Stage

Before modifying code, load the card and its live funnel through MCP `olie-flow-ai`. Apply the stage-resolution and move procedure in `~/git/olie/prompts/workflow-policy.md`.

- If the card is still in `not-started` ('Não iniciado'), move it to `in-progress` ('Em progresso').
- If the card is already in `in-progress`, continue without moving it again.
- If the card is in another stage, do not move it automatically. Report its current stage and wait for instructions.
- Resolve the card UUID and target `step_id` from MCP / the live funnel. Use `OLIE_MANAGEMENT_TOKEN` for management HTTP auth (not the MCP token). Never hard-code ids or paste tokens.
- Verify that the stage transition succeeded before continuing.
- Do not start a project execution. The Opbed Job page (`/job`) does that (`~/git/olie/prompts/workflow-policy.md`).

## 3. Git Workflow

Before making any code changes:

1. Identify every repository the card changes and its configured base branch. Use the card when it specifies a base; otherwise use the repository's documented working branch in `~/git/olie/prompts/project.md`.
2. Check the current Git status in every affected repository. Preserve existing user changes and never overwrite, discard, or silently modify unrelated work.
3. Switch each affected repository to its base branch. If the working tree contains changes that could interfere with switching branches or updating the repository, stop and report the situation before proceeding.
4. Pull the latest changes from each base branch. If an update fails or cannot be completed safely, report the issue and wait for further instructions.
5. Read the card's content to identify the required branch name.
6. Create and switch to that card-specific branch from the updated base in every repository the card changes.
7. Verify every active branch before proceeding.

Do not implement the card on a base branch.

## 4. Planning Phase

Before implementing anything, analyze the card requirements and create a concrete implementation plan.

**Plan mode first (Cursor):** Before creating or presenting the plan/checklist, switch the chat to **Plan** mode (`SwitchMode` → `plan`). Investigate read-only and build the plan **while still in Plan mode**. Do not stay in Agent mode and “just write a checklist” in chat — that invites premature coding. Leave Plan mode only when the user sends `next` (or explicitly asks to implement / waives controlled mode). If `SwitchMode` is unavailable, still present the plan and stop; do not start coding.

### 4.1. Codebase Investigation

Inspect the relevant application code, architecture, business rules, dependencies, and existing tests.

Identify and document:

- The code responsible for the current behavior.
- Existing code that could interfere with, override, or otherwise affect the behavior being implemented or modified.
- Dependencies, indirect effects, and potential regressions.
- Relevant edge cases, error scenarios, and integration points.
- Existing tests and gaps in test coverage.

Document the findings that are relevant to implementation and testing. Do not modify unrelated code merely to simplify the implementation.

### 4.2. Test Coverage

Before implementing the card, inspect the private E2E suite (resolve the root per **Private E2E suites** / path resolution in `workflow-policy.md`: workspace folder `olie-e2e` on host-card, else `~/git/olie/olie-e2e`).

Determine whether the existing tests adequately cover the current behavior and the scenarios affected by the proposed changes.

If tests are missing or coverage is insufficient, add `create tests for the behavior` as an explicit item in the implementation checklist.

Do not assume that the absence of an obvious test means no relevant tests exist. Search the existing test suite and inspect related scenarios before identifying gaps.

Those Playwright specs are **private** (meta-repo only). Keep checklist/plan/chat references local to the WorkVM. Do **not** put `olie-e2e` paths or “e2e coverage” into card content, Caderno, company repos, or PR bodies — **Private E2E suites** in `~/git/olie/prompts/workflow-policy.md`.

### 4.3. Plan Documentation

Already in Plan mode (see **Plan mode first** above). Create the implementation plan in the agent's native planning mechanism (e.g. Cursor `CreatePlan`). If that mechanism is unavailable, use an ignored local card-work directory rather than adding an orchestration document to a product repository. Add repository documentation only when the card itself requires it.

The document must include:

- Card code and a concise description of the objective.
- Relevant requirements and acceptance criteria.
- Findings from the codebase investigation.
- Existing behavior that could interfere with the intended behavior.
- Test coverage assessment and identified gaps.
- An ordered implementation checklist.
- Potential risks, dependencies, and regression scenarios.
- A section titled 'Issues encountered during development'.

When the card touches the frontend (`olie-fronts`) or any HTTP/API path, the plan must also document these four items (agent plan only — do not paste them into card content):

- **Means:** every path through which the action can happen (UI control, API route, job, webhook, keyboard submit, deep link, etc.).
- **Request / performance impacts:** expected calls (including N+1 or two-or-more of the same request), whether debounce or duplicate-submit guards are needed, and any listing/query volume concern.
- **Screens and why:** which screens or flows change and why each is in scope.
- **Foreseen problems:** defects or regressions you expect before coding, with a mitigation or checklist item when known.

The checklist must contain small, independently reviewable tasks, ordered by dependency. Include testing, documentation, and verification tasks where applicable.

Do not begin implementation until the plan is documented and presented for review.

**Default after the plan:** stop. Do **not** start coding, scaffolding, or tests until the user sends **`next`**. Present the checklist clearly in chat so they can follow item by item.

## 5. Step-by-Step Implementation

Implementation runs in **controlled mode by default**: the user drives progress with `next` (one checklist item per `next`). Only skip controlled mode when the user explicitly asks to run the whole checklist without stopping (e.g. “implement everything”, “sem next”, “go”).

After presenting the plan:

1. **Wait** for the user to send `next`. Implement **only** the next incomplete checklist item (including its tests/verification for that item). Then stop again.
2. If the user explicitly waived controlled mode, implement the checklist in dependency order, reporting after each meaningful verification boundary.
3. Mark an item as complete only after its requirements have been implemented and the relevant verification has succeeded.
4. Update the plan whenever progress, findings, or implementation details change.
5. Report what changed, which files were affected, what verification was performed, and any remaining concerns.
6. After each item (controlled mode), stop and wait for the next `next` before another checklist item.

If a task reveals new requirements, unexpected dependencies, significant risks, or a need to change the plan, document the findings and present the proposed adjustment before proceeding with work that depends on that adjustment.

Do not skip checklist items, combine multiple independent items into one step, or implement subsequent items without authorization.

If an issue blocks the current item, explain the blocker and wait for instructions when resolving it requires a decision or action beyond the existing plan.

## 6. Development Issue Tracking

Maintain the section titled 'Issues encountered during development' in the plan document throughout the implementation.

Record problems discovered during investigation, implementation, and testing, including:

- Unexpected existing behavior.
- Bugs or inconsistencies in related code.
- Missing or unreliable test coverage.
- Environmental or configuration problems.
- Failed commands, tests, or verification steps.
- Relevant workarounds and unresolved risks.

For each issue, describe the observed problem, its impact, its status, and the resolution or proposed next action when known.

Do not silently omit failed checks or describe an issue as resolved without verification.

## 7. Temporary E2E CAPTCHA Configuration

reCAPTCHA has two sides: the **site key** (front widget) and the **secret** (`api-main` `siteverify`). Playwright stubs `grecaptcha` with a fake token. `api-main` skips `RecaptchaValidate` only when `APP_ENV=testing`. This VM is `local`, so the real secret answers `Token inválido` and a real development site key can still show Google challenges in the browser.

**Allowed local bypass (env only — Google's public test key pair):**

| Side | Where | Test value |
| --- | --- | --- |
| Secret | `~/git/olie/api-main/.env` → `RECAPTCHA_SECRET` | `6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe` |
| Site key | `~/git/olie/olie-fronts/packages/management/.env.development.local` → `VITE_APP_RECAPTCHA_SITE_KEY` | `6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI` |

With that pair, `siteverify` accepts any token (same window as `APP_ENV=testing`) and the browser widget does not force a real challenge. Use the secret for e2e/API; add the site-key `.local` file when the agent or a human must log in through the real management UI.

**Forbidden:** stubbing the management API; commenting out or deleting `RecaptchaValidate` / `getToken()` / related PHP or front code; editing tracked `packages/management/.env.development` for this; committing any of these local env overrides.

### Server secret

1. Confirm `~/git/olie/api-main/.env` is gitignored.
2. If `RECAPTCHA_SECRET` is not already the test secret, copy `.env` to `~/.config/workvm/api-main.env.recaptcha-backup` (`chmod 600`) before the first change. Do not put the original secret in the repo, in a comment, or in the chat.
3. Set `RECAPTCHA_SECRET` to the test secret.
4. Run `docker exec olie-api-main php artisan config:clear`. Smoke: `POST /api/management/login/identify` with JSON `{"email":"…","token":"test-token-…"}` and `Origin: http://devframe.olie.localhost` must return `method: password` (HTTP 200), not `invalid_token` / `required_token`.
5. Leave the test secret in place while e2e or browser login on this VM needs it. Restore the backup and run `config:clear` again when that work is finished or the user asks. Delete the backup after a successful restore. If the restore fails, say the test secret may still be active.
6. Never commit, push, or quote `.env` or the backup.

### Browser site key (when UI login must avoid Google challenges)

1. Write `packages/management/.env.development.local` with only `VITE_APP_RECAPTCHA_SITE_KEY=` plus the test site key above (Vite loads `*.local` over `.env.development`).
2. Keep that path in `olie-fronts/.git/info/exclude` (local exclude — do not change the committed `.gitignore` only for this).
3. Backup the previous development site key from tracked `.env.development` to `~/.config/workvm/management.recaptcha-site-key.backup` (`chmod 600`) before the first override.
4. `docker restart olie-front-management` so Vite reloads env.
5. Never commit `.env.development.local`. Restore by deleting that file and restarting the front (and restore the secret backup when asked).

If the API container or `api-main` `.env` is missing, stop and report that. Do not add a code bypass.

## 8. Code Quality and Validation

Follow the project's existing architecture, conventions, and established patterns. Prefer the smallest change that correctly satisfies the card's requirements.

- Avoid unrelated refactoring and unnecessary changes.
- Preserve existing behavior unless the card explicitly requires changing it.
- Do not edit `en.json`. English translations are resolved later. Add or update user-facing keys in `pt-br.json` only.
- Image/video/audio analysis: follow **Card media review** in §1 (skills `olie-project-image-analysis` / `olie-project-video-conversion`).
- Add or update tests to cover the intended behavior, relevant edge cases, and regressions.
- Run appropriate tests and verification commands for the current checklist item when the environment permits.
- Clearly distinguish successful checks from checks that failed, were skipped, or could not run.
- Document any verification limitations in the plan.

When the card changes `olie-fronts`, treat these as checklist items whenever they apply to a changed call or UI path (do not invent unrelated work):

- **Tenant / `frame_id`:** the front sends `frame_id` (or the project's established tenant context) on requests that the API scopes by frame.
- **Permission:** the UI respects the same permission gate the backend enforces (hide/disable or fail clearly; do not assume the API alone is enough for the card's UX).
- **i18n:** new or changed user-facing copy uses keys in `pt-br.json` only.
- **UX (evidence rows):** for UI paths this card touches, verify **contraste** (light+dark, Olie standard — not axe/WCAG gate), **feedback** (loading + API error visible), **comportamento** (acceptance, outside-click dismiss, clickable not covered). Cover in private e2e when stable; otherwise browser check and record for the Front evidence table — **UX rows** in `~/git/olie/prompts/workflow-policy.md`.
- **JS → TypeScript (gradual):** new front files are TypeScript (`.ts` / `.tsx` / `<script setup lang="ts">`) unless a concrete reason blocks it. When editing an existing JS file (or Vue without `lang="ts"`), convert it in this change when the blast radius fits the card; otherwise leave it JS and keep a clear reason for the evidence tables. Policy and card tables: **JS → TypeScript** under **Evidence table on project content** in `~/git/olie/prompts/workflow-policy.md`.
- **Options API → Composition API (gradual):** new Vue SFCs use Composition (`<script setup>` preferred). When editing an Options-API `.vue`, convert it when the blast radius fits the card; otherwise leave Options and keep a clear reason. Policy and card tables: **Options API → Composition API** in the same workflow-policy section.

**Do not run 'pint' unless the user explicitly instructs you to do so.** The pre-QA workflow is an explicit exception; follow `~/git/olie/prompts/workflow-policy.md` when it applies.

## 9. Completion Criteria

The card is complete only when all applicable checklist items have been completed and verified, including:

- The implementation satisfies the card's requirements and acceptance criteria.
- Relevant tests have been created or updated, and coverage gaps have been addressed as planned.
- Required tests and verification checks have been run, with any remaining limitations explicitly reported.
- Relevant documentation and the implementation checklist are up to date.
- The 'Issues encountered during development' section accurately reflects resolved and unresolved issues.
- No unrelated user changes have been overwritten or included unintentionally.
- No prohibited CAPTCHA configuration or secrets have been committed, pushed, or included in a pull request.

When all checklist items are complete, provide a concise final report covering the implementation, changed files, tests and verification results, unresolved issues, and any remaining manual actions.

Do not commit, push, or open a pull request unless explicitly requested and permitted by the applicable restrictions above.

**Do not recommend commit / push / PR** at the end of this paste — not even as a “when you are ready” hint. Product commits belong to **`pre-qa.md`** after the rest of the develop handoff has run (`implementation-validation.md`, then when `api-main` changed: gap → coverage → mutation → `pest-parallel.md`, then `pre-qa.md`). In the completion report, recommend only the **next prompt** (`implementation-validation.md` via `next prompt`).

When implementation work on this paste is done, the next recommended prompt is `~/git/olie/prompts/implementation-validation.md` (code-only). The user may send `next prompt` to run it without pasting. Do not run `~/git/olie/prompts/pre-qa.md` or board `~/git/olie/prompts/validation.md` yet.

The durable **Evidence table** on the card content (`save-media-tool`, `### Evidência — Implementation`) is written at the end of **`pre-qa.md`**, not on this paste — never description, Caderno, or PR; see **Evidence table on project content** in `~/git/olie/prompts/workflow-policy.md`. When `olie-fronts` (or other front packages) changed, that block must include the migration tables when they have rows: JS→TS (**Arquivos mexidos mas não convertidos para TypeScript** / **Novos arquivos que nasceram em JavaScript**) and Options→Composition (**Arquivos Vue mexidos mas não convertidos para Composition API** / **Novos arquivos Vue que nasceram em Options API**). Track those reasons during this paste so pre-QA can upsert them accurately.