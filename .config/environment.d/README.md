# `environment.d` — env local para apps gráficos

Este path deve ser um **diretório** de arquivos `*.conf` (estilo systemd),
nunca um arquivo único chamado `environment.d`.

O overlay `~/git/.config` → `~/.config` (vm-setup) e o Hyprland/Cursor leem
`~/.config/environment.d/*.conf` para interpolar `${env:NAME}` nos headers MCP.

## Token Olie Flow AI (MCP)

Crie um arquivo local (não versionado):

```bash
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/olie.conf <<'EOF'
OLIE_FLOW_AI_TOKEN=seu_token_aqui
EOF
chmod 600 ~/.config/environment.d/olie.conf
```

Depois feche o Cursor por completo e reabra (via `start.sh` / login gráfico).

`*.conf` com secrets ficam só no live (`~/.config`); não copiar para o git.
