# Plugin Olie para o Sandbox Manager.
# Problema: mutation/Pest no host-card compartilhavam MySQL `testing` e
# corrompiam `api_main` quando o colleague-review disparava gates em paralelo.
# Isola worktree por sandbox; MySQL/Redis/Mongo vêm do stack compartilhado
# hc-olie-data (mesmo dos host-cards) com DB/prefixo por id — sem N× instâncias.
# Opt-out: WORKVM_SANDBOX_SHARED_DATA=0 (volta mysql/redis/mongo do slim).

workvm_sandbox_project_max() {
    # 0 = sem teto (jarvis/host-card: N mutations em paralelo).
    # Cap explícito: WORKVM_SANDBOX_MAX=N.
    printf '%s\n' "${WORKVM_SANDBOX_MAX:-0}"
}

workvm_sandbox_project_mem_limit() {
    local profile="$1"
    case "$profile" in
        e2e) printf '1536m\n' ;;
        mutation) printf '1536m\n' ;;
        *) printf '1g\n' ;;
    esac
}

workvm_sandbox_project_cpus() {
    local profile="$1"
    case "$profile" in
        e2e) printf '1.5\n' ;;
        mutation) printf '1.5\n' ;;
        *) printf '1.0\n' ;;
    esac
}

workvm_sandbox_project_repos() {
    # Paths relative to ~/git/olie/ (clones da empresa).
    printf '%s\n' api-main olie-fronts
}

# Prefixo sb_ evita colisão com api_<dns_slug> dos host-cards no mesmo MySQL.
workvm_sandbox_olie_db_slug() {
    local id="$1"
    local s
    s="$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]' | tr '-' '_' | tr -c 'a-z0-9_' '_' | sed 's/__*/_/g; s/^_//; s/_$//')"
    printf 'sb_%s\n' "$s"
}

workvm_sandbox_olie_shared_data_enabled() {
    case "${WORKVM_SANDBOX_SHARED_DATA:-1}" in
        0|false|no|off) return 1 ;;
        *) return 0 ;;
    esac
}

# host-card-shared-data.sh precisa de workvm_host_card_{root,meta_repo,log}.
workvm_sandbox_olie_load_shared_data() {
    local meta_repo
    meta_repo="$(workvm_sandbox_meta_repo)"
    if declare -F workvm_host_card_olie_ensure_shared_data >/dev/null; then
        return 0
    fi
    if ! declare -F workvm_host_card_root >/dev/null; then
        workvm_host_card_root() {
            printf '%s\n' "${WORKVM_HOST_CARD_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/workvm/host-cards}"
        }
        workvm_host_card_meta_repo() { workvm_sandbox_meta_repo; }
        workvm_host_card_log() { printf 'workvm-host-card: %s\n' "$*" >&2; }
    fi
    # shellcheck source=/dev/null
    source "${meta_repo}/olie/sandbox/host-card-shared-data.sh"
}

workvm_sandbox_olie_load_testing_db_cache() {
    local meta_repo
    meta_repo="$(workvm_sandbox_meta_repo)"
    if declare -F workvm_olie_testing_db_cache_ensure_for_sandbox >/dev/null; then
        return 0
    fi
    # shellcheck source=/dev/null
    source "${meta_repo}/olie/sandbox/testing-db-cache.sh"
}

# Após compose up: importa dump do testing DB (ou build no miss) + stamp FastRefresh.
workvm_sandbox_project_after_up() {
    local id="$1"
    local wt="$2"
    local testing_db api_db

    workvm_sandbox_olie_shared_data_enabled || return 0
    workvm_sandbox_olie_load_testing_db_cache || return 0
    testing_db="$(workvm_sandbox_meta_get "$id" testing_database 2>/dev/null || true)"
    api_db="$(workvm_sandbox_meta_get "$id" db_database 2>/dev/null || true)"
    if [ -z "$testing_db" ]; then
        testing_db="testing_$(workvm_sandbox_olie_db_slug "$id")"
    fi
    if [ -z "$api_db" ]; then
        api_db="api_$(workvm_sandbox_olie_db_slug "$id")"
    fi
    workvm_olie_testing_db_cache_ensure_for_sandbox "$id" "$wt" "$testing_db" "$api_db" || true
}

