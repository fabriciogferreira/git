# MCP do Cursor

O mesmo MCP serve a mais de um projeto. Cada arquivo desta pasta é um destino (`olie.json` conecta na Olie), sem token. O `project.conf` aponta o MCP principal (`MCP=olie`); no login o merge inclui **todos** os `mcps/*.json`.

No `project-start` (login / setup), o merge vai para `~/.cursor/mcp.json` (user-level), junto com os `.cursor/mcp.json` versionados dos clones e dos e2e. Assim o Cursor não pede opt-in de project MCP a cada abertura. Tokens Olie ficam em `~/.config/environment.d/*.conf`.

PRs (pre-QA) usam **GitHub CLI** (`gh` / pacote `github-cli` no `vm-setup`), não um MCP GitHub nesta pasta. Auth: `gh auth login`.
