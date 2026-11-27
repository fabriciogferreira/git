# Olie Workflow Policy — Card context

Load this module for Caderno, media, deferred decisions, card-vs-chat, PR feedback/links, prompt templates.

Index: `~/git/olie/prompts/workflow-policy.md`

## Reading the project notebook (Caderno)

**Default:** manager **Card Spec** → `olie/cards/<CODE>/notebook/` (index + every page). Read that. Do **not** MCP-walk the Caderno when the dump exists.

Older names (forum/thread) = notebook/page. One notebook per project.

If the dump is **missing** and the prompt still requires Caderno: **stop** and tell the user to run **Card Spec** (implementation / correction / colleague). Do not rebuild via `get-notebook-tool` / `read-notebook-page-tool` unless the user explicitly asks to bypass. Never Bearer-curl Caderno; `workvm-olie-management-read.sh` only under **MCP auth** when a rare non–Card-Spec path still needs it.

## Project media

**Default:** `olie/cards/<CODE>/media.md` from **Card Spec** (timeline with system logs). Colleague bounce classification uses that file — not a live MCP re-list.

If the dump is missing: stop → Card Spec (same prompts as Caderno). Exception: a prompt that **must** refresh live media and the user asked — then MCP `get-project-media-tool` with **`filter: "default"`** only (never omit / never `content`; that hides funnel logs). Do not invent other filters.
## Prompt templates (`{{ code }}`)

Files under `~/git/*/prompts/` are paste templates. The repo keeps the literal placeholders (always `{{ code }}`, plus any other mustache tokens the file declares). Replacing them with a real card code happens only in the chat paste, never in the versioned file.

**Do not edit the template in the editor** to swap `{{ code }}` — that dirties the shared meta-repo and shows up in every host-card window. Prefer a chat command (agent reads the file, substitutes in memory, runs — no save):

- `colleague review DOP-1285`
- `run prompt colleague-review DOP-1285`
- or `@colleague-review.md` + the card code in the same message

Optional clipboard helper (no agent): `~/git/bin/workvm-paste-prompt olie colleague-review DOP-1285` → clipboard + `@.paste-prompt.md`. Do **not** create a git worktree of `~/git` just to isolate this edit.

## Card media analyses (meta-repo)

Image/video/audio analyses under `olie/cards/{CARD_CODE}/` are written to disk during the media pass. **Do not** commit or push them in `implementation.md`, `correction.md`, or mid-media-pass in colleague/production review.

| When | Who commits/pushes |
| --- | --- |
| Develop handoff | `pre-qa.md` §4.3 (required if those paths are dirty) |
| Colleague review | Closing meta step of that prompt (with private e2e when applicable — §3) |
| Production review | Closing meta step of that prompt |

Same rule for Locav / Televisão card folders and their media skills. Local `.md` reuse still applies before the push.

When committing or pushing the meta-repo `~/git` (e2e, card media analyses, prompt edits, or any other path):

- Do **not** stage, commit, or push a prompt whose only “edit” is a substituted card code (e.g. `DOP-1262` instead of `{{ code }}`).
- If a prompt is dirty that way, restore it (`git checkout -- path`) before the commit.
- Intentional prompt wording changes are fine; leave `{{ code }}` (and the other placeholders) intact.

## Closing PR review feedback

GitHub exposes review feedback in two shapes. Agents must close both; chat-only “done” is not enough.

| Shape | How it appears | How to close |
| --- | --- | --- |
| **Inline thread** | Line/file conversation; has **Resolve** | After the fix **and** the validation stack for this return (at least `implementation-validation`; when `api-main` changed also gap → coverage → mutation → Pest parallel as applicable): mark the thread **Resolved** (`resolveReviewThread` / MCP). |
| **Review body** | Summary on `CHANGES_REQUESTED` / substantive `COMMENTED` with **no** inline threads | GitHub has **no** Resolve on the body. After every actionable point is addressed **and** that same validation stack has passed: post **one** public PR audit comment listing each point (`✅` / `⬜` + reason) with commit SHAs on the **pushed** tip. Do **not** dismiss the review to fake closure. |