# Garante olie/api-main-sandbox:latest (PCOV). Se a base olie/api-main:latest
# não existir, builda via compose web do meta (mesmo caminho do smoke-case1) —
# host-card/ensure não pode depender da host-card já ter subido o stack.
workvm_sandbox_olie_ensure_sandbox_image() {
    local meta_repo git_root
    meta_repo="$(workvm_sandbox_meta_repo)"
    git_root="$(workvm_sandbox_git_root)"

    workvm_sandbox_docker_ok || return 1

    if docker image inspect olie/api-main-sandbox:latest >/dev/null 2>&1; then
        return 0
    fi
    if ! docker image inspect olie/api-main:latest >/dev/null 2>&1; then
        if [ ! -d "${git_root}/olie/api-main" ] || [ ! -f "${git_root}/olie/docker-compose.yml" ]; then
            workvm_sandbox_log "olie/api-main:latest ausente e sem ${git_root}/olie para build (project-setup olie?)"
            return 1
        fi
        workvm_sandbox_log "build olie/api-main:latest (compose web — base do host-card/sandbox)"
        (cd "${git_root}/olie" && GIT_ROOT="$git_root" docker compose build web) || {
            workvm_sandbox_log "falha ao buildar olie/api-main:latest"
            return 1
        }
    fi
    workvm_sandbox_log "build olie/api-main-sandbox:latest (PCOV)"
    docker build -t olie/api-main-sandbox:latest \
        -f "${meta_repo}/olie/sandbox/Dockerfile.app" \
        "${meta_repo}/olie/sandbox"
}

workvm_sandbox_olie_link_vendor() {
    # Vendor is bind-mounted via SB_API_VENDOR in compose (absolute host
    # symlinks break inside the container). Only link node_modules for host tools.
    local src="$1"
    local dest="$2"
    if [ -e "${src}/node_modules" ] && [ ! -e "${dest}/node_modules" ]; then
        ln -sfn "${src}/node_modules" "${dest}/node_modules"
    fi
    # Placeholder so accidental host php without the mount fails clearly.
    if [ ! -e "${dest}/vendor" ]; then
        mkdir -p "${dest}/vendor"
        printf '# mounted at runtime as SB_API_VENDOR → /var/www/html/vendor\n' \
            >"${dest}/vendor/README.sandbox.md"
    fi
}

# Patch phpunit.xml do worktree: Pest usa DB_DATABASE=testing por default;
# no shared MySQL cada sandbox precisa de testing_sb_<id> (+ _test_N).
# force="true": o compose injeta DB_DATABASE=api_sb_* no ambiente do
# container; sem force o PHPUnit não sobrescreve e o 1º Pest migra api_sb
# (~90s) em vez de usar testing_sb (e o dump cache).
workvm_sandbox_olie_patch_phpunit_db() {
    local phpunit="$1"
    local testing_db="$2"
    [ -f "$phpunit" ] || return 0
    if grep -q 'name="DB_DATABASE"' "$phpunit"; then
        sed -i -E "s|<env name=\"DB_DATABASE\"[^/]*/>|<env name=\"DB_DATABASE\" value=\"${testing_db}\" force=\"true\"/>|" "$phpunit"
    fi
    if grep -q 'name="CACHE_PREFIX"' "$phpunit"; then
        sed -i -E "s|<env name=\"CACHE_PREFIX\"[^/]*/>|<env name=\"CACHE_PREFIX\" value=\"${testing_db}_env\" force=\"true\"/>|" "$phpunit"
    fi
}

