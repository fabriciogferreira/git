# Cache do schema+seed de teste Locav (db_*_test), estilo vendor.
# Problema: o 1º Pest no sandbox gasta migrate:fresh + seed no Postgres
# shared. Sem FastRefresh, RefreshDatabase sempre remigra — pg_dump no host,
# import no create e patch do TestCase no worktree para pular migrate:fresh
# quando a tabela migrations já existe.
# Opt-out: WORKVM_LOCAV_TESTING_DB_CACHE=0
# Sourced por locav/sandbox/project.sh (after_up).

workvm_locav_testing_db_cache_enabled() {
    case "${WORKVM_LOCAV_TESTING_DB_CACHE:-1}" in
        0|false|no|off) return 1 ;;
        *) return 0 ;;
    esac
}

workvm_locav_testing_db_cache_dir() {
    printf '%s/workvm/cache/locav-testing-db\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

workvm_locav_testing_db_cache_key() {
    local api="$1"
    local mig seeders key
    mig="$(git -C "$api" rev-parse HEAD:database/migrations 2>/dev/null)" || return 1
    seeders="$(git -C "$api" rev-parse HEAD:database/seeders 2>/dev/null)" || return 1
    key="$(printf 'migrations:%s\nseeders:%s\n' "$mig" "$seeders" | sha256sum | awk '{print $1}')"
    case "$key" in
        [a-f0-9][a-f0-9][a-f0-9][a-f0-9]*) printf '%s\n' "$key" ;;
        *) return 1 ;;
    esac
}

workvm_locav_testing_db_cache_patch_testcase() {
    local api="$1"
    local tc trait
    tc="${api}/tests/TestCase.php"
    trait="${api}/tests/WorkvmCachedRefreshDatabase.php"
    [ -f "$tc" ] || return 0
    cat >"$trait" <<'PHP'
<?php

namespace Tests;

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\RefreshDatabaseState;
use Illuminate\Support\Facades\Schema;

/**
 * Sandbox-only (WorkVM). Skip migrate:fresh when testing-db-cache imported schema.
 */
trait WorkvmCachedRefreshDatabase
{
    use RefreshDatabase {
        refreshTestDatabase as private workvmLaravelRefreshTestDatabase;
    }

    protected function refreshTestDatabase()
    {
        if (! RefreshDatabaseState::$migrated) {
            if (Schema::hasTable('migrations')) {
                RefreshDatabaseState::$migrated = true;
            } else {
                $this->artisan('migrate:fresh', $this->migrateFreshUsing());
                $this->app[Kernel::class]->setArtisan(null);
                RefreshDatabaseState::$migrated = true;
            }
        }

        $this->beginDatabaseTransaction();
    }
}
PHP
    if grep -q 'WorkvmCachedRefreshDatabase' "$tc" 2>/dev/null; then
        return 0
    fi
    if grep -qE 'use RefreshDatabase;' "$tc"; then
        sed -i 's/use RefreshDatabase;/use WorkvmCachedRefreshDatabase;/' "$tc"
        workvm_sandbox_log "testing-db-cache: TestCase → WorkvmCachedRefreshDatabase"
    fi
}

workvm_locav_testing_db_cache_apply() {
    local db="$1"
    local dump_gz="$2"
    local n
    n="$(docker exec locav-hc-pgsql psql -U root -d "$db" -tAc \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null || echo 0)"
    n="$(printf '%s' "$n" | tr -d '[:space:]')"
    if [ "${n:-0}" -gt 0 ] 2>/dev/null; then
        workvm_sandbox_log "testing-db-cache: ${db} já tem tabelas (${n}); skip import"
        return 0
    fi
    workvm_sandbox_log "testing-db-cache: import → ${db}"
    gunzip -c "$dump_gz" | docker exec -i locav-hc-pgsql psql -U root -d "$db" -v ON_ERROR_STOP=1 -q \
        >/dev/null || return 1
}

