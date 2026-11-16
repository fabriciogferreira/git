# Hook Televisão: sobe API Laravel + Next namespaced no host (sem WorkVM).
# Problema: o slim (php -S no meta-dir) respondia 404 em /; o card precisa
# do stack de login (pgsql + backend + front) com portas/DNS por código.
# Sourced by lib/host-card.sh — define workvm_host_card_ensure_hook.

workvm_host_card_ensure_hook() {
    local id="$1"
    local dir="$2"
    local meta_repo git_root compose_dir port_base wt api front
    local code dns_slug front_env pname app_url front_url
    local host_uid host_gid

    meta_repo="$(workvm_host_card_meta_repo)"
    git_root="$(workvm_host_card_git_root)"
    # shellcheck source=/dev/null
    source "${meta_repo}/lib/host-card-proxy.sh"

    compose_dir="${dir}/compose"
    wt="${git_root}/televisao"
    api="${wt}/televisao-api"
    front="${wt}/televisao-front"
    port_base="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['port_base'])")"
    code="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['code'])")"
    dns_slug="$(workvm_host_card_dns_slug "$code")"
    host_uid="$(id -u)"
    host_gid="$(id -g)"
    app_url="http://api.${dns_slug}.olie.localhost"
    front_url="http://devframe.${dns_slug}.olie.localhost"

    if [ ! -d "$api" ]; then
        workvm_host_card_log "clone ausente: ${api} (rode project-setup televisao no host)"
        return 1
    fi
    if [ ! -d "$front" ]; then
        workvm_host_card_log "clone ausente: ${front}"
        return 1
    fi

    # .env da API (gitignored) — senão migrate/DB_HOST falham
    if [ ! -f "${api}/.env" ] && [ -f "${api}/.env.example" ]; then
        workvm_host_card_log "televisao-api/.env ausente — copiando de .env.example"
        cp -n "${api}/.env.example" "${api}/.env" || true
    fi
    if [ -f "${api}/.env" ]; then
        _hc_tv_set_env "${api}/.env" HOST_UID "$host_uid"
        _hc_tv_set_env "${api}/.env" HOST_GID "$host_gid"
        _hc_tv_set_env "${api}/.env" DB_HOST postgresql
        _hc_tv_set_env "${api}/.env" REDIS_HOST redis
        _hc_tv_set_env "${api}/.env" APP_URL "$app_url"
        _hc_tv_set_env "${api}/.env" FRONTEND_URL "${front_url}/"
        _hc_tv_set_env "${api}/.env" BROADCAST_CONNECTION log
    fi

    # Next: URLs DNS do card (não localhost:8000 da WorkVM)
    front_env="${dir}/front.env.local"
    cat >"$front_env" <<EOF
NEXT_PUBLIC_API_URL="${app_url}/api/"
NEXT_PUBLIC_API_IMAGE_URL="${app_url}/storage/"
NEXT_PUBLIC_REVERB_APP_KEY=my-app-key
NEXT_PUBLIC_REVERB_HOST=localhost
NEXT_PUBLIC_REVERB_PORT=8080
NEXT_PUBLIC_REVERB_SCHEME=http
NEXT_PUBLIC_MEET_URL=http://localhost:3001/meet/enterscience
EOF

    mkdir -p "$compose_dir/artifacts"
    cp -f "${meta_repo}/televisao/sandbox/compose.host.yml" "$compose_dir/compose.yaml"
    # Dockerfile precisa estar no context do build (BuildKit recusa path fora)
    cp -f "${meta_repo}/televisao/sandbox/Dockerfile.host-api" "${api}/Dockerfile.host-card"
    if [ -d "${api}/.git" ] || [ -f "${api}/.git" ]; then
        mkdir -p "${api}/.git/info"
        touch "${api}/.git/info/exclude"
        if ! grep -qxF '/Dockerfile.host-card' "${api}/.git/info/exclude" 2>/dev/null; then
            printf '/Dockerfile.host-card\n' >>"${api}/.git/info/exclude"
        fi
    fi

    pname="hc-${id}"
    {
        printf 'COMPOSE_PROJECT_NAME=%s\n' "$pname"
        printf 'SB_API=%s\n' "$api"
        printf 'SB_FRONT=%s\n' "$front"
        printf 'SB_FRONT_ENV=%s\n' "$front_env"
        printf 'SB_DOCKERFILE=Dockerfile.host-card\n'
        printf 'SB_DNS_SLUG=%s\n' "$dns_slug"
        printf 'SB_PORT_API=%s\n' "$port_base"
        printf 'SB_PORT_FRONT=%s\n' "$((port_base + 1))"
        printf 'HOST_UID=%s\n' "$host_uid"
        printf 'HOST_GID=%s\n' "$host_gid"
        printf 'DB_DATABASE=db_televisao\n'
        printf 'DB_USERNAME=root\n'
        printf 'DB_PASSWORD=password\n'
        printf 'APP_URL=%s\n' "$app_url"
        printf 'FRONTEND_URL=%s/\n' "$front_url"
        printf 'HC_BACKEND_IMAGE=televisao-backend:host-card\n'
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
meta["stack"] = "televisao-host"
meta["dns_slug"] = slug
meta["api_dns"] = f"http://api.{slug}.olie.localhost"
meta["front_dns"] = f"http://devframe.{slug}.olie.localhost"
meta["api_url"] = f"http://127.0.0.1:{port_base}"
meta["front_url"] = f"http://127.0.0.1:{port_base + 1}"
with open(path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
PY

    # Troca slim → host: derruba o stub antigo se ainda existir
    (
        cd "$compose_dir"
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
        export COMPOSE_PROJECT_NAME="$pname"
        docker compose --profile slim down --remove-orphans 2>/dev/null || true
        docker compose down --remove-orphans 2>/dev/null || true
    ) || true

    workvm_host_card_log "compose up ($pname) — build backend se preciso"
    (
        cd "$compose_dir"
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
        export COMPOSE_PROJECT_NAME="$pname"
        docker compose up -d --build --remove-orphans
    ) || return 1

    workvm_host_card_televisao_wait_api "$compose_dir" "$pname" || return 1
    workvm_host_card_proxy_ensure || workvm_host_card_log "proxy DNS falhou — use portas diretas"

    workvm_host_card_log "API  ${app_url}  (→ :${port_base})"
    workvm_host_card_log "Front ${front_url}  (→ :$((port_base + 1)))"
}

# KEY=value no .env sem apagar o resto (sed in-place).
_hc_tv_set_env() {
    local file="$1" key="$2" value="$3"
    if grep -q "^${key}=" "$file" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        printf '%s=%s\n' "$key" "$value" >>"$file"
    fi
}

# Espera /up (composer+migrate no setup.sh podem levar minutos no 1º boot).
workvm_host_card_televisao_wait_api() {
    local compose_dir="$1"
    local pname="$2"
    local i port

    port="$(python3 -c "import re;print(re.search(r'^SB_PORT_API=(\d+)', open('${compose_dir}/.env').read(), re.M).group(1))")"
    workvm_host_card_log "aguardando API /up em :${port}…"
    for i in $(seq 1 120); do
        if curl -fsS --connect-timeout 2 "http://127.0.0.1:${port}/up" >/dev/null 2>&1; then
            workvm_host_card_log "API pronta"
            return 0
        fi
        sleep 3
    done
    workvm_host_card_log "API não respondeu /up a tempo — veja: docker compose -p ${pname} logs backend"
    return 1
}
