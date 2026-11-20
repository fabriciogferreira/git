# Cache do schema+seed de teste Olie (testing_sb_*), estilo vendor.
# Problema: o 1º Pest num sandbox frio gasta ~70s+ em migrate:fresh +
# TestingDatabaseSeeder no MySQL shared. FastRefresh só pula migrate quando
# o DB já tem schema e o checksum em storage/app bate. Este cache grava um
# mysqldump no host e, no create, importa + carimba o checksum.
# Opt-out: WORKVM_OLIE_TESTING_DB_CACHE=0
# Sourced por olie/sandbox/project.sh (after_up).

workvm_olie_testing_db_cache_enabled() {
    case "${WORKVM_OLIE_TESTING_DB_CACHE:-1}" in
        0|false|no|off) return 1 ;;
        *) return 0 ;;
    esac
}

workvm_olie_testing_db_cache_dir() {
    printf '%s/workvm/cache/olie-testing-db\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

# Chave estável: tree de migrations + blobs do TestingDatabaseSeeder e dos
# seeders que ele chama. Mesmo tip em N cards = hit; nova migration ou
# mudança nesses seeders = miss → rebuild. Não usar mtime (worktree muda).
workvm_olie_testing_db_cache_key() {
    local api_main="$1"
    local mig key
    mig="$(git -C "$api_main" rev-parse HEAD:database/migrations 2>/dev/null)" || return 1
    key="$(
        {
            printf 'migrations:%s\n' "$mig"
            # Closure de TestingDatabaseSeeder::run() (manter alinhado ao PHP).
            for _tdc_seeder in \
                TestingDatabaseSeeder \
                UserSeeder \
                FrameSeeder \
                FrameDataSeeder \
                PermissionsSeeder \
                SystemSeeder \
                ProductSeeder
            do
                printf 'seeder:%s:%s\n' "$_tdc_seeder" \
                    "$(git -C "$api_main" rev-parse "HEAD:database/seeders/${_tdc_seeder}.php" 2>/dev/null || echo missing)"
            done
        } | sha256sum | awk '{print $1}'
    )" || return 1
    case "$key" in
        [a-f0-9][a-f0-9][a-f0-9][a-f0-9]*) printf '%s\n' "$key" ;;
        *) return 1 ;;
    esac
}

# Checksum que o FastRefresh vai calcular neste worktree (mtime + path no container).
# Só para carimbar storage/app após o import — não é a chave do dump.
workvm_olie_testing_db_cache_fastrefresh_checksum() {
    local sandbox_id="$1"
    local api_main="$2"
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
    out="$(workvm_sandbox_container_compose "$sandbox_id" exec -T app \
        php storage/app/_workvm_migration_checksum.php 2>/dev/null | tr -d '\r' | tail -n1)" || return 1
    rm -f "$script"
    case "$out" in
        [a-f0-9][a-f0-9][a-f0-9][a-f0-9]*) printf '%s\n' "$out" ;;
        *) return 1 ;;
    esac
}

# Laravel Str::slug do nome do DB → nome do arquivo migration-checksum_*.txt
workvm_olie_testing_db_cache_db_slug() {
    local db="$1"
    printf '%s' "$db" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

workvm_olie_testing_db_cache_stamp() {
    local api_main="$1"
    local testing_db="$2"
    local checksum="$3"
    local slug file
    slug="$(workvm_olie_testing_db_cache_db_slug "$testing_db")"
    mkdir -p "${api_main}/storage/app"
    file="${api_main}/storage/app/migration-checksum_${slug}.txt"
    printf '%s' "$checksum" >"$file"
}

workvm_olie_testing_db_cache_apply() {
    local testing_db="$1"
    local dump_gz="$2"
    local tables
    tables="$(docker exec olie-hc-mysql mysql -uroot -psandbox -N -e \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${testing_db}'" 2>/dev/null || echo 0)"
    if [ "${tables:-0}" -gt 0 ] 2>/dev/null; then
        workvm_sandbox_log "testing-db-cache: ${testing_db} já tem tabelas (${tables}); skip import"
        return 0
    fi
    workvm_sandbox_log "testing-db-cache: import → ${testing_db}"
    gunzip -c "$dump_gz" | docker exec -i olie-hc-mysql mysql -uroot -psandbox "$testing_db" || return 1
}

