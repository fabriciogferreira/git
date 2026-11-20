# Hook Opbed: sobe API Laravel + Next namespaced no host (sem WorkVM).
# Problema: ensure do projeto só clonava e abria Cursor — sem compose o
# Opbed não “roda” (WAIT_URL / job board). Sourced by lib/host-card.sh.

workvm_host_card_ensure_hook() {
    local id="$1"
    local dir="$2"
    local meta_repo git_root compose_dir port_base api front
    local code dns_slug pname app_url front_url
    local host_uid host_gid ssh_dir olie_mgmt olie_mcp

    meta_repo="$(workvm_host_card_meta_repo)"
    git_root="$(workvm_host_card_git_root)"
    # shellcheck source=/dev/null
    source "${meta_repo}/lib/host-card-proxy.sh"
    # shellcheck source=/dev/null
    source "${meta_repo}/opbed/sandbox/host-card-shared-data.sh"

    # Shared pgsql/redis for workvm-sandbox (mutation/coverage); Card keeps
    # its own namespaced pgsql in compose.host.yml.
    workvm_host_card_opbed_ensure_shared_data || workvm_host_card_log "hc-opbed-data falhou — sandboxes sem shared data"

    compose_dir="${dir}/compose"
    api="${git_root}/opbed/opbed-backend"
    front="${git_root}/opbed/opbed-frontend"
    port_base="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['port_base'])")"
    code="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['code'])")"
    dns_slug="$(workvm_host_card_dns_slug "$code")"
    host_uid="$(id -u)"
    host_gid="$(id -g)"
    app_url="http://api.${dns_slug}.olie.localhost"
    front_url="http://devframe.${dns_slug}.olie.localhost"
    ssh_dir="${HOME}/.ssh"

    if [ ! -d "$api" ]; then
        workvm_host_card_log "clone ausente: ${api}"
        return 1
    fi
    if [ ! -d "$front" ]; then
        workvm_host_card_log "clone ausente: ${front}"
        return 1
    fi

    if [ ! -f "${api}/.env" ] && [ -f "${api}/.env.example" ]; then
        workvm_host_card_log "opbed-backend/.env ausente — copiando de .env.example"
        cp -n "${api}/.env.example" "${api}/.env" || true
    fi
    if [ -f "${api}/.env" ]; then
        _hc_opbed_set_env "${api}/.env" APP_URL "$app_url"
        _hc_opbed_set_env "${api}/.env" DB_HOST pgsql
        _hc_opbed_set_env "${api}/.env" DB_DATABASE opbed_local
        _hc_opbed_set_env "${api}/.env" DB_USERNAME root
        _hc_opbed_set_env "${api}/.env" DB_PASSWORD password
        _hc_opbed_set_env "${api}/.env" API_PORT "$port_base"
        _hc_opbed_set_env "${api}/.env" FRONT_PORT "$((port_base + 1))"
        _hc_opbed_set_env "${api}/.env" HOST_UID "$host_uid"
        _hc_opbed_set_env "${api}/.env" HOST_GID "$host_gid"
    fi

    # Tokens Olie (card create / MCP) — mesmos confs da WorkVM.
    olie_mgmt=""
    olie_mcp=""
    if [ -f "${HOME}/.config/environment.d/olie.conf" ]; then
        # shellcheck disable=SC1091
        set -a
        source "${HOME}/.config/environment.d/olie.conf"
        set +a
        olie_mgmt="${OLIE_MANAGEMENT_TOKEN:-}"
        olie_mcp="${OLIE_FLOW_AI_MCP_TOKEN:-}"
    fi

    mkdir -p "$compose_dir"
    cp -f "${meta_repo}/opbed/sandbox/compose.host.yml" "$compose_dir/compose.yaml"

    pname="hc-${id}"
    {
        printf 'COMPOSE_PROJECT_NAME=%s\n' "$pname"
        printf 'SB_API=%s\n' "$api"
        printf 'SB_FRONT=%s\n' "$front"
        printf 'SB_DNS_SLUG=%s\n' "$dns_slug"
        printf 'SB_PORT_API=%s\n' "$port_base"
        printf 'SB_PORT_FRONT=%s\n' "$((port_base + 1))"
        printf 'HOST_UID=%s\n' "$host_uid"
        printf 'HOST_GID=%s\n' "$host_gid"
        printf 'HOME=%s\n' "$HOME"
        printf 'WORK_VM_SSH_DIR=%s\n' "$ssh_dir"
        printf 'DB_DATABASE=opbed_local\n'
        printf 'DB_USERNAME=root\n'
        printf 'DB_PASSWORD=password\n'
        printf 'APP_URL=%s\n' "$app_url"
        printf 'NEXT_PUBLIC_CLIENT_API_URL=%s/api\n' "$app_url"
        printf 'NEXT_PRIVATE_API_URL=http://backend:8000/api\n'
        printf 'HC_BACKEND_IMAGE=opbed-backend:host-card\n'
        printf 'HC_FRONTEND_IMAGE=opbed-frontend:host-card\n'
        printf 'OLIE_MANAGEMENT_TOKEN=%s\n' "$olie_mgmt"
        printf 'OLIE_FLOW_AI_MCP_TOKEN=%s\n' "$olie_mcp"
        workvm_host_card_write_resource_env
        printf 'COMPOSE_FILE=compose.yaml\n'
    } >"$compose_dir/.env"

    workvm_host_card_apply_compose_limits "$compose_dir"

    python3 - "$dir/meta.json" "$pname" "$compose_dir" "$dns_slug" "$port_base" <<'PY'
