#!/usr/bin/env bash
# MCP PrimeVue no Cursor. Problema: mcp.json com `command: npx` usa o shim
# mise; quando o install lazy do node está incompleto (comum pós-reinstall
# do Cursor), a discovery falha com "npx is not a valid shim" e o server
# aparece como error/mcp_auth. Este wrapper garante node/npx e chama o
# pacote com o binário real sob installs/node/*/bin (não o shim).
# Uso (mcp.json): command=este-script, args=[]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENSURE="${ROOT}/bin/workvm-ensure-mise-node.sh"

if [ -x "$ENSURE" ]; then
    "$ENSURE" || true
fi

export PATH="${HOME}/.local/share/mise/shims:/usr/bin:/bin:${PATH:-}"

# Prefer absolute npx from the active mise node install (shim may still lie).
npx_bin=""
if command -v mise >/dev/null 2>&1; then
    node_bin="$(mise which node 2>/dev/null || true)"
    if [ -n "$node_bin" ] && [ -x "$(dirname "$node_bin")/npx" ]; then
        npx_bin="$(dirname "$node_bin")/npx"
    fi
fi
if [ -z "$npx_bin" ]; then
    # Fallback: newest installs/node/*/bin/npx
    npx_bin="$(
        ls -1d "${HOME}/.local/share/mise/installs/node"/*/bin/npx 2>/dev/null \
            | sort -V \
            | tail -1 || true
    )"
fi
if [ -z "$npx_bin" ] || [ ! -x "$npx_bin" ]; then
    echo "workvm-primevue-mcp: npx ausente — rode ~/git/bin/workvm-ensure-mise-node.sh" >&2
    exit 1
fi

exec "$npx_bin" -y @primevue/mcp "$@"
