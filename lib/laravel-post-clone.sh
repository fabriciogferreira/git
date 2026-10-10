#!/usr/bin/env bash
# Bootstrap de um app Laravel depois do clone: .env, UID do volume, compose.dev.yaml.
# Problema: boilerplate-laravel e vid2agent-code repetiam este script. Os dois
# usam os serviços workspace, postgres e redis. O caminho do app é o argumento.
# Não sobe a stack inteira: só o que o migrate e o composer precisam.

workvm_laravel_set_env_kv() {
    local file="$1"
    local key="$2"
    local value="$3"
    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        printf '%s=%s\n' "$key" "$value" >>"$file"
    fi
}

workvm_laravel_post_clone() {
    local app="${1:-}"
    local label compose_file host_uid host_gid

    if [ -z "$app" ] || [ ! -d "$app" ]; then
        echo "error: workvm_laravel_post_clone <dir do app>" >&2
        return 1
    fi

    label="$(basename "$app")"
    compose_file="compose.dev.yaml"
    host_uid="${HOST_UID:-$(id -u)}"
    host_gid="${HOST_GID:-$(id -g)}"

    # Sessão de agente/sudo grava o volume como root e o php-fpm não escreve.
    if [ "$host_uid" = "0" ]; then
        host_uid=1000
        host_gid=1000
    fi

    if [ ! -f "${app}/.env.example" ]; then
        echo "error: .env.example ausente: ${app}/.env.example" >&2
        return 1
    fi

    echo "→ ${label}: cp -n .env.example → .env"
    cp -n "${app}/.env.example" "${app}/.env"

    echo "→ ${label}: .env para stack docker (postgres/redis/nginx)"
    workvm_laravel_set_env_kv "${app}/.env" APP_URL "http://localhost"
    workvm_laravel_set_env_kv "${app}/.env" DB_CONNECTION pgsql
    workvm_laravel_set_env_kv "${app}/.env" DB_HOST postgres
    workvm_laravel_set_env_kv "${app}/.env" DB_PORT 5432
    workvm_laravel_set_env_kv "${app}/.env" DB_DATABASE app
    workvm_laravel_set_env_kv "${app}/.env" DB_USERNAME laravel
    workvm_laravel_set_env_kv "${app}/.env" DB_PASSWORD secret
    workvm_laravel_set_env_kv "${app}/.env" REDIS_HOST redis
    workvm_laravel_set_env_kv "${app}/.env" REDIS_PORT 6379

    echo "→ ${label}: composer install (workspace; volume sobrescreve vendor da imagem)"
    (
        cd "$app"
        docker compose -f "$compose_file" run --rm --no-deps \
            -u "${host_uid}:${host_gid}" \
            workspace \
            composer install --no-interaction --prefer-dist
    )

    if ! grep -q '^APP_KEY=base64:' "${app}/.env"; then
        echo "→ ${label}: php artisan key:generate"
        (
            cd "$app"
            docker compose -f "$compose_file" run --rm --no-deps \
                -u "${host_uid}:${host_gid}" \
                workspace \
                php artisan key:generate --force
        )
    fi

    echo "→ ${label}: php artisan migrate --force"
    (
        cd "$app"
        # O migrate resolve o host postgres na rede do compose. Sobe os dois
        # antes: o workspace espera o postgres healthy.
        docker compose -f "$compose_file" up -d postgres redis
        docker compose -f "$compose_file" run --rm \
            -u "${host_uid}:${host_gid}" \
            workspace \
            php artisan migrate --force
    )

    if [ -f "${app}/package.json" ] && [ ! -d "${app}/node_modules" ]; then
        echo "→ ${label}: npm install (workspace)"
        (
            cd "$app"
            docker compose -f "$compose_file" run --rm --no-deps \
                -u "${host_uid}:${host_gid}" \
                workspace \
                bash -lc 'source ~/.nvm/nvm.sh && npm install'
        )
    fi

    echo "✓ Pós-clone ${label} concluído"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -euo pipefail
    workvm_laravel_post_clone "${1:?caminho do app Laravel}"
fi
