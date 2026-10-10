# MCP do Cursor

O mesmo MCP serve a mais de um projeto. Cada arquivo desta pasta é um destino (`olie.json` conecta na Olie), sem token. O `project.conf` só diz o nome (`MCP=olie`).

No `project-start` (login / setup), o merge vai para `~/.cursor/mcp.json` (user-level), junto com os `.cursor/mcp.json` versionados dos clones e dos e2e. Assim o Cursor não pede opt-in de project MCP a cada abertura. O token continua em `~/.config/environment.d/*.conf`.