workvm_sandbox_olie_write_env() {
    local src_env="$1"
    local dest_env="$2"
    local api_db="${3:-api_main}"
    local redis_prefix="${4:-}"
    local db_host=mysql
    local mongo_host=mongo
    local redis_host=redis

    if workvm_sandbox_olie_shared_data_enabled; then
        db_host=olie-hc-mysql
        mongo_host=olie-hc-mongo
        redis_host=olie-hc-redis
        [ -n "$redis_prefix" ] || redis_prefix="${api_db}_"
    fi

    if [ -f "$src_env" ]; then
        cp -f "$src_env" "$dest_env"
    else
        printf 'APP_KEY=base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\n' >"$dest_env"
    fi
    # KEY= vazio: Laravel trata env() como setado → config perde o default
    # (ex. META_GRAPH_URL= → graph_url '' em vez de graph.facebook.com).
    # Só na cópia do sandbox; não mexe no .env do clone/card.
    if [ -f "$dest_env" ]; then
        sed -i -E '/^[A-Z][A-Z0-9_]*=[[:space:]]*$/d' "$dest_env"
    fi
    local key val
    for key in \
        "DB_HOST=${db_host}" \
        DB_PORT=3306 \
        "DB_DATABASE=${api_db}" \
        DB_USERNAME=sandbox \
        DB_PASSWORD=sandbox \
        "MONGODB_HOST=${mongo_host}" \
        MONGODB_PORT=27017 \
        "MONGODB_DATABASE=${api_db}" \
        MONGODB_USERNAME=sandbox \
        MONGODB_PASSWORD=sandbox \
        "REDIS_HOST=${redis_host}" \
        REDIS_PORT=6379 \
        REDIS_PASSWORD=null \
        "REDIS_PREFIX=${redis_prefix}"
    do
        val="${key#*=}"
        key="${key%%=*}"
        if grep -q "^${key}=" "$dest_env" 2>/dev/null; then
            sed -i "s|^${key}=.*|${key}=${val}|" "$dest_env"
        else
            printf '%s=%s\n' "$key" "$val" >>"$dest_env"
        fi
    done
}

workvm_sandbox_project_prepare_worktrees() {
    local id="$1"
    local wt="$2"
    local from_commit="${3:-}"
    local git_root project_root repo src dest
    local db_slug api_db testing_db redis_prefix
    # wt vazio → dest "/api-main" / "/e2e/" (pé-de-cabra DOP-1136)
    workvm_assert_safe_destructive_path "$wt" || return 1
    git_root="$(workvm_sandbox_git_root)"
    project_root="${git_root}/olie"
    db_slug="$(workvm_sandbox_olie_db_slug "$id")"
    api_db="api_${db_slug}"
    testing_db="testing_${db_slug}"
    redis_prefix="${db_slug}_"

    mkdir -p "$wt/e2e"
    printf 'sandbox=%s\n' "$id" >"$wt/.sandbox-id"

    # Exclude sandbox worktrees from the meta-repo noise.
    local exclude="${project_root}/.git/info/exclude"
    if [ -d "${project_root}/.git" ] || [ -f "${project_root}/.git" ]; then
        mkdir -p "$(dirname "$exclude")"
        touch "$exclude"
        if ! grep -qxF '/.sandboxes/' "$exclude" 2>/dev/null; then
            printf '/.sandboxes/\n' >>"$exclude"
        fi
    fi
    # Meta-repo root also lists olie/.sandboxes when project_root is not a git dir.
    exclude="$(workvm_sandbox_meta_repo)/.git/info/exclude"
    if [ -d "$(dirname "$exclude")" ]; then
        mkdir -p "$(dirname "$exclude")"
        touch "$exclude"
        if ! grep -qxF '/olie/.sandboxes/' "$exclude" 2>/dev/null; then
            printf '/olie/.sandboxes/\n' >>"$exclude"
        fi
    fi

    while IFS= read -r repo; do
        [ -n "$repo" ] || continue
        src="${project_root}/${repo}"
        dest="${wt}/${repo}"
        if [ -d "${src}/.git" ] || [ -f "${src}/.git" ]; then
            if [ -d "$dest" ]; then
                workvm_sandbox_olie_link_vendor "$src" "$dest"
                continue
            fi
            workvm_sandbox_log "worktree $repo → $dest"
            if [ -n "$from_commit" ]; then
                git -C "$src" worktree add --detach "$dest" "$from_commit"
            else
                git -C "$src" worktree add --detach "$dest" HEAD
            fi
            workvm_sandbox_olie_link_vendor "$src" "$dest"
            mkdir -p "${dest}/storage/logs" \
                "${dest}/storage/framework/cache" \
                "${dest}/storage/framework/sessions" \
                "${dest}/storage/framework/views" \
                "${dest}/bootstrap/cache"
            if [ "$repo" = "api-main" ]; then
                workvm_sandbox_olie_write_env "${src}/.env" "${dest}/.env" "$api_db" "$redis_prefix"
                if workvm_sandbox_olie_shared_data_enabled; then
                    workvm_sandbox_olie_patch_phpunit_db "${dest}/phpunit.xml" "$testing_db"
                fi
            fi
        else
            mkdir -p "$dest"
            printf '# clone %s ausente neste host; dir vazio no sandbox\n' "$repo" >"$dest/README.sandbox.md"
        fi
    done < <(workvm_sandbox_project_repos)

    # olie-e2e vive no meta-repo (não é clone separado).
    local e2e_src="${project_root}/olie-e2e"
    if [ -d "$e2e_src" ] && [ ! -e "${wt}/e2e/package.json" ]; then
        # Cópia leve de specs — evita e2e paralelo no mesmo tree do meta-repo.
        # Guard: wt vazio faria dest=/e2e/ com --delete.
        workvm_assert_safe_destructive_path "${wt}/e2e" || return 1
        rsync -a --delete \
            --exclude node_modules --exclude test-results --exclude playwright-report \
            "${e2e_src}/" "${wt}/e2e/" 2>/dev/null \
            || cp -a "${e2e_src}/." "${wt}/e2e/"
    fi
}

