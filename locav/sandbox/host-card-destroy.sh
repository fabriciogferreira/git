# Hook Locav: DROP dos DBs do card no Postgres shared (não derruba locav-hc-*).
# Sourced by lib/host-card.sh — define workvm_host_card_destroy_hook.

workvm_host_card_destroy_hook() {
    local id="$1"
    local dir="$2"
    local meta_repo dns_slug

    meta_repo="$(workvm_host_card_meta_repo)"
    # shellcheck source=/dev/null
    source "${meta_repo}/locav/sandbox/host-card-shared-data.sh"

    dns_slug="$(python3 -c "import json;print(json.load(open('${dir}/meta.json')).get('dns_slug') or '')" 2>/dev/null || true)"
    if [ -n "$dns_slug" ]; then
        workvm_host_card_locav_drop_card_databases "$dns_slug" || true
    fi
}
