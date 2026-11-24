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

# Fail-fast se o container nem existe (stack back-only). Sem isso o
# workvm-docker-mcp espera 180s e o Cursor fica em "loading".
DOCKER_BIN=/usr/bin/docker
[ -x "$DOCKER_BIN" ] || DOCKER_BIN="$(command -v docker 2>/dev/null || true)"
if [ -n "$DOCKER_BIN" ]; then
    state="$("$DOCKER_BIN" inspect -f '{{.State.Status}}' "$container" 2>/dev/null || true)"
    if [ -z "$state" ]; then
        echo "workvm-host-card-playwright-mcp: $container ausente (stack back-only?). Rode: workvm-host-card add --project olie --code <CODE> --group front" >&2
        exit 1
    fi
fi

exec "$PW_MCP" "$container"