# migrate:fresh + TestingDatabaseSeeder num DB scratch → mysqldump gzip no cache.
workvm_olie_testing_db_cache_build() {
    local sandbox_id="$1"
    local cache_key="$2"
    local dump_gz="$3"
    local scratch sum_path
    scratch="olie_tdcache_$(printf '%s' "$cache_key" | cut -c1-16)"
    sum_path="${dump_gz%.sql.gz}.key"

    workvm_sandbox_log "testing-db-cache: build miss → scratch ${scratch}"
    docker exec olie-hc-mysql mysql -uroot -psandbox -e \
        "DROP DATABASE IF EXISTS \`${scratch}\`; CREATE DATABASE \`${scratch}\`; GRANT ALL PRIVILEGES ON \`${scratch}\`.* TO 'sandbox'@'%'; FLUSH PRIVILEGES;" \
        || return 1

    if ! workvm_sandbox_container_compose "$sandbox_id" exec -T \
        -e "DB_DATABASE=${scratch}" \
        app php artisan migrate:fresh --force --no-interaction \
        --seeder=Database\\Seeders\\TestingDatabaseSeeder --seed
    then
        docker exec olie-hc-mysql mysql -uroot -psandbox -e "DROP DATABASE IF EXISTS \`${scratch}\`;" 2>/dev/null || true
        return 1
    fi

    mkdir -p "$(dirname "$dump_gz")"
    docker exec olie-hc-mysql mysqldump -uroot -psandbox \
        --single-transaction --routines --triggers --no-tablespaces \
        "$scratch" | gzip -c >"${dump_gz}.tmp" || {
        rm -f "${dump_gz}.tmp"
        docker exec olie-hc-mysql mysql -uroot -psandbox -e "DROP DATABASE IF EXISTS \`${scratch}\`;" 2>/dev/null || true
        return 1
    }
    mv -f "${dump_gz}.tmp" "$dump_gz"
    printf '%s' "$cache_key" >"$sum_path"
    docker exec olie-hc-mysql mysql -uroot -psandbox -e "DROP DATABASE IF EXISTS \`${scratch}\`;" 2>/dev/null || true
    workvm_sandbox_log "testing-db-cache: wrote $(basename "$dump_gz")"
}

# Hit: import+stamp. Miss: build+import+stamp. Soft-fail → Pest frio.
# Importa em testing_sb_* e api_sb_*: o compose injeta DB_DATABASE=api_sb_*
# e o Pest/FastRefresh ainda migra api_sb no 1º run (~90s) mesmo com
# phpunit force=true em alguns boots — carimbar os dois evita o frio.
workvm_olie_testing_db_cache_ensure_for_sandbox() {
    local sandbox_id="$1"
    local wt="$2"
    local testing_db="$3"
    local api_db="${4:-}"
    local api_main cache_key fr_sum cache_dir dump_gz

    workvm_olie_testing_db_cache_enabled || return 0
    workvm_sandbox_olie_shared_data_enabled || return 0

    api_main="${wt}/api-main"
    [ -d "${api_main}/database/migrations" ] || return 0
    docker inspect olie-hc-mysql --format '{{.State.Running}}' 2>/dev/null | grep -q true || return 0

    cache_key="$(workvm_olie_testing_db_cache_key "$api_main")" || {
        workvm_sandbox_log "testing-db-cache: cache key falhou; Pest frio"
        return 0
    }

    cache_dir="$(workvm_olie_testing_db_cache_dir)"
    mkdir -p "$cache_dir"
    dump_gz="${cache_dir}/${cache_key}.sql.gz"

    if [ ! -f "$dump_gz" ]; then
        workvm_olie_testing_db_cache_build "$sandbox_id" "$cache_key" "$dump_gz" || {
            workvm_sandbox_log "testing-db-cache: build falhou; Pest frio"
            return 0
        }
    else
        workvm_sandbox_log "testing-db-cache: hit $(basename "$dump_gz")"
    fi

    workvm_olie_testing_db_cache_apply "$testing_db" "$dump_gz" || {
        workvm_sandbox_log "testing-db-cache: apply testing falhou; Pest frio"
        return 0
    }
    if [ -n "$api_db" ]; then
        workvm_olie_testing_db_cache_apply "$api_db" "$dump_gz" || {
            workvm_sandbox_log "testing-db-cache: apply api falhou (seguindo)"
        }
    fi

    # Carimbo = o que o FastRefresh calcula AGORA neste worktree (mtimes locais).
    fr_sum="$(workvm_olie_testing_db_cache_fastrefresh_checksum "$sandbox_id" "$api_main")" || {
        workvm_sandbox_log "testing-db-cache: FastRefresh checksum falhou após import; Pest pode migrar"
        return 0
    }
    workvm_olie_testing_db_cache_stamp "$api_main" "$testing_db" "$fr_sum"
    if [ -n "$api_db" ]; then
        workvm_olie_testing_db_cache_stamp "$api_main" "$api_db" "$fr_sum"
    fi
}
