#!/usr/bin/env bash
# One-time bootstrap after cloning Olie repos (run by project-setup.sh).
set -euo pipefail

GIT_ROOT="${GIT_ROOT:-$HOME/git}"
OLIE="${GIT_ROOT}/olie"

echo "→ api-main: composer install + .env"
(
    cd "$OLIE/api-main"
    docker run --rm \
        -u "$(id -u):$(id -g)" \
        -v "$(pwd):/var/www/html" \
        -w /var/www/html \
        laravelsail/php84-composer:latest \
        bash -c "composer install --ignore-platform-reqs && cp .env.example .env"
)

echo "→ websocket: npm install + .env"
(
    cd "$OLIE/websocket"
    docker run --rm \
        -v "$(pwd):/app" \
        -w /app \
        node:20 \
        bash -c "npm install && cp .env.example .env"
)

echo "→ backoffice: .env"
cp -n "$OLIE/backoffice/.env.example" "$OLIE/backoffice/.env"

echo "→ landing: .env"
cp -n "$OLIE/landing/.env.example" "$OLIE/landing/.env"

echo "→ docker-workspace: compose up, migrate --seed, restart"
(
    cd "$OLIE/docker-workspace"
    docker compose up -d
    docker container exec olie-api-main bash -c "php artisan key:generate && php artisan migrate --seed"
    docker compose stop
    docker compose up -d
)

echo "✓ Pós-clone Olie concluído"
