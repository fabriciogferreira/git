#!/usr/bin/env bash
# Reaplica DNS/front nos host-cards Olie já criados (DOP-1183 / DOP-1073…).
# Problema: ensure antigo não tinha Caddy nem Vite; este script só retoma.
set -euo pipefail
export WORKVM_HOST_CARD_OPEN_CURSOR="${WORKVM_HOST_CARD_OPEN_CURSOR:-0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HC="$ROOT/bin/workvm-host-card"

docker info >/dev/null

codes=("$@")
if [ "${#codes[@]}" -eq 0 ]; then
    codes=(DOP-1183 DOP-1073)
fi

for code in "${codes[@]}"; do
    echo "=== ensure $code (DNS + front) ==="
    "$HC" ensure --project olie --code "$code"
done

echo "=== resolve / curl ==="
for code in "${codes[@]}"; do
    slug="$("$HC" status --project olie --code "$code" | python3 -c "import sys,json; print(json.load(sys.stdin).get('dns_slug',''))")"
    front="http://devframe.${slug}.olie.localhost"
    api="http://api.${slug}.olie.localhost"
    getent hosts "devframe.${slug}.olie.localhost" "api.${slug}.olie.localhost" || true
    echo -n "$front → "
    curl -sS -o /dev/null -w '%{http_code}\n' --connect-timeout 5 "$front" || echo fail
    echo -n "$api → "
    curl -sS -o /dev/null -w '%{http_code}\n' --connect-timeout 5 "$api" || echo fail
done
