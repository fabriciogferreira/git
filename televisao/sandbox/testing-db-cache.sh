# Cache do schema+seed de teste Televisão (db_*_test), estilo vendor.
# Problema: o 1º Pest no sandbox gasta migrate:fresh + TestingSeeder no
# Postgres shared. Sem FastRefresh, RefreshDatabase sempre remigra — este
# cache faz pg_dump no host, importa no create e patcha o TestCase do
# worktree para pular migrate:fresh quando a tabela migrations já existe
# e para não re-seedar users já importados (unique email).
# Opt-out: WORKVM_TELEVISAO_TESTING_DB_CACHE=0
# Sourced por televisao/sandbox/project.sh (after_up / before_job).

workvm_televisao_testing_db_cache_enabled() {
    case "${WORKVM_TELEVISAO_TESTING_DB_CACHE:-1}" in
        0|false|no|off) return 1 ;;
        *) return 0 ;;
    esac
}

workvm_televisao_testing_db_cache_dir() {
    printf '%s/workvm/cache/televisao-testing-db\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

# Dirty-aware: hash files on disk (rsync do card muda morph/migrations sem commit).
workvm_televisao_testing_db_cache_key() {
    local api="$1"
    local key
    [ -d "${api}/database/migrations" ] || return 1
    [ -d "${api}/database/seeders" ] || return 1
    key="$(
        {
            find "${api}/database/migrations" "${api}/database/seeders" \
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

workvm_televisao_testing_db_cache_stamp_path() {
    local api="$1"
    printf '%s/storage/app/.workvm-testing-db-cache.key\n' "$api"
}

# Worktree-only: skip migrate:fresh when dump populated; skip re-seed of TestingSeeder.
workvm_televisao_testing_db_cache_patch_testcase() {
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
    if ! grep -q 'WorkvmCachedRefreshDatabase' "$tc" 2>/dev/null; then
        if grep -qE 'use RefreshDatabase;' "$tc"; then
            sed -i 's/use RefreshDatabase;/use WorkvmCachedRefreshDatabase;/' "$tc"
            workvm_sandbox_log "testing-db-cache: TestCase → WorkvmCachedRefreshDatabase"
        fi
    fi

    # Dump already ran TestingSeeder — setUp re-seed hits users_email_unique.
    if grep -q 'workvm-testing-db-cache: seed-guard' "$tc" 2>/dev/null; then
        return 0
    fi
    if grep -qE '\$this->seed\(TestingSeeder::class\);' "$tc"; then
        WORKVM_SB_TC="$tc" python3 - <<'PY'
import os, re
path = os.environ["WORKVM_SB_TC"]
text = open(path, encoding="utf-8").read()
pat = re.compile(
    r"^([ \t]*)\$this->seed\(TestingSeeder::class\);[ \t]*$",
    re.M,
)
repl = (
    r"\1// workvm-testing-db-cache: seed-guard — dump already seeded\n"
    r"\1if (! User::query()->exists()) {\n"
    r"\1  $this->seed(TestingSeeder::class);\n"
    r"\1}"
)
new, n = pat.subn(repl, text, count=1)
if n:
    open(path, "w", encoding="utf-8").write(new)
PY
        workvm_sandbox_log "testing-db-cache: TestCase seed guarded (skip if users exist)"
    fi
}

# phpunit.xml: force testing DB (belt; compose already sets SB_TESTING_DATABASE).
workvm_televisao_testing_db_cache_patch_phpunit() {
    local phpunit="$1"
    local testing_db="$2"
    [ -f "$phpunit" ] || return 0
    [ -n "$testing_db" ] || return 0
    if grep -q 'name="DB_DATABASE"' "$phpunit"; then
        sed -i -E "s|<env name=\"DB_DATABASE\"[^/]*/>|<env name=\"DB_DATABASE\" value=\"${testing_db}\" force=\"true\"/>|" "$phpunit"
    fi
    if grep -q 'name="DB_CONNECTION"' "$phpunit"; then
        sed -i -E 's|<env name="DB_CONNECTION"[^/]*/>|<env name="DB_CONNECTION" value="pgsql" force="true"/>|' "$phpunit"
    fi
}

workvm_televisao_testing_db_cache_apply() {
    local db="$1"
    local dump_gz="$2"
    local n
    n="$(docker exec televisao-hc-pgsql psql -U root -d "$db" -tAc \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null || echo 0)"
    n="$(printf '%s' "$n" | tr -d '[:space:]')"
    if [ "${n:-0}" -gt 0 ] 2>/dev/null; then
        workvm_sandbox_log "testing-db-cache: ${db} já tem tabelas (${n}); skip import"
        return 0
    fi
    workvm_sandbox_log "testing-db-cache: import → ${db}"
    gunzip -c "$dump_gz" | docker exec -i televisao-hc-pgsql psql -U root -d "$db" -v ON_ERROR_STOP=1 -q \
        >/dev/null || return 1
}

workvm_televisao_testing_db_cache_build() {
    local sandbox_id="$1"
    local cache_key="$2"
    local dump_gz="$3"
    local scratch sum_path
    scratch="tv_tdcache_$(printf '%s' "$cache_key" | cut -c1-16)"
    sum_path="${dump_gz%.sql.gz}.key"

    workvm_sandbox_log "testing-db-cache: build miss → scratch ${scratch}"
    docker exec televisao-hc-pgsql psql -U root -d postgres -v ON_ERROR_STOP=1 -c \
        "DROP DATABASE IF EXISTS \"${scratch}\";" >/dev/null
    docker exec televisao-hc-pgsql psql -U root -d postgres -v ON_ERROR_STOP=1 -c \
        "CREATE DATABASE \"${scratch}\";" || return 1

    if ! workvm_sandbox_container_compose "$sandbox_id" exec -T \
        -w /work/televisao-api \
        -e "DB_DATABASE=${scratch}" \
        -e "DB_CONNECTION=pgsql" \
        app php artisan migrate:fresh --force --no-interaction \
        --seeder=Database\\Seeders\\TestingSeeder --seed
    then
        docker exec televisao-hc-pgsql psql -U root -d postgres -c \
            "DROP DATABASE IF EXISTS \"${scratch}\";" >/dev/null 2>&1 || true
        return 1
    fi

    mkdir -p "$(dirname "$dump_gz")"
    # Sem --create/--dbname no dump: o restore escolhe o DB alvo (manual 9.4.5.1).
    docker exec televisao-hc-pgsql pg_dump -U root -d "$scratch" \
        --no-owner --no-acl --clean --if-exists \
        | gzip -c >"${dump_gz}.tmp" || {
        rm -f "${dump_gz}.tmp"
        docker exec televisao-hc-pgsql psql -U root -d postgres -c \
            "DROP DATABASE IF EXISTS \"${scratch}\";" >/dev/null 2>&1 || true
        return 1
    }
    mv -f "${dump_gz}.tmp" "$dump_gz"
    printf '%s' "$cache_key" >"$sum_path"
    docker exec televisao-hc-pgsql psql -U root -d postgres -c \
        "DROP DATABASE IF EXISTS \"${scratch}\";" >/dev/null 2>&1 || true
    workvm_sandbox_log "testing-db-cache: wrote $(basename "$dump_gz")"
}

workvm_televisao_testing_db_cache_ensure_for_sandbox() {
    local sandbox_id="$1"
    local wt="$2"
    local testing_db="$3"
    local api_db="${4:-}"
    local api cache_key cache_dir dump_gz

    workvm_televisao_testing_db_cache_enabled || return 0
    workvm_sandbox_televisao_shared_data_enabled || return 0

    api="${wt}/televisao-api"
    [ -d "${api}/database/migrations" ] || return 0
    docker inspect televisao-hc-pgsql --format '{{.State.Running}}' 2>/dev/null | grep -q true || return 0

    cache_key="$(workvm_televisao_testing_db_cache_key "$api")" || {
        workvm_sandbox_log "testing-db-cache: cache key falhou; Pest frio"
        return 0
    }

    cache_dir="$(workvm_televisao_testing_db_cache_dir)"
    mkdir -p "$cache_dir"
    dump_gz="${cache_dir}/${cache_key}.sql.gz"

    if [ ! -f "$dump_gz" ]; then
        workvm_televisao_testing_db_cache_build "$sandbox_id" "$cache_key" "$dump_gz" || {
            workvm_sandbox_log "testing-db-cache: build falhou; Pest frio"
            return 0
        }
    else
        workvm_sandbox_log "testing-db-cache: hit $(basename "$dump_gz")"
    fi

    workvm_televisao_testing_db_cache_apply "$testing_db" "$dump_gz" || {
        workvm_sandbox_log "testing-db-cache: apply testing falhou; Pest frio"
        return 0
    }
    if [ -n "$api_db" ]; then
        workvm_televisao_testing_db_cache_apply "$api_db" "$dump_gz" || true
    fi

    workvm_televisao_testing_db_cache_patch_testcase "$api"
    workvm_televisao_testing_db_cache_patch_phpunit "${api}/phpunit.xml" "$testing_db"
    mkdir -p "${api}/storage/app"
    printf '%s' "$cache_key" >"$(workvm_televisao_testing_db_cache_stamp_path "$api")"
}

# Re-apply patches after agent rsync; rebuild dump if migrations/seeders drifted.
workvm_televisao_testing_db_cache_repatch_worktree() {
    local wt="$1"
    local testing_db="$2"
    local sandbox_id="${3:-}"
    local api_db="${4:-}"
    local api stamp want have cache_dir dump_gz
    api="${wt}/televisao-api"
    [ -d "$api" ] || return 0
    workvm_televisao_testing_db_cache_patch_testcase "$api"
    workvm_televisao_testing_db_cache_patch_phpunit "${api}/phpunit.xml" "$testing_db"

    workvm_televisao_testing_db_cache_enabled || return 0
    want="$(workvm_televisao_testing_db_cache_key "$api" 2>/dev/null || true)"
    [ -n "$want" ] || return 0
    stamp="$(workvm_televisao_testing_db_cache_stamp_path "$api")"
    have="$(cat "$stamp" 2>/dev/null || true)"
    if [ -n "$have" ] && [ "$have" = "$want" ]; then
        return 0
    fi

    # Dirty morph/migration vs dump do tip — invalida e reconstrói.
    workvm_sandbox_log "testing-db-cache: schema drift (stamp≠disk); rebuild"
    cache_dir="$(workvm_televisao_testing_db_cache_dir)"
    mkdir -p "$cache_dir"
    dump_gz="${cache_dir}/${want}.sql.gz"
    rm -f "$dump_gz" "${dump_gz%.sql.gz}.key"
    if [ -n "$sandbox_id" ] && [ -n "$testing_db" ]; then
        # Drop testing tables so apply reimports.
        docker exec televisao-hc-pgsql psql -U root -d postgres -v ON_ERROR_STOP=1 -c \
            "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${testing_db}' AND pid <> pg_backend_pid();" \
            >/dev/null 2>&1 || true
        docker exec televisao-hc-pgsql psql -U root -d postgres -v ON_ERROR_STOP=1 -c \
            "DROP DATABASE IF EXISTS \"${testing_db}\";" >/dev/null 2>&1 || true
        docker exec televisao-hc-pgsql psql -U root -d postgres -v ON_ERROR_STOP=1 -c \
            "CREATE DATABASE \"${testing_db}\";" >/dev/null 2>&1 || true
        if [ -n "$api_db" ]; then
            docker exec televisao-hc-pgsql psql -U root -d postgres -v ON_ERROR_STOP=1 -c \
                "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${api_db}' AND pid <> pg_backend_pid();" \
                >/dev/null 2>&1 || true
            docker exec televisao-hc-pgsql psql -U root -d postgres -v ON_ERROR_STOP=1 -c \
                "DROP DATABASE IF EXISTS \"${api_db}\";" >/dev/null 2>&1 || true
            docker exec televisao-hc-pgsql psql -U root -d postgres -v ON_ERROR_STOP=1 -c \
                "CREATE DATABASE \"${api_db}\";" >/dev/null 2>&1 || true
        fi
        workvm_televisao_testing_db_cache_ensure_for_sandbox \
            "$sandbox_id" "$wt" "$testing_db" "$api_db" || true
    fi
}
