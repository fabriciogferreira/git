# Hook Opbed: derruba o compose do host-card (não derruba hc-opbed-data).
# Sourced by lib/host-card.sh — define workvm_host_card_destroy_hook.

workvm_host_card_destroy_hook() {
    local id="$1"
    local dir="$2"
    local compose_dir pname meta_repo dns_slug

    meta_repo="$(workvm_host_card_meta_repo)"
    # shellcheck source=/dev/null
    source "${meta_repo}/opbed/sandbox/host-card-shared-data.sh"

    compose_dir="$(python3 -c "import json;print(json.load(open('${dir}/meta.json')).get('compose_dir') or '')" 2>/dev/null || true)"
    pname="$(python3 -c "import json;print(json.load(open('${dir}/meta.json')).get('compose_project') or '')" 2>/dev/null || true)"
    dns_slug="$(python3 -c "import json;print(json.load(open('${dir}/meta.json')).get('dns_slug') or '')" 2>/dev/null || true)"
    if [ -z "$compose_dir" ]; then
        compose_dir="${dir}/compose"
    fi
    if [ -z "$pname" ]; then
        pname="hc-${id}"
    fi

    if [ -d "$compose_dir" ] && [ -f "$compose_dir/compose.yaml" ]; then
        workvm_host_card_log "compose down -v ($pname)"
        (
            cd "$compose_dir"
            set -a
            # shellcheck disable=SC1091
            [ -f .env ] && source .env
            set +a
            export COMPOSE_PROJECT_NAME="$pname"
            docker compose down -v --remove-orphans 2>/dev/null || true
        ) || true
    elif [ -n "$pname" ] && command -v docker >/dev/null 2>&1; then
        docker compose -p "$pname" down -v --remove-orphans 2>/dev/null || true
    fi

    if [ -n "$dns_slug" ]; then
        workvm_host_card_opbed_drop_card_databases "$dns_slug" || true
    fi
}
