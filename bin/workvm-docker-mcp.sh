#!/usr/bin/env bash
# Cursor sobe no login antes do compose. docker exec falha na hora e o MCP
# fica failed até reiniciar. Espera o container e só então encaminha o stdio.
# Uso (mcp.json): command=este-script, args=[container, cmd...]
# Não sobe o compose; só espera. Timeout: WORKVM_DOCKER_MCP_WAIT_SECONDS (180).
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

if ! command -v docker >/dev/null 2>&1; then
    echo "workvm-docker-mcp: docker not in PATH" >&2
    exit 1
fi

timeout_sec="${WORKVM_DOCKER_MCP_WAIT_SECONDS:-180}"
deadline=$((SECONDS + timeout_sec))
logged=0

while true; do
    state="$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || true)"
    if [ "$state" = "running" ]; then
        break
    fi
    if [ "$SECONDS" -ge "$deadline" ]; then
        echo "workvm-docker-mcp: $container not running after ${timeout_sec}s (state=${state:-missing})" >&2
        exit 1
    fi
    if [ "$logged" -eq 0 ]; then
        echo "workvm-docker-mcp: waiting for $container (compose still starting)" >&2
        logged=1
    fi
    sleep 1
done

exec docker exec -i "$container" "$@"
