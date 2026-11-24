#!/usr/bin/env bash
# Omarchy declara node lazy no mise; após reinstall do Cursor (ou wipe de
# ~/.local/share/mise/installs) o shim `npx` fica sem binário e o MCP
# PrimeVue (`npx -y @primevue/mcp`) morre na discovery. Reinstala o node
# ativo quando `npx -v` falha. Idempotente; silencioso no sucesso.
# Uso: workvm-ensure-mise-node.sh   (exit 0 se npx ok ou após force-install)
set -euo pipefail

MISE_BIN="${MISE_BIN:-}"
if [ -z "$MISE_BIN" ]; then
    if [ -x /usr/bin/mise ]; then
        MISE_BIN=/usr/bin/mise
    elif command -v mise >/dev/null 2>&1; then
        MISE_BIN="$(command -v mise)"
    else
        echo "workvm-ensure-mise-node: mise não encontrado" >&2
        exit 1
    fi
fi

export PATH="${HOME}/.local/share/mise/shims:/usr/bin:/bin:${PATH:-}"

npx_ok() {
    # Sem stderr de avisos do mise — só importa o código.
    npx -v >/dev/null 2>&1
}

if npx_ok; then
    exit 0
fi

ver="$("$MISE_BIN" current node 2>/dev/null | awk '{print $1}' || true)"
if [ -z "$ver" ] || [ "$ver" = "system" ]; then
    ver=latest
fi

echo "workvm-ensure-mise-node: npx quebrado — mise install --force node@${ver}" >&2
"$MISE_BIN" install --force "node@${ver}" >&2

if ! npx_ok; then
    echo "workvm-ensure-mise-node: npx ainda falha após install node@${ver}" >&2
    exit 1
fi
