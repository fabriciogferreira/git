#!/usr/bin/env bash
# Bootstrap depois do clone Locav (project-setup.sh).
# Copia example.env → .env e alinha UID do Sail; o compose monta ../locav-front.
set -euo pipefail

GIT_ROOT="${GIT_ROOT:-$HOME/git}"
API="${GIT_ROOT}/locav/LocavApi"
FRONT="${GIT_ROOT}/locav/locav-front"
HOST_UID="${HOST_UID:-$(id -u)}"
HOST_GID="${HOST_GID:-$(id -g)}"

if [ "$HOST_UID" = "0" ]; then
    HOST_UID=1000
    HOST_GID=1000
fi

copy_example_env() {
    local dir="$1"
    local src="${dir}/example.env"
    local dst="${dir}/.env"
    if [ ! -f "$src" ]; then
        echo "error: example.env ausente: $src" >&2
        return 1
    fi
    echo "→ cp -n ${src} → ${dst}"
    cp -n "$src" "$dst"
}

set_env_kv() {
    local file="$1"
    local key="$2"
    local value="$3"
    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        printf '%s=%s\n' "$key" "$value" >>"$file"
    fi
}

copy_example_env "$API"
copy_example_env "$FRONT"

echo "→ LocavApi: WWWUSER/GROUP + WORKSPACE_P*UID (${HOST_UID}:${HOST_GID})"
set_env_kv "${API}/.env" WWWUSER "$HOST_UID"
set_env_kv "${API}/.env" WWWGROUP "$HOST_GID"
set_env_kv "${API}/.env" WORKSPACE_PUID "$HOST_UID"
set_env_kv "${API}/.env" WORKSPACE_PGID "$HOST_GID"
# example.env diz :8000; compose usa APP_PORT default 80 (e o front aponta pra :80).
set_env_kv "${API}/.env" APP_URL "http://localhost"
set_env_kv "${API}/.env" FRONTEND_URL "http://localhost:3000"

echo "✓ Pós-clone Locav concluído"
