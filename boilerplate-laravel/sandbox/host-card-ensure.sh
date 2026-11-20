# Hook boilerplate-laravel: sobe Laravel (nginx+php-fpm+workspace) namespaced no host.
# Problema: ensure do projeto só clonava e abria Cursor — sem compose o
# app não “roda”. Sourced by lib/host-card.sh.

workvm_host_card_ensure_hook() {
    local id="$1"
    local dir="$2"
    local meta_repo git_root compose_dir port_base app
    local code dns_slug pname app_url vite_url
    local host_uid host_gid

    meta_repo="$(workvm_host_card_meta_repo)"
    git_root="$(workvm_host_card_git_root)"
    # shellcheck source=/dev/null
    source "${meta_repo}/lib/host-card-proxy.sh"
    # shellcheck source=/dev/null
    source "${meta_repo}/boilerplate-laravel/sandbox/host-card-shared-data.sh"

    workvm_host_card_bl_ensure_shared_data || workvm_host_card_log "hc-boilerplate-laravel-data falhou — sandboxes sem shared data"

    compose_dir="${dir}/compose"
    app="${git_root}/boilerplate-laravel/boilerplate-laravel"
    port_base="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['port_base'])")"
    code="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['code'])")"
    dns_slug="$(workvm_host_card_dns_slug "$code")"
    host_uid="$(id -u)"
    host_gid="$(id -g)"
    app_url="http://api.${dns_slug}.olie.localhost"
    vite_url="http://devframe.${dns_slug}.olie.localhost"

    if [ ! -d "$app" ]; then
        workvm_host_card_log "clone ausente: ${app}"
        return 1
    fi

    if [ ! -f "${app}/.env" ] && [ -f "${app}/.env.example" ]; then
        workvm_host_card_log "boilerplate-laravel/.env ausente — copiando de .env.example"
        cp -n "${app}/.env.example" "${app}/.env" || true
    fi
    if [ -f "${app}/.env" ]; then
        _hc_bl_set_env "${app}/.env" APP_URL "$app_url"
        _hc_bl_set_env "${app}/.env" DB_HOST postgres
        _hc_bl_set_env "${app}/.env" DB_DATABASE boilerplate_local
        _hc_bl_set_env "${app}/.env" DB_USERNAME root
        _hc_bl_set_env "${app}/.env" DB_PASSWORD secret
        _hc_bl_set_env "${app}/.env" REDIS_HOST redis
        _hc_bl_set_env "${app}/.env" NGINX_PORT "$port_base"
        _hc_bl_set_env "${app}/.env" VITE_PORT "$((port_base + 1))"
        _hc_bl_set_env "${app}/.env" UID "$host_uid"
        _hc_bl_set_env "${app}/.env" GID "$host_gid"
        if ! grep -q '^APP_KEY=base64:' "${app}/.env" 2>/dev/null; then
            # key vazia — gera no workspace depois do up
            :
        fi
    fi

    mkdir -p "$compose_dir"
    cp -f "${meta_repo}/boilerplate-laravel/sandbox/compose.host.yml" "$compose_dir/compose.yaml"

    pname="hc-${id}"
    {
        printf 'COMPOSE_PROJECT_NAME=%s\n' "$pname"
        printf 'SB_APP=%s\n' "$app"
        printf 'SB_DNS_SLUG=%s\n' "$dns_slug"
        printf 'SB_PORT_WEB=%s\n' "$port_base"
        printf 'SB_PORT_VITE=%s\n' "$((port_base + 1))"
        printf 'HOST_UID=%s\n' "$host_uid"
        printf 'HOST_GID=%s\n' "$host_gid"
        printf 'DB_DATABASE=boilerplate_local\n'
        printf 'DB_USERNAME=root\n'
        printf 'DB_PASSWORD=secret\n'
        printf 'APP_URL=%s\n' "$app_url"
        printf 'HC_PHPFPM_IMAGE=boilerplate-laravel-php-fpm:host-card\n'
        printf 'HC_WORKSPACE_IMAGE=boilerplate-laravel-workspace:sandbox\n'
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
meta["stack"] = "boilerplate-laravel-host"
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

    # APP_KEY / migrate no workspace
    if [ -f "${app}/.env" ] && ! grep -qE '^APP_KEY=base64:.+' "${app}/.env" 2>/dev/null; then
        workvm_host_card_log "gerando APP_KEY"
        docker compose -p "$pname" --project-directory "$compose_dir" exec -T workspace \
            php artisan key:generate --force 2>/dev/null || true
    fi
    docker compose -p "$pname" --project-directory "$compose_dir" exec -T workspace \
        php artisan migrate --force --no-interaction 2>/dev/null || true

    workvm_host_card_bl_wait_web "$compose_dir" "$pname" || return 1
    workvm_host_card_proxy_ensure || workvm_host_card_log "proxy DNS falhou — use portas diretas"

    workvm_host_card_log "App  ${app_url}  (→ :${port_base})"
    workvm_host_card_log "Vite ${vite_url}  (→ :$((port_base + 1)))"
}

_hc_bl_set_env() {
    local file="$1" key="$2" value="$3"
    if grep -q "^${key}=" "$file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        printf '%s=%s\n' "$key" "$value" >>"$file"
    fi
}

workvm_host_card_bl_wait_web() {
    local compose_dir="$1"
    local pname="$2"
    local i port

    port="$(python3 -c "import re;print(re.search(r'^SB_PORT_WEB=(\d+)', open('${compose_dir}/.env').read(), re.M).group(1))")"
    workvm_host_card_log "aguardando web em :${port}…"
    for i in $(seq 1 120); do
        if curl -fsS --connect-timeout 2 "http://127.0.0.1:${port}/up" >/dev/null 2>&1 \
            || curl -fsS --connect-timeout 2 -o /dev/null -w '' "http://127.0.0.1:${port}/" >/dev/null 2>&1; then
            workvm_host_card_log "web pronta"
            return 0
        fi
        sleep 3
    done
    workvm_host_card_log "web não respondeu a tempo — veja: docker compose -p ${pname} logs"
    return 1
}
