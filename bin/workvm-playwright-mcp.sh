#!/usr/bin/env bash
# Playwright MCP via Docker e2e. @playwright/mcp@latest pede chrome-for-testing
# e sandbox; a imagem só tem Chromium em /ms-playwright e o sandbox quebra.
# Espera o container (workvm-docker-mcp) e sobe o MCP headless sem sandbox.
# Uso (mcp.json): command=este-script, args=[container]
set -euo pipefail

container="${1:-}"
if [ -z "$container" ]; then
    echo "usage: workvm-playwright-mcp.sh <e2e-container>" >&2
    exit 2
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
inner='chrome="$(ls -d /ms-playwright/chromium-*/chrome-linux*/chrome 2>/dev/null | head -n1 || true)"
if [ -z "$chrome" ]; then
  echo "workvm-playwright-mcp: no Chromium under /ms-playwright" >&2
  exit 1
fi
exec npx -y @playwright/mcp@latest --headless --no-sandbox --executable-path "$chrome"'

exec "$here/workvm-docker-mcp.sh" "$container" sh -c "$inner"