**Timing (do not invert):**

1. **`correction.md`** — implement fixes + local regression tests; draft the audit checklist in the chat report. Do **not** Resolve threads, do **not** post the audit comment, and do **not** treat commit/push as “closing the review” in that paste.
2. **`implementation-validation.md`** (then gap → coverage → mutation → `pest-parallel` when backend changed).
3. **`pre-qa.md` Phase B** — after manager **Pre-QA** moved the card: Resolve + audit comment (§5.0 intent). Move/checklist/PR create are the manager script.

Marking a finding “resolved” on GitHub before those validations is a miss: the reviewer would see green closure on an unvalidated tip.

Loading feedback for correction / return to 'QA/CR':

1. Resolve associated PR URLs (**Code review form** / card PR fields / project content).
2. Read **threads** (`get_review_comments` / `reviewThreads`) **and** **reviews** (`get_reviews`). Empty threads alone ≠ “no PR feedback”.
3. Triage every actionable thread comment and every actionable body bullet like any other finding.

`correction.md` §10b prepares the close (draft only). Manager **Pre-QA** moves back to 'QA/CR'; `pre-qa.md` Phase B **owns** the public close (Resolve + audit) when returning from Corrigir.

## Pull request links on the card

Manager **Pre-QA** writes PR URLs into form fields (and notes leftovers in the artifact). Agent: verify URLs on the Pre-QA artifact / scoreboard; do **not** re-drive `set-form-answers-tool` / description append for the normal handoff. If Apply left a gap and the user asks you to fix links only, match existing form fields by label — never invent fields; never wipe the description.

## Deferred decisions on the card

Card text sometimes **defers** a product or design choice to whoever implements (the human in this develop chat). That is an open decision — **not** permission for the agent to pick alone.

Signals in the card description, tasks, acceptance criteria, media notes, or Caderno:

- Explicit handoffs: “decidir”, “a critério do implementador”, “deixar em aberto”, “confirmar com…”, “TBD”, “TODO decisão”
- Alternatives joined by **ou** / **or** that read as a choice the implementer must make (e.g. “usar X ou Y”, “endpoint A ou B”, “manter no front ou mover para a API”)
- Soft forks that still need a pick: “preferencialmente”, “idealmente”, “se fizer sentido”, “pode ser…” when two paths remain viable

When you find any of these **before the plan is finished** (and again if one appears mid-implementation or mid-correction):

