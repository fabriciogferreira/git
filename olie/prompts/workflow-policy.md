# Olie Workflow Policy

Shared Olie rules split so agents **open only the module the current prompt needs** — do not load every file under `workflow-policy/`.

| Module | When to open |
| --- | --- |
| [`workflow-policy/tools.md`](./workflow-policy/tools.md) | Tool preference, GitHub MCP vs `gh`, MCP auth, tokens, tooling failures / `resolva` |
| [`workflow-policy/gates.md`](./workflow-policy/gates.md) | Re-run budget, Pest TIA, backend change-set, colleague review outcome, chat commands |
| [`workflow-policy/board.md`](./workflow-policy/board.md) | Board stages, agent MCP moves, bans on hand checklist/curl (QA/CR handoff = manager Pre-QA) |
| [`workflow-policy/host.md`](./workflow-policy/host.md) | Host-card ensure/open/destroy, CAPTCHA, payment cards, production URL, docs ban, private e2e, language/formatting |
| [`workflow-policy/card-context.md`](./workflow-policy/card-context.md) | Caderno, project media, Card Spec/media analyses, deferred decisions, card content vs chat, PR feedback/links |
| [`workflow-policy/evidence.md`](./workflow-policy/evidence.md) | Decisions + Evidence tables (`save-media-tool`) |

Prompts should cite the **section name** and the **module path** (e.g. **Host card environment** in `workflow-policy/host.md`). Legacy references to this file alone still mean: open the matching module above — not the whole tree.

Not usually pasted alone; other Olie prompts pull the slice they need.
