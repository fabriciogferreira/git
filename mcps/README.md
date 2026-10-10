# MCP do Cursor

O mesmo MCP serve a mais de um projeto. Cada arquivo desta pasta é um destino (`olie.json` conecta na Olie), sem token. O `project.conf` só diz o nome (`MCP=olie`). No `project-setup` e no login, a cópia vai para `~/git/.cursor/mcp.json`, que é a raiz que o Cursor abre. O token continua em `~/.config/environment.d/*.conf`.
