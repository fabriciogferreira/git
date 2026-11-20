# Shared PostgreSQL/Redis para sandboxes boilerplate-laravel.
# Problema: N× pgsql/redis estourava RAM; mutation no Card corrompia o DB
# do compose.dev. Uma stack hc-boilerplate-laravel-data; sandbox só muda DB/prefixo.
# Sourced por host-card-ensure/destroy e boilerplate-laravel/sandbox/project.sh.

workvm_host_card_bl_db_suffix() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr '-' '_' | tr -c 'a-z0-9_' '_' | sed 's/__*/_/g; s/^_//; s/_$//'
}

workvm_host_card_bl_shared_data_dir() {
    printf '%s/boilerplate-laravel/_shared-data\n' "$(workvm_host_card_root)"
}

workvm_host_card_bl_ensure_shared_data() {
    local meta_repo data_dir
    meta_repo="$(workvm_host_card_meta_repo)"
    data_dir="$(workvm_host_card_bl_shared_data_dir)"
    mkdir -p "$data_dir"

    cp -f "${meta_repo}/boilerplate-laravel/sandbox/compose.host-data.yml" "$data_dir/compose.yaml"
    {
        printf 'COMPOSE_PROJECT_NAME=hc-boilerplate-laravel-data\n'
        printf 'COMPOSE_FILE=compose.yaml\n'
    } >"$data_dir/.env"

    workvm_host_card_log "shared data up (hc-boilerplate-laravel-data → bl-hc-pgsql/redis)"
    (
        cd "$data_dir"
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
        export COMPOSE_PROJECT_NAME=hc-boilerplate-laravel-data
        docker compose up -d --remove-orphans
    ) || return 1

    local i
    for i in $(seq 1 60); do
        if docker exec bl-hc-pgsql pg_isready -q -d boilerplate -U root 2>/dev/null \
            && docker exec bl-hc-redis redis-cli ping 2>/dev/null | grep -q PONG; then
            return 0
        fi
        sleep 2
    done
    workvm_host_card_log "shared data não ficou healthy a tempo"
    return 1
}

workvm_host_card_bl_provision_card_databases() {
    local dns_slug="$1"
    local suffix api_db testing_db i sql

    suffix="$(workvm_host_card_bl_db_suffix "$dns_slug")"
    api_db="db_${suffix}"
    testing_db="db_${suffix}_test"

    workvm_host_card_log "provision PostgreSQL DBs ${api_db} / ${testing_db}(+_*)"
    sql="SELECT 1 FROM pg_database WHERE datname='${api_db}'"
    if ! docker exec bl-hc-pgsql psql -U root -d postgres -tAc "$sql" 2>/dev/null | grep -q 1; then
        docker exec bl-hc-pgsql psql -U root -d postgres -c "CREATE DATABASE \"${api_db}\";" || return 1
    fi
    sql="SELECT 1 FROM pg_database WHERE datname='${testing_db}'"
    if ! docker exec bl-hc-pgsql psql -U root -d postgres -tAc "$sql" 2>/dev/null | grep -q 1; then
        docker exec bl-hc-pgsql psql -U root -d postgres -c "CREATE DATABASE \"${testing_db}\";" || return 1
    fi
    for i in $(seq 1 16); do
        sql="SELECT 1 FROM pg_database WHERE datname='${testing_db}_${i}'"
        if ! docker exec bl-hc-pgsql psql -U root -d postgres -tAc "$sql" 2>/dev/null | grep -q 1; then
            docker exec bl-hc-pgsql psql -U root -d postgres -c "CREATE DATABASE \"${testing_db}_${i}\";" || return 1
        fi
    done
}

workvm_host_card_bl_drop_card_databases() {
    local dns_slug="$1"
    local suffix api_db testing_db i
    suffix="$(workvm_host_card_bl_db_suffix "$dns_slug")"
    api_db="db_${suffix}"
    testing_db="db_${suffix}_test"
    [ -n "$suffix" ] || return 0
    docker inspect bl-hc-pgsql --format '{{.State.Running}}' 2>/dev/null | grep -q true || return 0

    workvm_host_card_log "drop PostgreSQL DBs ${api_db} / ${testing_db}*"
    _bl_drop_db() {
        local name="$1"
        docker exec bl-hc-pgsql psql -U root -d postgres -v ON_ERROR_STOP=1 -c \
            "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${name}' AND pid <> pg_backend_pid();" \
            >/dev/null 2>&1 || true
        docker exec bl-hc-pgsql psql -U root -d postgres -c "DROP DATABASE IF EXISTS \"${name}\";" 2>/dev/null || true
    }
    _bl_drop_db "$api_db"
    _bl_drop_db "$testing_db"
    for i in $(seq 1 16); do
        _bl_drop_db "${testing_db}_${i}"
    done
}
