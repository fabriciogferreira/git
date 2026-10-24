# MCP do Cursor

Cada arquivo desta pasta é um destino (`olie.json` → OlieFlowAi), sem token. O `project.conf` do projeto ativo diz qual entrar no merge (`MCP=olie` → só `mcps/olie.json`). Projetos sem `MCP=` não recebem nada daqui.

`MCP=olie` só é permitido em **olie**, **locav** e **televisao** (`workvm_apply_mcp` recusa nos demais).

No `project-start` (login / setup), o merge vai para `~/.cursor/mcp.json` (user-level), junto com os `.cursor/mcp.json` versionados dos clones e dos e2e. Assim o Cursor não pede opt-in de project MCP a cada abertura. Tokens Olie ficam em `~/.config/environment.d/*.conf`.

`olie-flow-ai` no arquivo versionado aponta para `https://api.olie.ai/mcp/management`. O merge grava `http://127.0.0.1:47331/mcp/management` sem header: esse host publica descoberta OAuth e o Cursor não manda o Bearer. O `workvm-olie-mcp-proxy` responde 404 nisso e encaminha com `OLIE_FLOW_AI_MCP_TOKEN`.

PRs (pre-QA) usam **GitHub CLI** (`gh` / pacote `github-cli` no `vm-setup`), não um MCP GitHub nesta pasta. Auth: `gh auth login`.