workvm_locav_testing_db_cache_build() {
    local sandbox_id="$1"
    local cache_key="$2"
    local dump_gz="$3"
    local scratch sum_path seeder api_in_container
    scratch="locav_tdcache_$(printf '%s' "$cache_key" | cut -c1-16)"
    sum_path="${dump_gz%.sql.gz}.key"
    api_in_container="${WORKVM_LOCAV_API_MAIN:-}"
    # Prefer TestingSeeder when present (parity with TestCase); else DatabaseSeeder.
    if [ -n "$api_in_container" ] && [ -f "${api_in_container}/database/seeders/TestingSeeder.php" ]; then
        seeder='Database\Seeders\TestingSeeder'
    else
        seeder='Database\Seeders\DatabaseSeeder'
    fi

    workvm_sandbox_log "testing-db-cache: build miss → scratch ${scratch} seeder=${seeder}"
    docker exec locav-hc-pgsql psql -U root -d postgres -v ON_ERROR_STOP=1 -c \
        "DROP DATABASE IF EXISTS \"${scratch}\";" >/dev/null
    docker exec locav-hc-pgsql psql -U root -d postgres -v ON_ERROR_STOP=1 -c \
        "CREATE DATABASE \"${scratch}\";" || return 1

    if ! workvm_sandbox_container_compose "$sandbox_id" exec -T \
        -w /work/LocavApi \
        -e "DB_DATABASE=${scratch}" \
        -e "DB_CONNECTION=pgsql" \
        app php artisan migrate:fresh --force --no-interaction \
        --seeder="${seeder}" --seed
    then
        docker exec locav-hc-pgsql psql -U root -d postgres -c \
            "DROP DATABASE IF EXISTS \"${scratch}\";" >/dev/null 2>&1 || true
        return 1
    fi

    mkdir -p "$(dirname "$dump_gz")"
    docker exec locav-hc-pgsql pg_dump -U root -d "$scratch" \
        --no-owner --no-acl --clean --if-exists \
        | gzip -c >"${dump_gz}.tmp" || {
        rm -f "${dump_gz}.tmp"
        docker exec locav-hc-pgsql psql -U root -d postgres -c \
            "DROP DATABASE IF EXISTS \"${scratch}\";" >/dev/null 2>&1 || true
        return 1
    }
    mv -f "${dump_gz}.tmp" "$dump_gz"
    printf '%s' "$cache_key" >"$sum_path"
    docker exec locav-hc-pgsql psql -U root -d postgres -c \
        "DROP DATABASE IF EXISTS \"${scratch}\";" >/dev/null 2>&1 || true
    workvm_sandbox_log "testing-db-cache: wrote $(basename "$dump_gz")"
}

workvm_locav_testing_db_cache_ensure_for_sandbox() {
    local sandbox_id="$1"
    local wt="$2"
    local testing_db="$3"
    local api_db="${4:-}"
    local api cache_key cache_dir dump_gz

    workvm_locav_testing_db_cache_enabled || return 0
    workvm_sandbox_locav_shared_data_enabled || return 0

    api="${wt}/LocavApi"
    [ -d "${api}/database/migrations" ] || return 0
    docker inspect locav-hc-pgsql --format '{{.State.Running}}' 2>/dev/null | grep -q true || return 0

    cache_key="$(workvm_locav_testing_db_cache_key "$api")" || {
        workvm_sandbox_log "testing-db-cache: cache key falhou; Pest frio"
        return 0
    }

    cache_dir="$(workvm_locav_testing_db_cache_dir)"
    mkdir -p "$cache_dir"
    dump_gz="${cache_dir}/${cache_key}.sql.gz"

    if [ ! -f "$dump_gz" ]; then
        WORKVM_LOCAV_API_MAIN="$api" \
            workvm_locav_testing_db_cache_build "$sandbox_id" "$cache_key" "$dump_gz" || {
            workvm_sandbox_log "testing-db-cache: build falhou; Pest frio"
            return 0
        }
    else
        workvm_sandbox_log "testing-db-cache: hit $(basename "$dump_gz")"
    fi

    workvm_locav_testing_db_cache_apply "$testing_db" "$dump_gz" || {
        workvm_sandbox_log "testing-db-cache: apply testing falhou; Pest frio"
        return 0
    }
    if [ -n "$api_db" ]; then
        workvm_locav_testing_db_cache_apply "$api_db" "$dump_gz" || true
    fi

    workvm_locav_testing_db_cache_patch_testcase "$api"
}
