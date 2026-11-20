# Hook fabriciogferreira: sobe Next namespaced no host.
# Problema: ensure do projeto só clonava e abria Cursor — sem compose o
# portfólio não rodava. Sourced by lib/host-card.sh.

workvm_host_card_ensure_hook() {
    local id="$1"
    local dir="$2"
    local meta_repo git_root compose_dir port_base app
    local code dns_slug pname app_url
    local host_uid host_gid

    meta_repo="$(workvm_host_card_meta_repo)"
    git_root="$(workvm_host_card_git_root)"
    # shellcheck source=/dev/null
    source "${meta_repo}/lib/host-card-proxy.sh"

    compose_dir="${dir}/compose"
    app="${git_root}/fabriciogferreira/fabriciogferreira"
    port_base="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['port_base'])")"
    code="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['code'])")"
    dns_slug="$(workvm_host_card_dns_slug "$code")"
    host_uid="$(id -u)"
    host_gid="$(id -g)"
    app_url="http://devframe.${dns_slug}.olie.localhost"

    if [ ! -d "$app" ]; then
        workvm_host_card_log "clone ausente: ${app}"
        return 1
    fi

    if [ ! -f "${app}/.env" ] && [ -f "${app}/.env.example" ]; then
        cp -n "${app}/.env.example" "${app}/.env" || true
    fi

    mkdir -p "$compose_dir"
    cp -f "${meta_repo}/fabriciogferreira/sandbox/compose.host.yml" "$compose_dir/compose.yaml"

    pname="hc-${id}"
    {
        printf 'COMPOSE_PROJECT_NAME=%s\n' "$pname"
        printf 'SB_APP=%s\n' "$app"
        printf 'SB_DNS_SLUG=%s\n' "$dns_slug"
        printf 'SB_PORT_WEB=%s\n' "$port_base"
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
meta["stack"] = "fabriciogferreira-host"
meta["dns_slug"] = slug
meta["api_url"] = f"http://127.0.0.1:{port_base}"
meta["front_url"] = f"http://127.0.0.1:{port_base}"
meta["api_dns"] = f"http://devframe.{slug}.olie.localhost"
meta["front_dns"] = f"http://devframe.{slug}.olie.localhost"
with open(path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
PY

    workvm_host_card_log "compose up ($pname) — Next dev"
    (
        cd "$compose_dir"
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
        export COMPOSE_PROJECT_NAME="$pname"
        docker compose up -d --remove-orphans
    ) || return 1

    workvm_host_card_fg_wait_web "$compose_dir" "$pname" || return 1
    workvm_host_card_proxy_ensure || workvm_host_card_log "proxy DNS falhou — use porta direta"

    workvm_host_card_log "Front ${app_url}  (→ :${port_base})"
}

workvm_host_card_fg_wait_web() {
    local compose_dir="$1"
    local pname="$2"
    local i port

    port="$(python3 -c "import re;print(re.search(r'^SB_PORT_WEB=(\d+)', open('${compose_dir}/.env').read(), re.M).group(1))")"
    workvm_host_card_log "aguardando Next em :${port}…"
    for i in $(seq 1 120); do
        if curl -fsS --connect-timeout 2 -o /dev/null "http://127.0.0.1:${port}/" >/dev/null 2>&1; then
            workvm_host_card_log "Next pronto"
            return 0
        fi
        sleep 3
    done
    workvm_host_card_log "Next não respondeu a tempo — veja: docker compose -p ${pname} logs"
    return 1
}
