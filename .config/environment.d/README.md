# `environment.d` — env local para apps gráficos

Este path deve ser um **diretório** de arquivos `*.conf` (estilo systemd),
nunca um arquivo único chamado `environment.d`.

O overlay `~/git/.config` → `~/.config` (vm-setup) e o Hyprland/Cursor leem
`~/.config/environment.d/*.conf` para interpolar `${env:NAME}` nos headers MCP
e para o shell do agente nas requests HTTP de management.

## Tokens Olie (dois papéis)

Crie um arquivo local (não versionado):

```bash
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/olie.conf <<'EOF'
# MCP olie-flow-ai only (Cursor ${env:OLIE_FLOW_AI_MCP_TOKEN})
OLIE_FLOW_AI_MCP_TOKEN=seu_token_mcp_aqui
# Management HTTP API (move card, project-executions, etc.)
OLIE_MANAGEMENT_TOKEN=seu_token_management_aqui
EOF
chmod 600 ~/.config/environment.d/olie.conf
```

- **`OLIE_FLOW_AI_MCP_TOKEN`** — só o MCP `olie-flow-ai` (`mcps/olie.json`).
- **`OLIE_MANAGEMENT_TOKEN`** — Bearer das requests `https://api.olie.ai/api/management/...` nos prompts (`workflow-policy.md`). Precisa da ability `management:access` (ex.: sessão/PAT do app, não o token do MCP). O site, ao criar um card com código Olie, lê o story point com este token e com o do MCP.

### GitHub (PRs)

Use **GitHub CLI** (`gh`), instalado pelo `vm-setup.sh` (`github-cli`):

```bash
gh auth login
gh auth status
```

Não coloque PAT do GitHub no `environment.d` só para o agente: o pre-QA usa `gh pr create` / `gh pr edit` com a sessão do `gh`. Se ainda existir `GITHUB_PERSONAL_ACCESS_TOKEN` no `olie.conf` de tentativas antigas com MCP, pode remover.

Depois feche o Cursor por completo e reabra (login gráfico) se mudou tokens Olie.

`*.conf` com secrets ficam só no live (`~/.config`); não copiar para o git.

## Token do Opbed

O sync dos prompts (`opbed-prompts.mdc`) lê o Bearer da API `https://api.opbed.com`. O valor tem `|`; entre aspas, senão um `source` trata o pipe como comando.

```bash
cat > ~/.config/environment.d/opbed.conf <<'EOF'
OPBED_API_TOKEN="cole_o_bearer_aqui"
EOF
chmod 600 ~/.config/environment.d/opbed.conf
```