workvm_sandbox_project_remove_worktrees() {
    local id="$1"
    local wt="$2"
    local git_root project_root repo src dest db_slug
    workvm_assert_safe_destructive_path "$wt" || return 1
    git_root="$(workvm_sandbox_git_root)"
    project_root="${git_root}/olie"

    if workvm_sandbox_olie_shared_data_enabled; then
        db_slug="$(workvm_sandbox_olie_db_slug "$id")"
        workvm_sandbox_olie_load_shared_data || true
        if declare -F workvm_host_card_olie_drop_card_databases >/dev/null; then
            workvm_sandbox_log "drop shared DBs for $db_slug"
            workvm_host_card_olie_drop_card_databases "$db_slug" || true
        fi
    fi

    while IFS= read -r repo; do
        [ -n "$repo" ] || continue
        src="${project_root}/${repo}"
        dest="${wt}/${repo}"
        if [ -d "${src}/.git" ] || [ -f "${src}/.git" ]; then
            if [ -d "$dest" ]; then
                if [ -L "${dest}/node_modules" ]; then
                    rm -f "${dest}/node_modules"
                fi
                # Placeholder vendor/ dir (not a git link) — remove so worktree remove is clean.
                if [ -d "${dest}/vendor" ] && [ ! -L "${dest}/vendor" ]; then
                    rm -rf "${dest}/vendor"
                fi
                git -C "$src" worktree remove --force "$dest" 2>/dev/null \
                    || rm -rf "$dest"
            fi
        fi
    done < <(workvm_sandbox_project_repos)

    rm -rf "$wt"
}

