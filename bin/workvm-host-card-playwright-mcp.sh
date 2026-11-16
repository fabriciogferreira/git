#!/usr/bin/env bash
# Playwright MCP no host-card Olie via container olie-e2e.
# Problema: workvm-playwright-mcp.sh espera um nome de container; no jarvis
# cada card sobe `hc-olie-*-olie-e2e-1` (ensure) e o mcp.json user-level é um só.
# Lê o pointer do card ativo (mesmo padrão do Boost).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POINTER="${XDG_CONFIG_HOME:-$HOME/.config}/workvm/host-card-e2e-container"
PW_MCP="${ROOT}/bin/workvm-playwright-mcp.sh"

container=""
if [ -f "$POINTER" ]; then
    container="$(tr -d '[:space:]' <"$POINTER" || true)"
fi
if [ -z "$container" ]; then
    container="$(
        docker ps --format '{{.Names}}' 2>/dev/null \
            | grep -E '^hc-olie-.+-olie-e2e-1$' \
            | head -1 || true
    )"
fi
if [ -z "$container" ]; then
    echo "workvm-host-card-playwright-mcp: nenhum hc-olie-*-olie-e2e-1 (rode ensure)" >&2
    exit 1
fi

exec "$PW_MCP" "$container"
