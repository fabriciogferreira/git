#!/usr/bin/env bash
set -euo pipefail

# Bind-mounted report dirs are often root-owned on the host (created by an
# earlier root run). Playwright runs as pwuser (uid 1000) and needs write access.
for dir in /app/test-results /app/playwright-report; do
    mkdir -p "$dir"
    chown -R pwuser:pwuser "$dir" 2>/dev/null || chmod -R a+rwX "$dir" || true
done

# Drop to pwuser when started as root (compose may still set user: 1000:1000).
if [[ "$(id -u)" -eq 0 ]]; then
    exec runuser -u pwuser -- "$@"
fi

exec "$@"
