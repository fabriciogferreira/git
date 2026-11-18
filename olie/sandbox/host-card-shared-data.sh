# Shared MySQL/Redis/Mongo para host-cards Olie.
# Problema: N cards × instâncias de data estourava RAM no jarvis.
# Uma stack hc-olie-data (imagens ≈ docker-workspace); card só muda DB/prefixo.
# Sourced por host-card-ensure.sh / host-card-destroy.sh.

workvm_host_card_olie_db_suffix() {
    printf '%s' "$1" | tr '-' '_'
}

workvm_host_card_olie_shared_data_dir() {
    printf '%s/olie/_shared-data\n' "$(workvm_host_card_root)"
}

# Sobe (ou retoma) olie-hc-mysql / redis / mongo. Idempotente.
workvm_host_card_olie_ensure_shared_data() {
    local meta_repo data_dir
    meta_repo="$(workvm_host_card_meta_repo)"
    data_dir="$(workvm_host_card_olie_shared_data_dir)"
    mkdir -p "$data_dir"

    cp -f "${meta_repo}/olie/sandbox/compose.host-data.yml" "$data_dir/compose.yaml"
    {
        printf 'COMPOSE_PROJECT_NAME=hc-olie-data\n'
        printf 'SB_HOST_DATA_INIT=%s\n' "${meta_repo}/olie/sandbox/host-data-init"
        printf 'SB_HOST_DATA_REDIS_CONF=%s\n' "${meta_repo}/olie/sandbox/redis/redis-stack.conf"
        printf 'COMPOSE_FILE=compose.yaml\n'
    } >"$data_dir/.env"

    workvm_host_card_log "shared data up (hc-olie-data → olie-hc-mysql/redis/mongo)"
    (
        cd "$data_dir"
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
        export COMPOSE_PROJECT_NAME=hc-olie-data
        docker compose up -d --remove-orphans
    ) || return 1

    local i
    for i in $(seq 1 60); do
        if docker exec olie-hc-mysql mysqladmin ping -h 127.0.0.1 -psandbox --silent 2>/dev/null \
            && docker exec olie-hc-redis redis-cli ping 2>/dev/null | grep -q PONG \
            && docker exec olie-hc-mongo mongosh --quiet -u sandbox -p sandbox --authenticationDatabase admin \
                --eval 'db.adminCommand("ping").ok' 2>/dev/null | grep -q 1; then
            return 0
        fi
        sleep 2
    done
    workvm_host_card_log "shared data não ficou healthy a tempo"
    return 1
}

# Cria api_<suffix> + testing_<suffix> (+ testing_<suffix>_test_1..32) no MySQL shared.
workvm_host_card_olie_provision_card_databases() {
    local dns_slug="$1"
    local suffix api_db testing_db i sql

    suffix="$(workvm_host_card_olie_db_suffix "$dns_slug")"
    api_db="api_${suffix}"
    testing_db="testing_${suffix}"

    workvm_host_card_log "provision MySQL DBs ${api_db} / ${testing_db}(+_test_*)"
    sql="CREATE DATABASE IF NOT EXISTS \`${api_db}\`;"
    sql+="CREATE DATABASE IF NOT EXISTS \`${testing_db}\`;"
    sql+="GRANT ALL PRIVILEGES ON \`${api_db}\`.* TO 'sandbox'@'%';"
    sql+="GRANT ALL PRIVILEGES ON \`${testing_db}%\`.* TO 'sandbox'@'%';"
    for i in $(seq 1 32); do
        sql+="CREATE DATABASE IF NOT EXISTS \`${testing_db}_test_${i}\`;"
    done
    sql+="FLUSH PRIVILEGES;"
    docker exec -i olie-hc-mysql mysql -uroot -psandbox -e "$sql" || return 1

    docker exec olie-hc-mongo mongosh --quiet -u sandbox -p sandbox --authenticationDatabase admin \
        --eval "db.getSiblingDB('${api_db}').stats()" >/dev/null 2>&1 || true
}

workvm_host_card_olie_drop_card_databases() {
    local dns_slug="$1"
    local suffix api_db testing_db i sql

    suffix="$(workvm_host_card_olie_db_suffix "$dns_slug")"
    api_db="api_${suffix}"
    testing_db="testing_${suffix}"
    [ -n "$suffix" ] || return 0
    docker inspect olie-hc-mysql --format '{{.State.Running}}' 2>/dev/null | grep -q true || return 0

    workvm_host_card_log "drop MySQL DBs ${api_db} / ${testing_db}*"
    sql="DROP DATABASE IF EXISTS \`${api_db}\`; DROP DATABASE IF EXISTS \`${testing_db}\`;"
    for i in $(seq 1 32); do
        sql+="DROP DATABASE IF EXISTS \`${testing_db}_test_${i}\`;"
    done
    docker exec -i olie-hc-mysql mysql -uroot -psandbox -e "$sql" 2>/dev/null || true
    docker exec olie-hc-mongo mongosh --quiet -u sandbox -p sandbox --authenticationDatabase admin \
        --eval "db.getSiblingDB('${api_db}').dropDatabase()" >/dev/null 2>&1 || true
}
