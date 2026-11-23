# Hook use-url-query: sobe lib bun + demo API Laravel + demo web Next.
# Problema: ensure só subia o bun da lib; demos (web/api) não tinham stack
# namespaced. Sourced by lib/host-card.sh.

workvm_host_card_ensure_hook() {
    local id="$1"
    local dir="$2"
    local meta_repo git_root compose_dir port_base
    local lib api front
    local code dns_slug pname app_url front_url
    local host_uid host_gid

    meta_repo="$(workvm_host_card_meta_repo)"
    git_root="$(workvm_host_card_git_root)"
    # shellcheck source=/dev/null
    source "${meta_repo}/lib/host-card-proxy.sh"

    compose_dir="${dir}/compose"
    lib="${git_root}/use-url-query/use-url-query"
    api="${git_root}/use-url-query/use-url-query-demo-api"
    front="${git_root}/use-url-query/use-url-query-demo-web"
    port_base="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['port_base'])")"
    code="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['code'])")"
    dns_slug="$(workvm_host_card_dns_slug "$code")"
    host_uid="$(id -u)"
    host_gid="$(id -g)"
    app_url="http://api.${dns_slug}.olie.localhost"
    front_url="http://devframe.${dns_slug}.olie.localhost"

    for path in "$lib" "$api" "$front"; do
        if [ ! -d "$path" ]; then
            workvm_host_card_log "clone ausente: ${path}"
            return 1
        fi
    done

    if [ ! -f "${api}/.env" ] && [ -f "${api}/.env.example" ]; then
        workvm_host_card_log "demo-api/.env ausente — copiando de .env.example"
        cp -n "${api}/.env.example" "${api}/.env" || true
    fi
    if [ -f "${api}/.env" ]; then
        _hc_uuq_set_env "${api}/.env" APP_URL "$app_url"
        _hc_uuq_set_env "${api}/.env" DB_HOST postgres
        _hc_uuq_set_env "${api}/.env" DB_DATABASE use_url_query_demo_api_local
        _hc_uuq_set_env "${api}/.env" DB_USERNAME root
        _hc_uuq_set_env "${api}/.env" DB_PASSWORD secret
        _hc_uuq_set_env "${api}/.env" REDIS_HOST redis
        _hc_uuq_set_env "${api}/.env" UID "$host_uid"
        _hc_uuq_set_env "${api}/.env" GID "$host_gid"
    fi

    mkdir -p "$compose_dir"
    cp -f "${meta_repo}/use-url-query/sandbox/compose.host.yml" "$compose_dir/compose.yaml"

    # Vitest no Card precisa de Node real (mesma tag do sandbox slim).
    _hc_uuq_ensure_lib_image "${meta_repo}" \
        || workvm_host_card_log "aviso: build use-url-query-sandbox-backend:tests falhou"

    pname="hc-${id}"
    {
        printf 'COMPOSE_PROJECT_NAME=%s\n' "$pname"
        printf 'SB_LIB=%s\n' "$lib"
        printf 'SB_API=%s\n' "$api"
        printf 'SB_FRONT=%s\n' "$front"
        printf 'SB_DNS_SLUG=%s\n' "$dns_slug"
        printf 'SB_PORT_API=%s\n' "$port_base"
        # Demo Next na :3000 do host (produto sem N cards paralelos como Olie).
        printf 'SB_PORT_FRONT=3000\n'
        printf 'SB_PORT_VITE=%s\n' "$((port_base + 2))"
        printf 'HOST_UID=%s\n' "$host_uid"
        printf 'HOST_GID=%s\n' "$host_gid"
        printf 'DB_DATABASE=use_url_query_demo_api_local\n'
        printf 'DB_USERNAME=root\n'
        printf 'DB_PASSWORD=secret\n'
        printf 'APP_URL=%s\n' "$app_url"
        printf 'HC_BUN_IMAGE=%s\n' "${HC_BUN_IMAGE:-use-url-query-sandbox-backend:tests}"
        printf 'HC_PHPFPM_IMAGE=uuq-demo-php-fpm:host-card\n'
        printf 'HC_WORKSPACE_IMAGE=uuq-demo-workspace:host-card\n'
        printf 'HC_FRONT_IMAGE=uuq-demo-web:host-card\n'
        workvm_host_card_write_resource_env 2>/dev/null || true
        # Não gravar COMPOSE_FILE aqui: o env herdado do WorkVM/agent
        # (ex. compose.dev.yaml) vaza no `docker compose exec` e aponta
        # para o YAML errado. _hc_uuq_dc passa -f compose.yaml.
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
meta["api_dns"] = f"http://api.{slug}.olie.localhost"
meta["front_dns"] = f"http://devframe.{slug}.olie.localhost"
meta["api_url"] = f"http://127.0.0.1:{port_base}"
meta["front_port"] = 3000
meta["front_url"] = "http://127.0.0.1:3000"
with open(path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
PY

    workvm_host_card_log "compose up ($pname) — lib + demo-api + demo-web"
    _hc_uuq_dc "$compose_dir" "$pname" up -d --build --remove-orphans || return 1

    # vendor / APP_KEY: php-fpm lê env_file na criação — key vazia fica no
    # ambiente do container até recreate, mesmo com .env já preenchido.
    if [ ! -f "${api}/vendor/autoload.php" ]; then
        workvm_host_card_log "composer install (demo-api)"
        _hc_uuq_dc "$compose_dir" "$pname" exec -T workspace \
            composer install --no-interaction --prefer-dist \
            || workvm_host_card_log "composer install falhou — API pode responder 500"
    fi
    if [ -f "${api}/.env" ] && ! grep -qE '^APP_KEY=base64:.+' "${api}/.env" 2>/dev/null; then
        workvm_host_card_log "gerando APP_KEY (demo-api)"
        _hc_uuq_dc "$compose_dir" "$pname" exec -T workspace \
            php artisan key:generate --force 2>/dev/null || true
        workvm_host_card_log "recreate php-fpm/workspace (env_file APP_KEY)"
        _hc_uuq_dc "$compose_dir" "$pname" up -d --force-recreate php-fpm workspace web \
            || workvm_host_card_log "recreate php-fpm falhou"
    fi
    _hc_uuq_dc "$compose_dir" "$pname" exec -T workspace \
        php artisan migrate --force --no-interaction 2>/dev/null || true

    # Confirma os três serviços do produto (não só HTTP das demos).
    _hc_uuq_dc "$compose_dir" "$pname" ps --status running --services 2>/dev/null \
        | grep -qx lib \
        || workvm_host_card_log "aviso: serviço lib não está running"
    workvm_host_card_uuq_wait_http "$compose_dir" "$pname" SB_PORT_API "demo-api" || return 1
    workvm_host_card_uuq_wait_http "$compose_dir" "$pname" SB_PORT_FRONT "demo-web" || return 1
    workvm_host_card_proxy_ensure || workvm_host_card_log "proxy DNS falhou — use portas diretas"

    workvm_host_card_log "Lib  bun (service lib)"
    workvm_host_card_log "API  ${app_url}  (→ :${port_base})"
    workvm_host_card_log "Front ${front_url}  (→ :3000)"
}

# Garante a imagem Bun+Node do serviço lib (Vitest no Card).
# Problema: oven/bun faz `node` → bun; pre-deploy `bun run test` quebra.
_hc_uuq_ensure_lib_image() {
    local meta_repo="$1"
    local tag=use-url-query-sandbox-backend:tests
    local df="${meta_repo}/use-url-query/sandbox/Dockerfile.backend"

    if [ ! -f "$df" ]; then
        workvm_host_card_log "Dockerfile.backend ausente: $df"
        return 1
    fi
    if docker image inspect "$tag" >/dev/null 2>&1; then
        if docker run --rm --entrypoint node "$tag" -e \
            'if (process.versions.bun) process.exit(1)' >/dev/null 2>&1; then
            return 0
        fi
        workvm_host_card_log "${tag} sem Node real — rebuild"
    else
        workvm_host_card_log "build ${tag} (Bun + Node)"
    fi
    docker build -t "$tag" \
        -f "$df" \
        "${meta_repo}/use-url-query/sandbox"
}

# docker compose do card: -f absoluto + COMPOSE_FILE herdado limpo.
# Problema: agent/WorkVM exporta COMPOSE_FILE (outro YAML) e o exec
# ignora --project-directory / .env do card.
_hc_uuq_dc() {
    local compose_dir="$1"
    local pname="$2"
    shift 2
    env -u COMPOSE_FILE docker compose \
        -p "$pname" \
        --project-directory "$compose_dir" \
        -f "${compose_dir}/compose.yaml" \
        "$@"
}

_hc_uuq_set_env() {
    local file="$1" key="$2" value="$3"
    if grep -q "^${key}=" "$file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        printf '%s=%s\n' "$key" "$value" >>"$file"
    fi
}

workvm_host_card_uuq_wait_http() {
    local compose_dir="$1"
    local pname="$2"
    local env_key="$3"
    local label="$4"
    local i port code

    port="$(python3 -c "import re;print(re.search(r'^${env_key}=(\d+)', open('${compose_dir}/.env').read(), re.M).group(1))")"
    workvm_host_card_log "aguardando ${label} em :${port}…"
    for i in $(seq 1 120); do
        # Qualquer HTTP (incl. 500) conta — porta aberta + processo respondendo.
        # Preferir 2xx/3xx quando já existir; 5xx ainda passa o wait (open não
        # deve abortar só porque APP_KEY/vendor ainda não estabilizou).
        code="$(curl -sS --connect-timeout 2 -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}/" 2>/dev/null || true)"
        if [ -n "$code" ] && [ "$code" != "000" ]; then
            workvm_host_card_log "${label} pronto (HTTP ${code})"
            return 0
        fi
        sleep 3
    done
    workvm_host_card_log "${label} não respondeu a tempo — veja: docker compose -p ${pname} logs"
    return 1
}
