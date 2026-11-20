# Hook use-url-query: sobe bun namespaced no host.
# Problema: ensure do projeto só clonava e abria Cursor — sem compose o
# container de testes não existia. Sourced by lib/host-card.sh.

workvm_host_card_ensure_hook() {
    local id="$1"
    local dir="$2"
    local meta_repo git_root compose_dir port_base app
    local code dns_slug pname
    local host_uid host_gid

    meta_repo="$(workvm_host_card_meta_repo)"
    git_root="$(workvm_host_card_git_root)"
    # shellcheck source=/dev/null
    source "${meta_repo}/lib/host-card-proxy.sh"

    compose_dir="${dir}/compose"
    app="${git_root}/use-url-query/use-url-query"
    port_base="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['port_base'])")"
    code="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['code'])")"
    dns_slug="$(workvm_host_card_dns_slug "$code")"
    host_uid="$(id -u)"
    host_gid="$(id -g)"

    if [ ! -d "$app" ]; then
        workvm_host_card_log "clone ausente: ${app}"
        return 1
    fi

    mkdir -p "$compose_dir"
    cp -f "${meta_repo}/use-url-query/sandbox/compose.host.yml" "$compose_dir/compose.yaml"

    pname="hc-${id}"
    {
        printf 'COMPOSE_PROJECT_NAME=%s\n' "$pname"
        printf 'SB_APP=%s\n' "$app"
        printf 'SB_DNS_SLUG=%s\n' "$dns_slug"
        printf 'HOST_UID=%s\n' "$host_uid"
        printf 'HOST_GID=%s\n' "$host_gid"
        workvm_host_card_write_resource_env 2>/dev/null || true
        printf 'COMPOSE_FILE=compose.yaml\n'
    } >"$compose_dir/.env"

    if declare -F workvm_host_card_apply_compose_limits >/dev/null; then
        workvm_host_card_apply_compose_limits "$compose_dir"
    fi

    python3 - "$dir/meta.json" "$pname" "$compose_dir" "$dns_slug" "$port_base" <<'PY'
import json, sys
path, pname, compose_dir, slug, port_base = sys.argv[1:6]
port_base = int(port_base)
with open(path, encoding="utf-8") as f:
    meta = json.load(f)
meta["compose_project"] = pname
meta["compose_dir"] = compose_dir
meta["stack"] = "use-url-query-host"
meta["dns_slug"] = slug
meta["api_url"] = ""
meta["front_url"] = ""
with open(path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
PY

    workvm_host_card_log "compose up ($pname) — bun install"
    (
        cd "$compose_dir"
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
        export COMPOSE_PROJECT_NAME="$pname"
        docker compose up -d --remove-orphans
    ) || return 1

    workvm_host_card_log "aguardando bun install…"
    local i
    for i in $(seq 1 60); do
        if docker compose -p "$pname" --project-directory "$compose_dir" exec -T use-url-query \
            test -d /srv/node_modules >/dev/null 2>&1; then
            workvm_host_card_log "node_modules ok"
            break
        fi
        sleep 2
    done

    workvm_host_card_log "Card use-url-query pronto (bun; sem HTTP). code=${code}"
}
