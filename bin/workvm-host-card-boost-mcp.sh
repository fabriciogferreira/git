#!/usr/bin/env bash
# Laravel Boost MCP no host-card Olie.
# Problema: o overlay aponta para o container WorkVM `olie-api-main`; no
# jarvis cada card é `hc-olie-*-app-1` e o mcp.json user-level é um só.
# Este wrapper lê o container do card ativo (ensure / open Cursor).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POINTER="${XDG_CONFIG_HOME:-$HOME/.config}/workvm/host-card-boost-container"
DOCKER_MCP="${ROOT}/bin/workvm-docker-mcp.sh"

container=""
if [ -f "$POINTER" ]; then
    container="$(tr -d '[:space:]' <"$POINTER" || true)"
fi
if [ -z "$container" ]; then
    container="$(
        docker ps --format '{{.Names}}' 2>/dev/null \
            | grep -E '^hc-olie-.+-app-1$' \
            | head -1 || true
    )"
fi
if [ -z "$container" ]; then
    echo "workvm-host-card-boost-mcp: nenhum container hc-olie-*-app-1 (rode ensure)" >&2
    exit 1
fi

exec "$DOCKER_MCP" "$container" php artisan boost:mcp
