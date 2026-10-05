#!/usr/bin/env bash
# One-time bootstrap after cloning vid2agent-code (run by project-setup.sh).
set -euo pipefail

GIT_ROOT="${GIT_ROOT:-$HOME/git}"
APP="${GIT_ROOT}/vid2agent-code/vid2agent-code"
COMPOSE_FILE="compose.dev.yaml"
HOST_UID="${HOST_UID:-$(id -u)}"
HOST_GID="${HOST_GID:-$(id -g)}"

# Avoid root UID from agent/sudo sessions breaking volume permissions.
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

echo "→ vid2agent-code: cp -n .env.example → .env"
cp -n "${APP}/.env.example" "${APP}/.env"

echo "→ vid2agent-code: .env para stack docker (postgres/redis/nginx)"
set_env_kv "${APP}/.env" APP_URL "http://localhost"
set_env_kv "${APP}/.env" DB_CONNECTION pgsql
set_env_kv "${APP}/.env" DB_HOST postgres
set_env_kv "${APP}/.env" DB_PORT 5432
set_env_kv "${APP}/.env" DB_DATABASE app
set_env_kv "${APP}/.env" DB_USERNAME laravel
set_env_kv "${APP}/.env" DB_PASSWORD secret
set_env_kv "${APP}/.env" REDIS_HOST redis
set_env_kv "${APP}/.env" REDIS_PORT 6379

echo "→ vid2agent-code: composer install (workspace; volume sobrescreve vendor da imagem)"
(
    cd "$APP"
    docker compose -f "$COMPOSE_FILE" run --rm --no-deps \
        -u "${HOST_UID}:${HOST_GID}" \
        workspace \
        composer install --no-interaction --prefer-dist
)

if ! grep -q '^APP_KEY=base64:' "${APP}/.env"; then
    echo "→ vid2agent-code: php artisan key:generate"
    (
        cd "$APP"
        docker compose -f "$COMPOSE_FILE" run --rm --no-deps \
            -u "${HOST_UID}:${HOST_GID}" \
            workspace \
            php artisan key:generate --force
    )
fi

echo "→ vid2agent-code: php artisan migrate --force"
(
    cd "$APP"
    docker compose -f "$COMPOSE_FILE" up -d postgres redis
    # Sem --no-deps: precisa da rede para resolver host "postgres"
    docker compose -f "$COMPOSE_FILE" run --rm \
        -u "${HOST_UID}:${HOST_GID}" \
        workspace \
        php artisan migrate --force
)

if [ -f "${APP}/package.json" ] && [ ! -d "${APP}/node_modules" ]; then
    echo "→ vid2agent-code: npm install (workspace)"
    (
        cd "$APP"
        docker compose -f "$COMPOSE_FILE" run --rm --no-deps \
            -u "${HOST_UID}:${HOST_GID}" \
            workspace \
            bash -lc 'source ~/.nvm/nvm.sh && npm install'
    )
fi

echo "✓ Pós-clone vid2agent-code concluído"