import json, sys
path, pname, compose_dir, slug, port_base = sys.argv[1:6]
port_base = int(port_base)
with open(path, encoding="utf-8") as f:
    meta = json.load(f)
meta["compose_project"] = pname
meta["compose_dir"] = compose_dir
meta["stack"] = "opbed-host"
meta["dns_slug"] = slug
meta["api_dns"] = f"http://api.{slug}.olie.localhost"
meta["front_dns"] = f"http://devframe.{slug}.olie.localhost"
meta["api_url"] = f"http://127.0.0.1:{port_base}"
meta["front_url"] = f"http://127.0.0.1:{port_base + 1}"
with open(path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
PY

    workvm_host_card_log "compose up ($pname) — build se preciso"
    (
        cd "$compose_dir"
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
        export COMPOSE_PROJECT_NAME="$pname"
        docker compose up -d --build --remove-orphans
    ) || return 1

    workvm_host_card_opbed_wait_api "$compose_dir" "$pname" || return 1
    workvm_host_card_proxy_ensure || workvm_host_card_log "proxy DNS falhou — use portas diretas"

    workvm_host_card_log "API  ${app_url}  (→ :${port_base})"
    workvm_host_card_log "Front ${front_url}  (→ :$((port_base + 1)))"
}

_hc_opbed_set_env() {
    local file="$1" key="$2" value="$3"
    if grep -q "^${key}=" "$file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        printf '%s=%s\n' "$key" "$value" >>"$file"
    fi
}

# Espera a API (composer+migrate no entrypoint no 1º boot).
workvm_host_card_opbed_wait_api() {
    local compose_dir="$1"
    local pname="$2"
    local i port

    port="$(python3 -c "import re;print(re.search(r'^SB_PORT_API=(\d+)', open('${compose_dir}/.env').read(), re.M).group(1))")"
    workvm_host_card_log "aguardando API em :${port}…"
    for i in $(seq 1 120); do
        if curl -fsS --connect-timeout 2 "http://127.0.0.1:${port}/up" >/dev/null 2>&1 \
            || curl -fsS --connect-timeout 2 "http://127.0.0.1:${port}/api" >/dev/null 2>&1 \
            || curl -fsS --connect-timeout 2 -o /dev/null -w '' "http://127.0.0.1:${port}/" >/dev/null 2>&1; then
            workvm_host_card_log "API pronta"
            return 0
        fi
        sleep 3
    done
    workvm_host_card_log "API não respondeu a tempo — veja: docker compose -p ${pname} logs backend"
    return 1
}
