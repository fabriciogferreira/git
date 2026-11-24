#!/usr/bin/env bash
# MCP PrimeVue no Cursor. Problema: mcp.json com `command: npx` usa o shim
# mise; quando o install lazy do node está incompleto (comum pós-reinstall
# do Cursor), a discovery falha com "npx is not a valid shim". Depois do
# wipe de $HOME, o cache `~/.npm/_npx/*/package.json` some e o npx dá
# ENOENT — Cursor marca o server como error. Avisos do mise no stderr
# também fazem o Cursor cancelar o MCP ([error]).
# Este wrapper: repara node/npx, limpa cache npx sem package.json, chama
# o binário absoluto e silencia mise no stderr de resolução.
# Uso (mcp.json): command=este-script, args=[]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENSURE="${ROOT}/bin/workvm-ensure-mise-node.sh"

# Quiet resolve — Cursor treats any stderr as MCP failure.
resolve_npx() {
    local node_bin="" npx_bin=""
    if [ -x /usr/bin/mise ]; then
        node_bin="$(/usr/bin/mise which node 2>/dev/null || true)"
    fi
    if [ -n "$node_bin" ] && [ -x "$(dirname "$node_bin")/npx" ]; then
        printf '%s\n' "$(dirname "$node_bin")/npx"
        return 0
    fi
    ls -1d "${HOME}/.local/share/mise/installs/node"/*/bin/npx 2>/dev/null \
        | sort -V \
        | tail -1
}

# Wipe incomplete npx -y dirs (node_modules without package.json).
repair_npx_cache() {
    local cache="${HOME}/.npm/_npx" d
    [ -d "$cache" ] || return 0
    shopt -s nullglob
    for d in "$cache"/*/; do
        if [ ! -f "${d}package.json" ]; then
            rm -rf "$d"
        fi
    done
    shopt -u nullglob
}

if [ -x "$ENSURE" ]; then
    "$ENSURE" >/dev/null 2>&1 || true
fi

npx_bin="$(resolve_npx || true)"
if [ -z "${npx_bin:-}" ] || [ ! -x "$npx_bin" ]; then
    echo "workvm-primevue-mcp: npx ausente — rode ~/git/bin/workvm-ensure-mise-node.sh" >&2
    exit 1
fi

repair_npx_cache

# Prefer a clean env for npm (no mise shim PATH / stray NPM_CONFIG_*).
export PATH="$(dirname "$npx_bin"):/usr/bin:/bin"
unset NPM_CONFIG_DEVDIR 2>/dev/null || true

exec "$npx_bin" -y @primevue/mcp "$@"
