#!/usr/bin/env bash
# Cursor sobe no login antes do compose. docker exec falha na hora e o MCP
# fica failed até reiniciar. Espera o container e só então encaminha o stdio.
# Uso (mcp.json): command=este-script, args=[container, cmd...]
# Não sobe o compose; só espera. Timeout: WORKVM_DOCKER_MCP_WAIT_SECONDS (180).
#
# Silêncio no stderr enquanto espera: o Cursor trata qualquer stderr como
# [error] e cancela/reconecta o MCP no meio da espera (Client closed).
set -euo pipefail

container="${1:-}"
if [ -z "$container" ]; then
    echo "usage: workvm-docker-mcp.sh <container> <command...>" >&2
    exit 2
fi
shift

if [ "$#" -eq 0 ]; then
    echo "workvm-docker-mcp: missing command after container '$container'" >&2
    exit 2
fi

# Electron/Cursor often has a short PATH; prefer the absolute binary.
DOCKER_BIN="${DOCKER_BIN:-}"
if [ -z "$DOCKER_BIN" ]; then
    if [ -x /usr/bin/docker ]; then
        DOCKER_BIN=/usr/bin/docker
    elif command -v docker >/dev/null 2>&1; then
        DOCKER_BIN="$(command -v docker)"
    else
        echo "workvm-docker-mcp: docker not found" >&2
        exit 1
    fi
fi

timeout_sec="${WORKVM_DOCKER_MCP_WAIT_SECONDS:-180}"
deadline=$((SECONDS + timeout_sec))

while true; do
    state="$("$DOCKER_BIN" inspect -f '{{.State.Status}}' "$container" 2>/dev/null || true)"
    if [ "$state" = "running" ]; then
        break
    fi
    if [ "$SECONDS" -ge "$deadline" ]; then
        echo "workvm-docker-mcp: $container not running after ${timeout_sec}s (state=${state:-missing})" >&2
        exit 1
    fi
    sleep 1
done

# Optional workdir (e.g. televisao-backend → /srv). Must precede the
# container name on `docker exec`; keep it out of MCP args so the command stays clean.
workdir_args=()
if [ -n "${WORKVM_DOCKER_MCP_WORKDIR:-}" ]; then
    workdir_args=(-w "$WORKVM_DOCKER_MCP_WORKDIR")
fi

exec "$DOCKER_BIN" exec -i "${workdir_args[@]}" "$container" "$@"
