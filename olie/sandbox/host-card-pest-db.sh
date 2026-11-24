# Warm-up dos DBs de Pest no host-card Olie (shared olie-hc-mysql).
# Problema: workvm-host-card-pest com --recreate-databases + rm dos
# migration-checksum_*.txt forçava migrate:fresh × N workers a cada gate
# (~20 min no jarvis). FastRefresh só fica rápido quando o schema já existe
# e o checksum em storage/app bate. Este helper carimba checksums (e importa
# dump do testing-db-cache se o DB estiver vazio) sem dropar os DBs.
# Sourced por bin/workvm-host-card-pest.

workvm_olie_host_card_pest_db_slug() {
    local db="$1"
    printf '%s' "$db" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

workvm_olie_host_card_pest_db_table_count() {
    local db="$1"
    docker exec olie-hc-mysql mysql -uroot -psandbox -N -e \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db}'" 2>/dev/null || echo 0
}

# Schema sozinho não basta: migrate abortado / dump incompleto deixa tables
# sem TestingDatabaseSeeder útil. Exige tester + frame DEVELOPMENT_FRAME
# (senão getTestFrame() → null e milhares de ErrorException).
workvm_olie_host_card_pest_db_seed_ok() {
    local db="$1"
    local frame="${2:-devframe}"
    local n
    n="$(docker exec olie-hc-mysql mysql -uroot -psandbox -N -e \
        "SELECT COUNT(*) FROM \`${db}\`.users u
         JOIN \`${db}\`.frames f ON f.subdomain='${frame}'
         WHERE u.email='tester@olie.ai'" 2>/dev/null || echo 0)"
    [ "${n:-0}" -ge 1 ] 2>/dev/null
}

workvm_olie_host_card_pest_db_reset_empty() {
    local db="$1"
    docker exec olie-hc-mysql mysql -uroot -psandbox -e \
        "DROP DATABASE IF EXISTS \`${db}\`; CREATE DATABASE \`${db}\`; GRANT ALL PRIVILEGES ON \`${db}\`.* TO 'sandbox'@'%';" \
        2>/dev/null || return 1
}

# Clona schema+seed de um DB já saudável (mais confiável que o dump gzip do
# testing-db-cache, que pode estar incompleto / desatualizado no jarvis).
workvm_olie_host_card_pest_db_clone_from() {
    local src="$1"
    local dst="$2"
    workvm_olie_host_card_pest_db_reset_empty "$dst" || return 1
    docker exec olie-hc-mysql mysqldump -uroot -psandbox \
        --single-transaction --routines --triggers --no-tablespaces \
        "$src" | docker exec -i olie-hc-mysql mysql -uroot -psandbox "$dst" || return 1
}

# Checksum que o FastRefresh calcula AGORA neste worktree (mtimes no container).
workvm_olie_host_card_pest_fastrefresh_checksum() {
    local compose_dir="$1"
    local pname="$2"
    local api_main="$3"
    local script out
    script="${api_main}/storage/app/_workvm_migration_checksum.php"
    mkdir -p "${api_main}/storage/app"
    cat >"$script" <<'PHP'
<?php
require __DIR__ . '/../../vendor/autoload.php';
$app = require __DIR__ . '/../../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$finder = Symfony\Component\Finder\Finder::create()
    ->in(database_path('migrations'))
    ->name('*.php')
    ->ignoreDotFiles(true)
    ->ignoreVCS(true)
    ->files();
$migrations = array_map(static function ($fileInfo) {
    return [$fileInfo->getMTime(), $fileInfo->getPath()];
}, iterator_to_array($finder));
$migrations = array_values($migrations);
$checkBranch = new Symfony\Component\Process\Process(['git', 'branch', '--show-current']);
$checkBranch->run();
$migrations['gitBranch'] = trim($checkBranch->getOutput());
echo hash('sha256', json_encode($migrations, JSON_THROW_ON_ERROR));
PHP
    out="$(
        cd "$compose_dir" || exit 1
        set -a
        # shellcheck disable=SC1091
        [ -f .env ] && source .env
        set +a
        export COMPOSE_PROJECT_NAME="$pname"
        docker compose --profile slim exec -T app \
            php storage/app/_workvm_migration_checksum.php 2>/dev/null | tr -d '\r' | tail -n1
    )" || out=""
    rm -f "$script"
    case "$out" in
        [a-f0-9][a-f0-9][a-f0-9][a-f0-9]*) printf '%s\n' "$out" ;;
        *) return 1 ;;
    esac
}

workvm_olie_host_card_pest_stamp() {
    local api_main="$1"
    local db="$2"
    local checksum="$3"
    local slug file
    slug="$(workvm_olie_host_card_pest_db_slug "$db")"
    mkdir -p "${api_main}/storage/app"
    file="${api_main}/storage/app/migration-checksum_${slug}.txt"
    printf '%s' "$checksum" >"$file"
}

# Drop worker DBs além de --processes (restos de nproc maior / runs abortados).
workvm_olie_host_card_pest_prune_orphan_workers() {
    local testing_db="$1"
    local procs="$2"
    local dbs i name
    dbs="$(docker exec olie-hc-mysql mysql -uroot -psandbox -N -e \
        "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME LIKE '${testing_db}_test_%'" 2>/dev/null || true)"
    [ -n "$dbs" ] || return 0
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        i="${name##*_test_}"
        case "$i" in
            ''|*[!0-9]*) continue ;;
        esac
        if [ "$i" -gt "$procs" ]; then
            workvm_host_card_log "pest-db: drop orphan ${name}"
            docker exec olie-hc-mysql mysql -uroot -psandbox -e \
                "DROP DATABASE IF EXISTS \`${name}\`;" 2>/dev/null || true
        fi
    done <<<"$dbs"
}

# Garante testing_<slug> + testing_<slug>_test_1..procs com schema+seed e checksum.
# Preferência: clonar do próprio testing_<slug> se ele estiver saudável (seed ok).
# Fallback: testing-db-cache dump. Sem fonte → não carimba (Pest migra a frio).
workvm_olie_host_card_pest_warm() {
    local compose_dir="$1"
    local pname="$2"
    local testing_db="$3"
    local procs="$4"
    local api_main="$5"
    local fr_sum dump_gz cache_key db
    local cache_sh base_ok=0

    docker inspect olie-hc-mysql --format '{{.State.Running}}' 2>/dev/null | grep -q true || return 0
    [ -d "${api_main}/database/migrations" ] || return 0

    workvm_olie_host_card_pest_prune_orphan_workers "$testing_db" "$procs"

    cache_sh="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/testing-db-cache.sh"
    # shellcheck source=olie/sandbox/testing-db-cache.sh
    source "$cache_sh"

    dump_gz=""
    if workvm_olie_testing_db_cache_enabled; then
        cache_key="$(workvm_olie_testing_db_cache_key "$api_main" 2>/dev/null || true)"
        if [ -n "${cache_key:-}" ]; then
            dump_gz="$(workvm_olie_testing_db_cache_dir)/${cache_key}.sql.gz"
            [ -f "$dump_gz" ] || dump_gz=""
        fi
    fi

    fr_sum="$(workvm_olie_host_card_pest_fastrefresh_checksum "$compose_dir" "$pname" "$api_main")" || {
        workvm_host_card_log "pest-db: FastRefresh checksum falhou; Pest pode migrar a frio"
        return 0
    }

    if workvm_olie_host_card_pest_db_seed_ok "$testing_db"; then
        base_ok=1
    elif [ -n "$dump_gz" ]; then
        workvm_host_card_log "pest-db: reset+import cache → ${testing_db}"
        workvm_olie_host_card_pest_db_reset_empty "$testing_db" || true
        gunzip -c "$dump_gz" | docker exec -i olie-hc-mysql mysql -uroot -psandbox "$testing_db" || true
        workvm_olie_host_card_pest_db_seed_ok "$testing_db" && base_ok=1
    fi

    if [ "$base_ok" -ne 1 ]; then
        workvm_host_card_log "pest-db: base ${testing_db} sem seed; skip stamp (Pest migra a frio)"
        return 0
    fi

    workvm_olie_host_card_pest_stamp "$api_main" "$testing_db" "$fr_sum"

    local need_clone=()
    for db in $(seq -f "${testing_db}_test_%g" 1 "$procs"); do
        if workvm_olie_host_card_pest_db_seed_ok "$db"; then
            workvm_olie_host_card_pest_stamp "$api_main" "$db" "$fr_sum"
        else
            need_clone+=("$db")
        fi
    done

    if [ ${#need_clone[@]} -gt 0 ]; then
        local dump_sql
        dump_sql="$(mktemp "${TMPDIR:-/tmp}/olie-pest-db.XXXXXX.sql")"
        workvm_host_card_log "pest-db: dump ${testing_db} → ${#need_clone[@]} workers"
        if ! docker exec olie-hc-mysql mysqldump -uroot -psandbox \
            --single-transaction --routines --triggers --no-tablespaces \
            "$testing_db" >"$dump_sql"; then
            rm -f "$dump_sql"
            workvm_host_card_log "pest-db: dump falhou; skip clone"
            return 0
        fi
        local db pids=()
        for db in "${need_clone[@]}"; do
            (
                workvm_olie_host_card_pest_db_reset_empty "$db" || exit 1
                docker exec -i olie-hc-mysql mysql -uroot -psandbox "$db" <"$dump_sql" || exit 1
                workvm_olie_host_card_pest_stamp "$api_main" "$db" "$fr_sum"
            ) &
            pids+=("$!")
            # Evita saturar o MySQL shared (22 dumps simultâneos).
            if [ ${#pids[@]} -ge 4 ]; then
                wait "${pids[0]}" || true
                pids=("${pids[@]:1}")
            fi
        done
        for pid in "${pids[@]+"${pids[@]}"}"; do
            wait "$pid" || workvm_host_card_log "pest-db: clone worker falhou (pid $pid)"
        done
        rm -f "$dump_sql"
    fi
    workvm_host_card_log "pest-db: warmed ${testing_db} + ${procs} workers (no recreate)"
}
