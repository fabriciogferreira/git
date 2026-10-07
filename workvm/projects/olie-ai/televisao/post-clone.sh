#!/usr/bin/env bash
# One-time bootstrap after cloning Televisão repos (run by project-setup.sh).
set -euo pipefail

GIT_ROOT="${GIT_ROOT:-$HOME/git}"
TV="${GIT_ROOT}/televisao"
API="${TV}/televisao-api"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

copy_env_example() {
    local dir="$1"
    local src="${dir}/.env.example"
    local dst="${dir}/.env"
    if [ ! -f "$src" ]; then
        echo "error: .env.example ausente: $src" >&2
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

ensure_docker_network() {
    local name="$1"
    if docker network inspect "$name" >/dev/null 2>&1; then
        echo "✓ Docker network: $name"
        return 0
    fi
    echo "→ Docker network create: $name"
    docker network create "$name" >/dev/null
}

wait_for() {
    local label="$1"
    local attempts="$2"
    shift 2
    echo "  waiting for ${label}..."
    local i
    for i in $(seq 1 "$attempts"); do
        if "$@"; then
            return 0
        fi
        sleep 2
    done
    echo "error: ${label} não ficou pronto" >&2
    return 1
}

api_ready() {
    docker container inspect televisao-backend --format '{{.State.Status}}' 2>/dev/null | grep -qx running \
        && curl -fsS --connect-timeout 2 "http://127.0.0.1:8000/up" >/dev/null 2>&1
}

echo "→ televisao: .env.example → .env (todos os repos)"
for repo in televisao-api televisao-front televisao-meet-front televisao-meet-core; do
    copy_env_example "${TV}/${repo}"
done

echo "→ televisao-api: HOST_UID/HOST_GID (${HOST_UID}:${HOST_GID})"
set_env_kv "$API/.env" HOST_UID "$HOST_UID"
set_env_kv "$API/.env" HOST_GID "$HOST_GID"

# docker-compose.yaml declares these as external.
ensure_docker_network micro-service-email
ensure_docker_network enterscience-net

echo "→ workvm stack: compose up (setup.sh no backend faz composer/migrate/seed/key)"
(
    cd "$API"
    docker compose up -d --build
)

wait_for "televisao-backend" 120 api_ready

if ! grep -q '^APP_KEY=base64:' "$API/.env"; then
    echo "aviso: APP_KEY ainda vazio; o setup.sh do container pode ainda estar rodando" >&2
fi

echo "✓ Pós-clone Televisão concluído"
