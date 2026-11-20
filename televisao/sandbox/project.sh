# Plugin Televisão para o Sandbox Manager.
# Problema: isolamento N× no mesmo Card sem copiar a VM; e2e sem host network.
# PostgreSQL/Redis: stack compartilhado hc-televisao-data (mesmo dos host-cards)
# com DB/prefixo por id. Opt-out: WORKVM_SANDBOX_SHARED_DATA=0.

workvm_sandbox_project_max() {
    printf '%s\n' "${WORKVM_SANDBOX_MAX:-2}"
}

workvm_sandbox_project_mem_limit() {
    local profile="$1"
    case "$profile" in
        e2e) printf '1536m\n' ;;
        *) printf '1g\n' ;;
    esac
}

workvm_sandbox_project_cpus() {
    local profile="$1"
    case "$profile" in
        e2e) printf '1.5\n' ;;
        *) printf '1.0\n' ;;
    esac
}

workvm_sandbox_project_repos() {
    # Paths relative to ~/git/televisao/
    printf '%s\n' televisao-api televisao-front televisao-meet-front televisao-meet-core
}

workvm_sandbox_televisao_db_slug() {
    local id="$1"
    local s
    s="$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]' | tr '-' '_' | tr -c 'a-z0-9_' '_' | sed 's/__*/_/g; s/^_//; s/_$//')"
    printf 'sb_%s\n' "$s"
}

workvm_sandbox_televisao_shared_data_enabled() {
    case "${WORKVM_SANDBOX_SHARED_DATA:-1}" in
        0|false|no|off) return 1 ;;
        *) return 0 ;;
    esac
}

workvm_sandbox_televisao_load_shared_data() {
    local meta_repo
    meta_repo="$(workvm_sandbox_meta_repo)"
    if declare -F workvm_host_card_televisao_ensure_shared_data >/dev/null; then
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
    source "${meta_repo}/televisao/sandbox/host-card-shared-data.sh"
}

workvm_sandbox_televisao_load_testing_db_cache() {
    local meta_repo
    meta_repo="$(workvm_sandbox_meta_repo)"
    if declare -F workvm_televisao_testing_db_cache_ensure_for_sandbox >/dev/null; then
        return 0
    fi
    # shellcheck source=/dev/null
    source "${meta_repo}/televisao/sandbox/testing-db-cache.sh"
}

# Após compose up: pg_dump cache → testing/api DBs + patch TestCase no worktree.
workvm_sandbox_project_after_up() {
    local id="$1"
    local wt="$2"
    local testing_db api_db

    workvm_sandbox_televisao_shared_data_enabled || return 0
    workvm_sandbox_televisao_load_testing_db_cache || return 0
    testing_db="$(workvm_sandbox_meta_get "$id" testing_database 2>/dev/null || true)"
    api_db="$(workvm_sandbox_meta_get "$id" db_database 2>/dev/null || true)"
    if [ -z "$testing_db" ]; then
        testing_db="db_$(workvm_sandbox_televisao_db_slug "$id")_test"
    fi
    if [ -z "$api_db" ]; then
        api_db="db_$(workvm_sandbox_televisao_db_slug "$id")"
    fi
    workvm_televisao_testing_db_cache_ensure_for_sandbox "$id" "$wt" "$testing_db" "$api_db" || true
}

