# Hook Locav: sobe shared PostgreSQL/Redis (hc-locav-data) por card.
# Problema: Sail do clone usa container_name — host-card namespaced completo
# ainda não existe; shared data já isola DB/prefixo para sandboxes e para
# quando o compose do card chegar. Sourced by lib/host-card.sh.

workvm_host_card_ensure_hook() {
    local id="$1"
    local dir="$2"
    local meta_repo code dns_slug db_suffix api_db testing_db redis_prefix

    meta_repo="$(workvm_host_card_meta_repo)"
    # shellcheck source=/dev/null
    source "${meta_repo}/locav/sandbox/host-card-shared-data.sh"

    code="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['code'])")"
    dns_slug="$(workvm_host_card_dns_slug "$code")"
    db_suffix="$(workvm_host_card_locav_db_suffix "$dns_slug")"
    api_db="db_${db_suffix}"
    testing_db="db_${db_suffix}_test"
    redis_prefix="hc_${db_suffix}_"

    workvm_host_card_locav_ensure_shared_data || return 1
    workvm_host_card_locav_provision_card_databases "$dns_slug" || return 1

    python3 - "$dir/meta.json" "$dns_slug" "$api_db" "$testing_db" "$redis_prefix" <<'PY'
import json, sys
path, slug, api_db, testing_db, redis_prefix = sys.argv[1:6]
with open(path, encoding="utf-8") as f:
    meta = json.load(f)
meta["shared_data"] = "hc-locav-data"
meta["dns_slug"] = slug
meta["db_database"] = api_db
meta["testing_database"] = testing_db
meta["redis_prefix"] = redis_prefix
meta["stack"] = "locav-shared-data-only"
with open(path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
PY

    workvm_host_card_log "shared data ok (${api_db}); app compose namespaced Locav ainda não — use Sail do clone ou workvm-sandbox --project locav"
}
