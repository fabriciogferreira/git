# Shared PostgreSQL/Redis para host-cards e sandboxes Locav.
# Problema: N× pgsql/redis estourava RAM no jarvis.
# Uma stack hc-locav-data; card/sandbox só muda DB/prefixo.
# Sourced por host-card-ensure/destroy e locav/sandbox/project.sh.

workvm_host_card_locav_db_suffix() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr '-' '_' | tr -c 'a-z0-9_' '_' | sed 's/__*/_/g; s/^_//; s/_$//'
}

workvm_host_card_locav_shared_data_dir() {
    printf '%s/locav/_shared-data\n' "$(workvm_host_card_root)"
}

workvm_host_card_locav_ensure_shared_data() {
    local meta_repo data_dir
    meta_repo="$(workvm_host_card_meta_repo)"
    data_dir="$(workvm_host_card_locav_shared_data_dir)"
    mkdir -p "$data_dir"

    cp -f "${meta_repo}/locav/sandbox/compose.host-data.yml" "$data_dir/compose.yaml"
    {
        printf 'COMPOSE_PROJECT_NAME=hc-locav-data\n'
        printf 'COMPOSE_FILE=compose.yaml\n'
    } >"$data_dir/.env"

    workvm_host_card_log "shared data up (hc-locav-data → locav-hc-pgsql/redis)"
    (
        cd "$data_dir"
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
        export COMPOSE_PROJECT_NAME=hc-locav-data
        docker compose up -d --remove-orphans
    ) || return 1

    local i
    for i in $(seq 1 60); do
        if docker exec locav-hc-pgsql pg_isready -q -d locav -U root 2>/dev/null \
            && docker exec locav-hc-redis redis-cli ping 2>/dev/null | grep -q PONG; then
            return 0
        fi
        sleep 2
    done
    workvm_host_card_log "shared data não ficou healthy a tempo"
    return 1
}

workvm_host_card_locav_provision_card_databases() {
    local dns_slug="$1"
    local suffix api_db testing_db i sql

    suffix="$(workvm_host_card_locav_db_suffix "$dns_slug")"
    api_db="db_${suffix}"
    testing_db="db_${suffix}_test"

    workvm_host_card_log "provision PostgreSQL DBs ${api_db} / ${testing_db}(+_*)"
    sql="SELECT 1 FROM pg_database WHERE datname='${api_db}'"
    if ! docker exec locav-hc-pgsql psql -U root -d postgres -tAc "$sql" 2>/dev/null | grep -q 1; then
        docker exec locav-hc-pgsql psql -U root -d postgres -c "CREATE DATABASE \"${api_db}\";" || return 1
    fi
    sql="SELECT 1 FROM pg_database WHERE datname='${testing_db}'"
    if ! docker exec locav-hc-pgsql psql -U root -d postgres -tAc "$sql" 2>/dev/null | grep -q 1; then
        docker exec locav-hc-pgsql psql -U root -d postgres -c "CREATE DATABASE \"${testing_db}\";" || return 1
    fi
    for i in $(seq 1 16); do
        sql="SELECT 1 FROM pg_database WHERE datname='${testing_db}_${i}'"
        if ! docker exec locav-hc-pgsql psql -U root -d postgres -tAc "$sql" 2>/dev/null | grep -q 1; then
            docker exec locav-hc-pgsql psql -U root -d postgres -c "CREATE DATABASE \"${testing_db}_${i}\";" || return 1
        fi
    done
}

workvm_host_card_locav_drop_card_databases() {
    local dns_slug="$1"
    local suffix api_db testing_db i
    suffix="$(workvm_host_card_locav_db_suffix "$dns_slug")"
    api_db="db_${suffix}"
    testing_db="db_${suffix}_test"
    [ -n "$suffix" ] || return 0
    docker inspect locav-hc-pgsql --format '{{.State.Running}}' 2>/dev/null | grep -q true || return 0

    workvm_host_card_log "drop PostgreSQL DBs ${api_db} / ${testing_db}*"
    _locav_drop_db() {
        local name="$1"
        docker exec locav-hc-pgsql psql -U root -d postgres -v ON_ERROR_STOP=1 -c \
            "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${name}' AND pid <> pg_backend_pid();" \
            >/dev/null 2>&1 || true
        docker exec locav-hc-pgsql psql -U root -d postgres -c "DROP DATABASE IF EXISTS \"${name}\";" 2>/dev/null || true
    }
    _locav_drop_db "$api_db"
    _locav_drop_db "$testing_db"
    for i in $(seq 1 16); do
        _locav_drop_db "${testing_db}_${i}"
    done
}