workvm_sandbox_televisao_write_env() {
    local src_env="$1"
    local dest_env="$2"
    local api_db="${3:-db_televisao}"
    local redis_prefix="${4:-}"
    local testing_db="${5:-db_televisao_test}"
    local db_host=postgresql
    local redis_host=redis

    if workvm_sandbox_televisao_shared_data_enabled; then
        db_host=televisao-hc-pgsql
        redis_host=televisao-hc-redis
        [ -n "$redis_prefix" ] || redis_prefix="${api_db}_"
    fi

    if [ -f "$src_env" ]; then
        cp -f "$src_env" "$dest_env"
    else
        printf 'APP_KEY=base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\n' >"$dest_env"
    fi
    if [ -f "$dest_env" ]; then
        sed -i -E '/^[A-Z][A-Z0-9_]*=[[:space:]]*$/d' "$dest_env"
    fi
    local key val
    for key in \
        DB_CONNECTION=pgsql \
        "DB_HOST=${db_host}" \
        DB_PORT=5432 \
        "DB_DATABASE=${api_db}" \
        DB_USERNAME=root \
        DB_PASSWORD=password \
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
    # .env.testing no worktree (phpunit / pest)
    local dest_testing="${dest_env}.testing"
    if [ -f "${src_env}.testing" ]; then
        cp -f "${src_env}.testing" "$dest_testing"
    elif [ -f "$dest_env" ]; then
        cp -f "$dest_env" "$dest_testing"
    fi
    if [ -f "$dest_testing" ]; then
        for key in \
            DB_CONNECTION=pgsql \
            "DB_HOST=${db_host}" \
            DB_PORT=5432 \
            "DB_DATABASE=${testing_db}" \
            DB_USERNAME=root \
            DB_PASSWORD=password \
            "REDIS_HOST=${redis_host}" \
            "REDIS_PREFIX=${redis_prefix}"
        do
            val="${key#*=}"
            key="${key%%=*}"
            if grep -q "^${key}=" "$dest_testing" 2>/dev/null; then
                sed -i "s|^${key}=.*|${key}=${val}|" "$dest_testing"
            else
                printf '%s=%s\n' "$key" "$val" >>"$dest_testing"
            fi
        done
    fi
}

workvm_sandbox_project_prepare_worktrees() {
    local id="$1"
    local wt="$2"
    local from_commit="${3:-}"
    local git_root project_root repo src dest
    local db_slug api_db testing_db redis_prefix
    git_root="$(workvm_sandbox_git_root)"
    project_root="${git_root}/televisao"
    db_slug="$(workvm_sandbox_televisao_db_slug "$id")"
    api_db="db_${db_slug}"
    testing_db="db_${db_slug}_test"
    redis_prefix="${db_slug}_"

    mkdir -p "$wt/e2e"
    if [ ! -f "$wt/index.php" ]; then
        printf '<?php echo "sandbox %s\\n";\n' "$id" >"$wt/index.php"
    fi
    printf 'sandbox=%s\n' "$id" >"$wt/.sandbox-id"

    local exclude="${project_root}/.git/info/exclude"
    if [ -d "${project_root}/.git" ] || [ -f "${project_root}/.git" ]; then
        mkdir -p "$(dirname "$exclude")"
        touch "$exclude"
        if ! grep -qxF '/.sandboxes/' "$exclude" 2>/dev/null; then
            printf '/.sandboxes/\n' >>"$exclude"
        fi
    fi

    while IFS= read -r repo; do
        [ -n "$repo" ] || continue
        src="${project_root}/${repo}"
        dest="${wt}/${repo}"
        if [ -d "${src}/.git" ] || [ -f "${src}/.git" ]; then
            if [ -d "$dest" ]; then
                continue
            fi
            workvm_sandbox_log "worktree $repo → $dest"
            if [ -n "$from_commit" ] && git -C "$src" cat-file -e "${from_commit}^{commit}" 2>/dev/null; then
                git -C "$src" worktree add --detach "$dest" "$from_commit"
            elif [ -n "$from_commit" ]; then
                workvm_sandbox_log "from_commit $from_commit absent in $repo; using HEAD"
                git -C "$src" worktree add --detach "$dest" HEAD
            else
                git -C "$src" worktree add --detach "$dest" HEAD
            fi
            if [ "$repo" = "televisao-api" ]; then
                workvm_sandbox_televisao_write_env "${src}/.env" "${dest}/.env" \
                    "$api_db" "$redis_prefix" "$testing_db"
            fi
        else
            mkdir -p "$dest"
            printf '# clone %s ausente neste host; dir vazio no sandbox\n' "$repo" >"$dest/README.sandbox.md"
        fi
    done < <(workvm_sandbox_project_repos)
}