workvm_sandbox_project_render_compose() {
    local id="$1"
    local compose_dir="$2"
    local wt="$3"
    local profile="$4"
    local port_base="$5"
    local mem="${6:-1g}"
    local cpus="${7:-1.0}"
    local gui="${WORKVM_SANDBOX_GUI:-0}"
    local meta_repo tmpl
    local db_slug api_db testing_db redis_prefix shared=0

    meta_repo="$(workvm_sandbox_meta_repo)"
    tmpl="${meta_repo}/olie/sandbox/compose.slim.yml"
    db_slug="$(workvm_sandbox_olie_db_slug "$id")"
    api_db="api_${db_slug}"
    testing_db="testing_${db_slug}"
    redis_prefix="${db_slug}_"

    workvm_sandbox_olie_ensure_sandbox_image || return 1

    mkdir -p "$compose_dir/artifacts" "$wt/e2e" "$wt/api-main"
    cp -f "$tmpl" "$compose_dir/compose.yaml"
    cp -f "${meta_repo}/olie/sandbox/compose.gui.yml" "$compose_dir/compose.gui.yml"

    if workvm_sandbox_olie_shared_data_enabled; then
        shared=1
        workvm_sandbox_olie_load_shared_data || return 1
        workvm_sandbox_log "shared data (hc-olie-data) para sandbox $id → $api_db / $testing_db"
        workvm_host_card_olie_ensure_shared_data || return 1
        workvm_host_card_olie_provision_card_databases "$db_slug" || return 1
        cp -f "${meta_repo}/olie/sandbox/compose.host-card-shared-data.yml" \
            "$compose_dir/compose.host-card-shared-data.yml"
    fi

    local api_port=$((port_base + 0))
    local pname
    pname="$(workvm_sandbox_container_project_name "$id")"
    local git_root api_vendor
    git_root="$(workvm_sandbox_git_root)"
    api_vendor="${git_root}/olie/api-main/vendor"
    if [ ! -f "${api_vendor}/autoload.php" ]; then
        workvm_sandbox_log "vendor ausente em ${api_vendor} (rode composer na host-card)"
        return 1
    fi

    {
        printf 'COMPOSE_PROJECT_NAME=%s\n' "$pname"
        printf 'SB_WORKTREE=%s\n' "$wt"
        printf 'SB_API_VENDOR=%s\n' "$api_vendor"
        if [ "$shared" = "1" ]; then
            # Placeholder: slim ainda interpola SB_MYSQL_INIT no serviço mysql
            # (profile unused); path vazio quebra o compose validate.
            printf 'SB_MYSQL_INIT=%s\n' "${meta_repo}/olie/sandbox/host-data-init"
            printf 'SB_DB_DATABASE=%s\n' "$api_db"
            printf 'SB_MONGO_DATABASE=%s\n' "$api_db"
            printf 'SB_REDIS_PREFIX=%s\n' "$redis_prefix"
            printf 'SB_TESTING_DATABASE=%s\n' "$testing_db"
        else
            printf 'SB_MYSQL_INIT=%s\n' "${meta_repo}/olie/sandbox/mysql-init"
        fi
        printf 'SB_MEM=%s\n' "$mem"
        printf 'SB_CPUS=%s\n' "$cpus"
        printf 'SB_PORT_API=%s\n' "$api_port"
        printf 'SB_PORT_FRONT=%s\n' "$((port_base + 1))"
        if [ "$shared" = "1" ]; then
            if [ "$gui" = "1" ] || [ "$gui" = "true" ]; then
                printf 'COMPOSE_FILE=compose.yaml:compose.gui.yml:compose.host-card-shared-data.yml\n'
            else
                printf 'COMPOSE_FILE=compose.yaml:compose.host-card-shared-data.yml\n'
            fi
        elif [ "$gui" = "1" ] || [ "$gui" = "true" ]; then
            printf 'COMPOSE_FILE=compose.yaml:compose.gui.yml\n'
        else
            printf 'COMPOSE_FILE=compose.yaml\n'
        fi
    } >"$compose_dir/.env"

    if declare -F workvm_sandbox_meta_set >/dev/null; then
        if [ "$shared" = "1" ]; then
            workvm_sandbox_meta_set "$id" shared_data hc-olie-data
            workvm_sandbox_meta_set "$id" db_slug "$db_slug"
            workvm_sandbox_meta_set "$id" db_database "$api_db"
            workvm_sandbox_meta_set "$id" testing_database "$testing_db"
        else
            workvm_sandbox_meta_set "$id" shared_data ""
        fi
    fi
}
