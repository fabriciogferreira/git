#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# .env is optional — defaults: super@super.super / password (UserSeeder local)
if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

# Playwright image runs as pwuser (uid 1000). Bind-mounted report dirs must be writable.
mkdir -p test-results playwright-report
chmod -R a+rwX test-results playwright-report 2>/dev/null || true

if ! curl -fsS --connect-timeout 2 "${E2E_BASE_URL:-http://localhost:3000}/login" >/dev/null 2>&1; then
    echo "televisao-front not reachable at ${E2E_BASE_URL:-http://localhost:3000}."
    echo "Start the stack first:"
    echo "  cd ../televisao-api && docker compose up -d"
    exit 1
fi

docker compose up -d --build
docker compose exec -T -u pwuser e2e npx playwright test --project=chromium "$@"
