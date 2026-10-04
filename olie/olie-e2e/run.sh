#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# .env is optional — defaults: tester@olie.ai / password (api-main seed)
if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

# Playwright image runs as pwuser (uid 1000). Bind-mounted report dirs must be writable.
mkdir -p test-results playwright-report
chmod -R a+rwX test-results playwright-report 2>/dev/null || true

# Workvm compose lives in the meta `git` repo (not olie-ai/docker-workspace).
WORKSPACE_DIR="${OLIE_WORKSPACE_DIR:-$(cd ../../workvm/projects/olie && pwd)}"
WORKSPACE_COMPOSE="$WORKSPACE_DIR/docker-compose.yml"
NETWORK="${OLIE_DOCKER_NETWORK:-docker-workspace_olie-network}"

if [[ -f "$WORKSPACE_COMPOSE" ]]; then
    if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
        echo "Starting workvm Olie stack (includes olie-e2e)..."
        docker compose -f "$WORKSPACE_COMPOSE" up -d
    else
        docker compose -f "$WORKSPACE_COMPOSE" up -d e2e --build
    fi
    docker compose -f "$WORKSPACE_COMPOSE" exec -T -u pwuser e2e npx playwright test --project=chromium "$@"
    exit 0
fi

# Fallback: standalone compose in this repo (network must already exist).
if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "Docker network not found. Start the stack first:"
    echo "  cd ../../workvm/projects/olie && docker compose up -d"
    echo "If your network name differs: OLIE_DOCKER_NETWORK=<name> $0"
    exit 1
fi

docker compose up -d --build
docker compose exec -T -u pwuser e2e npx playwright test --project=chromium "$@"
