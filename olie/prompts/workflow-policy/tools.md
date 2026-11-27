# Olie Workflow Policy — Tools & auth

Load this module when the prompt needs tool order, GitHub read/write, MCP auth, tokens, or prompt-health stops.

Index: `~/git/olie/prompts/workflow-policy.md`

## Tool preference

When more than one tool can do the same job, use this order (do not skip ahead to avoid a prompt):

1. **MCP** — `olie-flow-ai` for card/board/forms; GitHub MCP for PR approve/merge/read when the prompt uses those tools.
2. **`gh`** — GitHub CLI when MCP is the wrong tool or unavailable. **Exception:** manager **Pre-QA** (`bin/workvm-host-card-pre-qa`) **creates** PRs with `gh` first (GitHub MCP App form deferral / weak assignee-label support); agent does not drive create in chat — see `pre-qa.md`.
3. **curl / management HTTP** — last resort when MCP itself is `needsAuth` / 401, or inside **scripts** (Pre-QA, card dump). Never prefer HTTP over working MCP. Never invent move/checklist/Caderno curl in chat.

### GitHub reads vs writes (Auto-review)

- **MCP (read):** login, PRs, labels, checks, collaborator lookups.
- **`gh` (write):** manager **Pre-QA** owns `gh pr create` / `edit` / push for handoff. Agent does not drive create in the normal paste.
- Do **not** shell `gh pr list` / `gh api user` / `gh auth status` only to discover data MCP can read.

Never paste a Bearer token. Never silently swap tools to hide a failure (except `olie-flow-ai` `needsAuth` → **MCP auth** below).

## MCP auth

Desktop can show `olie-flow-ai` authenticated while this agent still gets `needsAuth` (host OAuth discovery vs local proxy with `MCP=olie` → `127.0.0.1:47331`). Do **not** call `mcp_auth`. Do **not** ask the user to sign in again for that case only. Keep using MCP tools against the proxied server.

If tools stay `needsAuth` / 401 after that: prefer Card Spec / manager artifacts already on disk; otherwise stop (prompt-health) — do **not** paste search/`get-available-steps` curl recipes. Scripts may use `OLIE_MANAGEMENT_TOKEN`; the agent paste should not.

## Tokens

Two env vars in `~/.config/environment.d/*.conf` (`chmod 600`). Never the same value by assumption; never paste into chat or repo files.

| Variable | Use |
| --- | --- |
| `OLIE_FLOW_AI_MCP_TOKEN` | Cursor MCP `olie-flow-ai` only (`mcps/olie.json` → `${env:OLIE_FLOW_AI_MCP_TOKEN}`) |
| `OLIE_MANAGEMENT_TOKEN` | HTTP for **scripts** / last-resort MCP auth (`workvm-host-card-pre-qa`, card dump helpers). Needs `management:access`. Agent paste: prefer MCP; do not invent curl for move/checklist. |

Layout and examples: `~/git/.config/environment.d/README.md`.

## Tooling failures and stalls (prompt health)

If a request, **MCP call** (any configured server), shell command, Docker/compose wait, git/gh, or other step **this prompt assumes will work** fails or takes unusually long — or the same **recurring** host-card friction burns time on every card — **stop the prompt**. Do not silently work around it, swap tools to hide the break, or keep going. `olie-flow-ai` `needsAuth` while the Cursor desktop already shows that server authenticated is the **MCP auth** case in this module, not this stop — do not ask the user to sign in again for that case only. Host-card **sandbox permission cluster**: retry with `required_permissions: ["all"]` first (see **Host card environment** in `workflow-policy/host.md`); that is not “host broken”.

Diagnose, then **wait** for one of `resolva` / `documente` / `resolva permanentemente` (**Chat commands** in `workflow-policy/gates.md`). Do not pick the path yourself.

Report:

1. What you were doing
2. The objective error (status, short message) or that it hung past a reasonable wait
3. The most likely cause
4. Whether `~/git/HISTORICO.md` or an existing rule/prompt **already documents** this — cite it if so
5. The three commands (`resolva` / `documente` / `resolva permanentemente`) and that you are waiting

Expected failures of the current task (e.g. testing an error path) can be reported and continued when that still makes sense.