workvm_sandbox_project_remove_worktrees() {
    local id="$1"
    local wt="$2"
    local git_root project_root repo src dest db_slug
    git_root="$(workvm_sandbox_git_root)"
    project_root="${git_root}/televisao"

    if workvm_sandbox_televisao_shared_data_enabled; then
        db_slug="$(workvm_sandbox_televisao_db_slug "$id")"
        workvm_sandbox_televisao_load_shared_data || true
        if declare -F workvm_host_card_televisao_drop_card_databases >/dev/null; then
            workvm_sandbox_log "drop shared DBs for $db_slug"
            workvm_host_card_televisao_drop_card_databases "$db_slug" || true
        fi
    fi

    while IFS= read -r repo; do
        [ -n "$repo" ] || continue
        src="${project_root}/${repo}"
        dest="${wt}/${repo}"
        if [ -d "${src}/.git" ] || [ -f "${src}/.git" ]; then
            if [ -d "$dest" ]; then
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
    tmpl="${meta_repo}/televisao/sandbox/compose.slim.yml"
    db_slug="$(workvm_sandbox_televisao_db_slug "$id")"
    api_db="db_${db_slug}"
    testing_db="db_${db_slug}_test"
    redis_prefix="${db_slug}_"

    mkdir -p "$compose_dir/artifacts" "$wt/e2e"
    cp -f "$tmpl" "$compose_dir/compose.yaml"
    cp -f "${meta_repo}/televisao/sandbox/compose.gui.yml" "$compose_dir/compose.gui.yml"

    if workvm_sandbox_televisao_shared_data_enabled; then
        shared=1
        workvm_sandbox_televisao_load_shared_data || return 1
        workvm_sandbox_log "shared data (hc-televisao-data) para sandbox $id → $api_db"
        workvm_host_card_televisao_ensure_shared_data || return 1
        workvm_host_card_televisao_provision_card_databases "$db_slug" || return 1
        cp -f "${meta_repo}/televisao/sandbox/compose.sandbox-shared-data.yml" \
            "$compose_dir/compose.sandbox-shared-data.yml"
    fi

    local api_port=$((port_base + 0))
    local pname
    pname="$(workvm_sandbox_container_project_name "$id")"
    {
        printf 'COMPOSE_PROJECT_NAME=%s\n' "$pname"
        printf 'SB_WORKTREE=%s\n' "$wt"
        printf 'SB_MEM=%s\n' "$mem"
        printf 'SB_CPUS=%s\n' "$cpus"
        printf 'SB_PORT_API=%s\n' "$api_port"
        printf 'SB_PORT_FRONT=%s\n' "$((port_base + 1))"
        if [ "$shared" = "1" ]; then
            printf 'SB_DB_DATABASE=%s\n' "$api_db"
            printf 'SB_TESTING_DATABASE=%s\n' "$testing_db"
            printf 'SB_REDIS_PREFIX=%s\n' "$redis_prefix"
            if [ "$gui" = "1" ] || [ "$gui" = "true" ]; then
                printf 'COMPOSE_FILE=compose.yaml:compose.gui.yml:compose.sandbox-shared-data.yml\n'
            else
                printf 'COMPOSE_FILE=compose.yaml:compose.sandbox-shared-data.yml\n'
            fi
        elif [ "$gui" = "1" ] || [ "$gui" = "true" ]; then
            printf 'COMPOSE_FILE=compose.yaml:compose.gui.yml\n'
        else
            printf 'COMPOSE_FILE=compose.yaml\n'
        fi
    } >"$compose_dir/.env"

    if declare -F workvm_sandbox_meta_set >/dev/null; then
        if [ "$shared" = "1" ]; then
            workvm_sandbox_meta_set "$id" shared_data hc-televisao-data
            workvm_sandbox_meta_set "$id" db_slug "$db_slug"
            workvm_sandbox_meta_set "$id" db_database "$api_db"
            workvm_sandbox_meta_set "$id" testing_database "$testing_db"
        else
            workvm_sandbox_meta_set "$id" shared_data ""
        fi
    fi
}
