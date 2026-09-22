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

if ! docker network inspect "${OLIE_DOCKER_NETWORK:-docker-workspace_olie-network}" >/dev/null 2>&1; then
    echo "Docker network not found. Start the stack first:"
    echo "  cd ../docker-workspace && docker compose up -d"
    echo "If your network name differs: OLIE_DOCKER_NETWORK=<name> $0"
    exit 1
fi

docker compose run --rm --build e2e npx playwright test --project=chromium "$@"
