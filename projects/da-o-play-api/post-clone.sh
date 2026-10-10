#!/usr/bin/env bash
# One-time bootstrap after cloning da-o-play-api (run by project-setup.sh).
set -euo pipefail

GIT_ROOT="${GIT_ROOT:-$HOME/git}"
APP="${GIT_ROOT}/musicians-app/da-o-play-api"
HOST_UID="${HOST_UID:-$(id -u)}"
HOST_GID="${HOST_GID:-$(id -g)}"

if [ "$HOST_UID" = "0" ]; then
    HOST_UID=1000
    HOST_GID=1000
fi

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

if [ ! -f "${APP}/.env.example" ]; then
    echo "error: .env.example ausente: ${APP}/.env.example" >&2
    exit 1
fi

echo "→ da-o-play-api: cp -n .env.example → .env"
cp -n "${APP}/.env.example" "${APP}/.env"

echo "→ da-o-play-api: HOST_UID/GID + DB defaults para docker compose"
set_env_kv "${APP}/.env" HOST_UID "$HOST_UID"
set_env_kv "${APP}/.env" HOST_GID "$HOST_GID"
set_env_kv "${APP}/.env" DB_CONNECTION pgsql
set_env_kv "${APP}/.env" DB_HOST postgresql
set_env_kv "${APP}/.env" DB_PORT 5432
set_env_kv "${APP}/.env" DB_DATABASE da_o_play
set_env_kv "${APP}/.env" DB_USERNAME root
set_env_kv "${APP}/.env" DB_PASSWORD password
set_env_kv "${APP}/.env" APP_URL "http://localhost:8000"

echo "✓ Pós-clone da-o-play-api concluído"
