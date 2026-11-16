#!/usr/bin/env bash
# migrate (+ seed se ainda não) nos host-cards Olie — corrige login “erro na base”.
# Problema: slim sobe MySQL vazio; o front identifica/login precisa de frames seedados.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/host-card.sh
source "$ROOT/lib/host-card.sh"
# shellcheck source=../olie/sandbox/host-card-ensure.sh
source "$ROOT/olie/sandbox/host-card-ensure.sh"

docker info >/dev/null

codes=("$@")
if [ "${#codes[@]}" -eq 0 ]; then
    codes=(DOP-1183 DOP-1073)
fi

for code in "${codes[@]}"; do
    id="$(workvm_host_card_id olie "$code")"
    dir="$(workvm_host_card_dir olie "$id")"
    meta="$(workvm_host_card_meta_path olie "$id")"
    if [ ! -f "$meta" ]; then
        workvm_host_card_log "card ausente: $code — rode ensure antes"
        continue
    fi
    compose_dir="$(python3 -c "import json;print(json.load(open('$meta')).get('compose_dir') or '')")"
    pname="$(python3 -c "import json;print(json.load(open('$meta')).get('compose_project') or '')")"
    echo "=== migrate/seed $code ($pname) ==="
    # force re-seed path if frames table empty: clear db_seeded flag when empty
    if [ -n "$compose_dir" ]; then
        (
            cd "$compose_dir"
            set -a
            # shellcheck disable=SC1091
            source .env
            set +a
            export COMPOSE_PROJECT_NAME="$pname"
            n="$(docker compose --profile slim exec -T mysql \
                mysql -Ns -usandbox -psandbox api_main \
                -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='api_main' AND table_name='frames'" \
                2>/dev/null | tr -d '\r' || echo 0)"
            if [ "${n:-0}" = "0" ]; then
                python3 - "$meta" <<'PY'
import json, sys
p = sys.argv[1]
m = json.load(open(p, encoding="utf-8"))
m["db_seeded"] = 0
json.dump(m, open(p, "w", encoding="utf-8"), indent=2)
open(p, "a", encoding="utf-8").write("\n")
PY
            fi
        )
    fi
    workvm_host_card_olie_migrate_seed "$compose_dir" "$pname" "$dir"
    echo "ok $code — tente login de novo em http://devframe.$(python3 -c "import json;print(json.load(open('$meta'))['dns_slug'])").olie.localhost"
done
