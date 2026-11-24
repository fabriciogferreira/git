# Cache do schema+DatabaseSeeder dos host-cards Olie (api_<slug>).
# Problema: cold open gasta ~390s em migrate --seed; dump+import ~80s no
# mesmo tip (bench DOP-1137). Grava mysqldump gzip no host; no ensure, se o
# banco do card está vazio e a chave bate, importa em vez de re-seedar.
#
# Fluxo (cada ensure / open de card):
#   1. MySQL up; conta tabelas em api_<slug> + meta db_seeded.
#   2. Já seedado (flag + tabelas) → só artisan migrate --force. Sem hash/dump.
#   3. Banco vazio → calcula chave (hash on-disk migrations+seeders+factories
#      do worktree deste card) → se existir <key>.sql.gz importa (~80s) +
#      migrate --force; senão migrate --seed (~390s) e grava o dump.
#   Mudou migration/seeder/factory no disco → chave nova → miss automático.
#   Mesmo tip em N cards → mesmo arquivo de dump (hit).
#
# Regenerar dump: ver HISTORICO "BusinessAreaFactory: unique Faker…" —
# corrigir a factory no api-main *antes* do miss, senão o dump fica parcial.
#
# Chave = hash on-disk (dirty-aware). Opt-out: WORKVM_OLIE_CARD_DB_CACHE=0
# Sourced por olie/sandbox/host-card-ensure.sh.

workvm_olie_card_db_cache_enabled() {
    case "${WORKVM_OLIE_CARD_DB_CACHE:-1}" in
        0|false|no|off) return 1 ;;
        *) return 0 ;;
    esac
}

workvm_olie_card_db_cache_dir() {
    printf '%s/workvm/cache/olie-card-db\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

# Hash estável do conteúdo que define o dump do card (DatabaseSeeder + schema).
# On-disk (não só tip Git): worktree dirty de seeder/factory invalida o cache.
workvm_olie_card_db_cache_key() {
    local api_main="$1"
    local key
    [ -d "${api_main}/database/migrations" ] || return 1
    [ -d "${api_main}/database/seeders" ] || return 1
    key="$(
        {
            find "${api_main}/database/migrations" \
                "${api_main}/database/seeders" \
                "${api_main}/database/factories" \
                -type f -name '*.php' -print0 2>/dev/null \
                | sort -z \
                | xargs -0 sha256sum 2>/dev/null
        } | sha256sum | awk '{print $1}'
    )" || return 1
    case "$key" in
        [a-f0-9][a-f0-9][a-f0-9][a-f0-9]*) printf '%s\n' "$key" ;;
        *) return 1 ;;
    esac
}

workvm_olie_card_db_cache_dump_path() {
    local cache_key="$1"
    printf '%s/%s.sql.gz\n' "$(workvm_olie_card_db_cache_dir)" "$cache_key"
}

# Importa dump num DB vazio. Skip se já tem tabelas.
workvm_olie_card_db_cache_apply() {
    local db_name="$1"
    local dump_gz="$2"
    local tables
    [ -f "$dump_gz" ] || return 1
    tables="$(docker exec olie-hc-mysql mysql -uroot -psandbox -N -e \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db_name}'" 2>/dev/null || echo 0)"
    if [ "${tables:-0}" -gt 0 ] 2>/dev/null; then
        workvm_host_card_log "card-db-cache: ${db_name} já tem tabelas (${tables}); skip import"
        return 0
    fi
    workvm_host_card_log "card-db-cache: import → ${db_name}"
    gunzip -c "$dump_gz" | docker exec -i olie-hc-mysql mysql -uroot -psandbox "$db_name" || return 1
}

# Grava dump do DB já seedado (miss → seed → store). Soft-fail no caller.
workvm_olie_card_db_cache_store() {
    local db_name="$1"
    local cache_key="$2"
    local dump_gz sum_path cache_dir
    cache_dir="$(workvm_olie_card_db_cache_dir)"
    mkdir -p "$cache_dir"
    dump_gz="$(workvm_olie_card_db_cache_dump_path "$cache_key")"
    sum_path="${dump_gz%.sql.gz}.key"

    if [ -f "$dump_gz" ]; then
        workvm_host_card_log "card-db-cache: dump já existe $(basename "$dump_gz")"
        return 0
    fi

    workvm_host_card_log "card-db-cache: store ← ${db_name}"
    docker exec olie-hc-mysql mysqldump -uroot -psandbox \
        --single-transaction --routines --triggers --no-tablespaces \
        "$db_name" | gzip -c >"${dump_gz}.tmp" || {
        rm -f "${dump_gz}.tmp"
        return 1
    }
    mv -f "${dump_gz}.tmp" "$dump_gz"
    printf '%s' "$cache_key" >"$sum_path"
    workvm_host_card_log "card-db-cache: wrote $(basename "$dump_gz") ($(stat -c%s "$dump_gz" 2>/dev/null || echo ?) bytes)"
}

# Hit: import e return 0. Miss/disabled/erro: return 1 (caller faz migrate --seed).
workvm_olie_card_db_cache_try_import() {
    local api_main="$1"
    local db_name="$2"
    local cache_key dump_gz

    workvm_olie_card_db_cache_enabled || return 1
    [ -d "${api_main}/database/migrations" ] || return 1
    docker inspect olie-hc-mysql --format '{{.State.Running}}' 2>/dev/null | grep -q true || return 1

    cache_key="$(workvm_olie_card_db_cache_key "$api_main")" || {
        workvm_host_card_log "card-db-cache: chave falhou; migrate --seed"
        return 1
    }
    dump_gz="$(workvm_olie_card_db_cache_dump_path "$cache_key")"
    if [ ! -f "$dump_gz" ]; then
        workvm_host_card_log "card-db-cache: miss $(printf '%.12s' "$cache_key")…"
        return 1
    fi

    workvm_host_card_log "card-db-cache: hit $(basename "$dump_gz")"
    workvm_olie_card_db_cache_apply "$db_name" "$dump_gz" || {
        workvm_host_card_log "card-db-cache: import falhou; migrate --seed"
        return 1
    }
    return 0
}
