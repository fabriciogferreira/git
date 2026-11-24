#!/usr/bin/env bash
# Smoke caso 1: dois cards Olie (DOP-1183 + DOP-1073) no host sem colisão.
# Problema: o agente Cursor pode não ter o gid docker até relogin; rodar no
# terminal onde `docker info` já funciona. Ensure agora também builda a base
# se faltar — este smoke ainda pré-builda para falhar cedo e claro.
set -euo pipefail

export WORKVM_HOST_CARD_OPEN_CURSOR="${WORKVM_HOST_CARD_OPEN_CURSOR:-0}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HC="$ROOT/bin/workvm-host-card"
API="$ROOT/olie/api-main"

docker info >/dev/null
echo "docker: ok"

if [ ! -d "$API" ] || [ ! -f "$API/composer.json" ]; then
    echo "falta $API (gh repo clone olie-ai/api-main)" >&2
    exit 1
fi

# Imagem base do slim (hook faz build sandbox a partir dela)
if ! docker image inspect olie/api-main:latest >/dev/null 2>&1; then
    echo "build olie/api-main:latest (serviço web do compose olie)"
    export GIT_ROOT="$ROOT"
    (cd "$ROOT/olie" && docker compose build web) || {
        echo "não foi possível obter olie/api-main:latest" >&2
        exit 1
    }
fi

if [ ! -f "$API/vendor/autoload.php" ]; then
    if command -v composer >/dev/null 2>&1; then
        echo "composer install (host)"
        (cd "$API" && composer install --no-interaction)
    else
        echo "composer install via olie/api-main image"
        docker run --rm -u "$(id -u):$(id -g)" -v "$API:/var/www/html" -w /var/www/html \
            olie/api-main:latest composer install --no-interaction
    fi
fi

for code in DOP-1183 DOP-1073; do
    echo "=== ensure $code ==="
    "$HC" ensure --project olie --code "$code"
done

echo "=== isolation ==="
python3 - <<'PY'
import json
from pathlib import Path
root = Path.home() / ".local/share/workvm/host-cards/olie"
cards = {json.loads(p.read_text())["code"]: json.loads(p.read_text()) for p in root.glob("*/meta.json")}
a, b = cards["DOP-1183"], cards["DOP-1073"]
assert a["port_base"] != b["port_base"], a
assert a["compose_project"] != b["compose_project"]
print("ports", a["port_base"], b["port_base"])
print("compose", a["compose_project"], b["compose_project"])
print("stack", a.get("stack"), b.get("stack"))
PY

echo "=== docker ps (hc-olie) ==="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Label "com.docker.compose.project"}}' \
    | grep -E 'hc-olie-dop-(1183|1073)|NAMES' || docker ps -a | head

echo "=== HTTP smoke ==="
for code in DOP-1183 DOP-1073; do
    port="$("$HC" status --project olie --code "$code" | python3 -c "import sys,json; print(json.load(sys.stdin)['port_base'])")"
    code_http="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 3 "http://127.0.0.1:${port}/" || echo fail)"
    echo "$code port=$port http=$code_http"
done

echo "case1 smoke done"