1. **Stop** the prompt — do not invent a choice, do not apply your recommendation as if it were decided, do not continue the checklist past that fork.
2. List each open decision with the literal card phrasing and the concrete options you see.
3. Ask the user (the implementer in this chat) what must be done / which option to take.
4. **For every decision you ask about**, end that question with an explicit **recommendation**: which option you recommend and **why**. Before writing that recommendation, load context beyond the current card:
   - **This card:** description, media (`filter: "default"`), and Caderno (**Reading the project notebook**).
   - **Parent card** (when `project.md` lists parent): read that code’s Card Spec dump when present; ask the user to Card Spec it if missing — do not MCP-rebuild by default.
   - **Child cards** (every entry in `children` on this project's details): each child's details/description, media, and full Caderno the same way.
   Ground the recommendation in those texts **plus** this project's code patterns, conventions, and sibling implementations. Cite which parent/child (CODE) informed the advice when it did. The recommendation is advice only — the user still chooses; never treat it as the answer until they confirm. Missing parent/children or empty Cadernos are fine — note that and continue from what exists (not a tooling failure).
5. Resume only after they answer. Record the chosen option (and a short **motivo** when the choice is not already obvious from the wording) in the plan — you will post them on the card at pre-QA.

Do **not** treat an ordinary “or” / “ou” inside a single fixed requirement as a deferral (e.g. “email or phone required” as an already-decided validation rule). When unsure whether a sentence is a deferral, **ask**.

Applies to every card-driven paste that would commit to one of the alternatives — especially `implementation.md` and `correction.md`. Same rule for Locav and Televisão (`~/git/locav/prompts/workflow-policy.md`, `~/git/televisao/prompts/workflow-policy.md`).

### Decisions table on project content (pre-QA)

When **at least one** deferred decision was answered in this develop chat, post a short Brazilian Portuguese **decisions table** into the **card content** with MCP **`save-media-tool`** at the end of **`pre-qa.md`**, in the **same moment** as the evidence table and **always before** it (two `save-media-tool` calls: Decisões first, then Evidência). Same destination rules as evidence: **only** card content — never description, Caderno, or PR.

**Omit** the whole decisions post when no deferred decision was asked/answered for this round.

| Trigger | Heading (exact `###` line) |
| --- | --- |
| Implementation handoff (`pre-qa.md` → 'QA/CR') | `### Decisões — Implementation` |
| Correction return (`pre-qa.md` after Corrigir) | `### Decisões — {N}º Correção` |

`{N}` matches the **same** Correção round as the evidence heading for that pre-QA. Refresh the same round by posting again with the **same exact** `###` line (latest media wins).

Columns:

| Column | Content |
| --- | --- |
| `decisão (trecho do card)` | Short literal / paraphrase of the open fork from the card |
| `opções` | The alternatives that were on the table |
| `escolha` | What the implementer chose |
| `motivo` | Why — **required** unless the escolha already makes the reason obvious (then use `—` or a one-word echo, not a fake essay) |

No prompt paths, no VM/sandbox/ledger jargon. Chat keeps the full Q&A; the card table is the compact public record for QA/CR.

```markdown
### Decisões — Implementation

| decisão (trecho do card) | opções | escolha | motivo |
| --- | --- | --- | --- |
| "usar X ou Y no endpoint" | X / Y | X | alinha ao contrato já usado em Z |
```

## Card content vs chat (private prompts)

Files under `~/git/olie/prompts/` are private host prompts. Other people on the Olie board cannot open them.

When writing to card content through OlieFlowAi (`save-media-tool`, description, forum, notebook/Caderno, or any project note):

- Write only findings, acceptance gaps, and fix instructions the author can act on without this meta-repo — **plus** the **Decisions table on project content** and the **Evidence table on project content** below (allowed exceptions).
- Do **not** name prompt files or paths (`colleague-review.md`, `colleague-review-core.md`, `test-gap-analysis.md`, `mutation-testing.md`, `coverage-testing.md`, `correction.md`, `~/git/.../prompts/...`, “next paste”, `next prompt`).
- Do **not** tell the author which local prompt to run next.
- Do **not** cite private meta-repo E2E (see **Private E2E suites** in `workflow-policy/host.md`).
- Do **not** cite personal host-card / sandbox / dispatcher / ledger tooling. That stack exists only for the owner of this meta-repo. Ban on the card (and Caderno): `host-card`, `sandbox`, `workvm-sandbox`, `dispatcher`, `ledger`, `mutation-ledger`, `coverage-ledger`, “nesta máquina”, hostnames, compose service names used only here, and process notes that only make sense with those tools (“fechamento do gate”, “Pest raw score”, “in-scope hunks”). Put that detail in the Cursor chat scoreboard only.
- If a gate is clean and there is nothing for the author to change, **do not** post a prose process wrap-up to the card. The **Evidence table** still applies when the trigger says to write it; silence otherwise is fine; the chat report remains required.
- On colleague review, do **not** dump gap / mutation / coverage **findings lists** onto the card during **reviewer-fix** (those stay in chat). Include author-facing findings when bouncing to 'Corrigir' for a failure outside those three gates — see **Project content (gap / mutation / coverage)** under **Colleague review outcome**. The **Evidence table** on Pass or Corrigir bounce is separate and **required** (`workflow-policy/evidence.md`).

Recommend the next prompt **only in the Cursor chat** report.

**No premature commit hints:** after `implementation.md` / `correction.md` (and any gate before `pre-qa.md`), do **not** suggest committing, pushing, or opening a PR for the product repos. Say only the next workflow prompt (`next prompt` / coverage / mutation as applicable). Product push/PR + board move are owned by manager **Pre-QA**; agent `pre-qa.md` Phase A/B wraps judgment + evidência.
