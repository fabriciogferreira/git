#!/usr/bin/env bash
# One-time bootstrap after cloning Olie repos (run by project-setup.sh).
set -euo pipefail

GIT_ROOT="${GIT_ROOT:-$HOME/git}"
OLIE="${GIT_ROOT}/olie"
COMPOSE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "→ workvm compose .env"
cp -n "$COMPOSE_DIR/.env.example" "$COMPOSE_DIR/.env"
# Keep GIT_ROOT in sync with this machine
if grep -q '^GIT_ROOT=' "$COMPOSE_DIR/.env"; then
    sed -i "s|^GIT_ROOT=.*|GIT_ROOT=${GIT_ROOT}|" "$COMPOSE_DIR/.env"
else
    printf '\nGIT_ROOT=%s\n' "$GIT_ROOT" >>"$COMPOSE_DIR/.env"
fi
# api-main image expects www-data as 1000:1000 (never root 0:0)
if grep -q '^UID=' "$COMPOSE_DIR/.env"; then
    sed -i 's|^UID=.*|UID=1000|' "$COMPOSE_DIR/.env"
    sed -i 's|^GID=.*|GID=1000|' "$COMPOSE_DIR/.env"
else
    printf 'UID=1000\nGID=1000\n' >>"$COMPOSE_DIR/.env"
fi

echo "→ api-main: composer install + .env"
(
    cd "$OLIE/api-main"
    docker run --rm \
        -u "1000:1000" \
        -v "$(pwd):/var/www/html" \
        -w /var/www/html \
        laravelsail/php84-composer:latest \
        bash -c "composer install --ignore-platform-reqs --no-plugins --no-scripts && composer dump-autoload --optimize --no-plugins --ignore-platform-reqs && cp -n .env.example .env"
)

echo "→ olie-fronts: yarn install (vite/workspaces)"
(
    cd "$OLIE/olie-fronts"
    # Run as root inside the container (avoids EACCES on fresh mounts), then chown.
    docker run --rm \
        -v "$(pwd):/app" \
        -w /app \
        node:22 \
        bash -c 'yarn install --frozen-lockfile && chown -R 1000:1000 node_modules'
)

echo "→ websocket: npm install + .env"
(
    cd "$OLIE/websocket"
    docker run --rm \
        -u "1000:1000" \
        -v "$(pwd):/app" \
        -w /app \
        node:20 \
        bash -c "npm install && cp -n .env.example .env"
)

echo "→ backoffice: .env"
cp -n "$OLIE/backoffice/.env.example" "$OLIE/backoffice/.env"

echo "→ landing: .env"
cp -n "$OLIE/landing/.env.example" "$OLIE/landing/.env"

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

api_php_ready() {
    docker container inspect olie-api-main --format '{{.State.Status}}' 2>/dev/null | grep -qx running \
        && docker container exec olie-api-main php -r 'echo "ok";' >/dev/null 2>&1
}

mysql_ready() {
    local user password
    user="$(grep -E '^DB_USERNAME=' "$COMPOSE_DIR/.env" | cut -d= -f2-)"
    password="$(grep -E '^DB_PASSWORD=' "$COMPOSE_DIR/.env" | cut -d= -f2-)"
    docker container exec olie-mysql mysqladmin ping -h 127.0.0.1 -u"$user" "-p${password}" --silent >/dev/null 2>&1 \
        && docker container exec \
            -e DB_USERNAME="$user" \
            -e DB_PASSWORD="$password" \
            olie-api-main php -r 'new PDO("mysql:host=mysql;port=3306", getenv("DB_USERNAME"), getenv("DB_PASSWORD"));' >/dev/null 2>&1
}

echo "→ workvm stack: compose up, key, migrate --seed, restart"
(
    cd "$COMPOSE_DIR"
    docker compose up -d

    wait_for "olie-api-main" 90 api_php_ready
    wait_for "olie-mysql" 90 mysql_ready

    # key:generate first (login fails hard with empty APP_KEY). Then migrate/seed.
    docker container exec olie-api-main php artisan key:generate --force
    docker container exec olie-api-main php artisan migrate --seed --force
    docker container exec olie-api-main php artisan config:clear

    if ! grep -q '^APP_KEY=base64:' "$OLIE/api-main/.env"; then
        echo "error: APP_KEY ainda vazio após key:generate" >&2
        exit 1
    fi

    docker compose stop
    docker compose up -d
)

echo "✓ Pós-clone Olie concluído"
