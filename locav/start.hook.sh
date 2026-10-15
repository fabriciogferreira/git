#!/usr/bin/env bash
# Pós-compose Locav: composer + migrate + passport quando o volume ainda não tem vendor.
# Problema: post-clone.sh só prepara .env (compose ainda não subiu); sem isto o
# laravel.test entra em FATAL e /api/hello estoura o wait no primeiro boot.
# Idempotente: com vendor/autoload.php presente, só garante migrate.

workvm_locav_api_exec() {
    local uid="$1"
    local gid="$2"
    shift 2
    (
        cd "${COMPOSE_DIR}"
        docker compose exec -T -u "${uid}:${gid}" laravel.test "$@"
    )
}

workvm_project_after_compose() {
    local api="${COMPOSE_DIR:-}"
    local uid gid marker

    if [ -z "$api" ] || [ ! -f "${api}/docker-compose.yml" ]; then
        workvm_project_log "Locav after_compose: COMPOSE_DIR inválido; pulando"
        return 0
    fi

    uid="${HOST_UID:-$(id -u)}"
    gid="${HOST_GID:-$(id -g)}"
    if [ "$uid" = "0" ]; then
        uid=1000
        gid=1000
    fi
    marker="${api}/storage/app/.workvm-bootstrapped"

    if [ ! -f "${api}/vendor/autoload.php" ]; then
        workvm_project_log "LocavApi: composer install (primeiro boot)"
        workvm_locav_api_exec "$uid" "$gid" \
            composer install --no-interaction --prefer-dist

        if ! grep -q '^APP_KEY=base64:' "${api}/.env" 2>/dev/null; then
            workvm_project_log "LocavApi: php artisan key:generate"
            workvm_locav_api_exec "$uid" "$gid" php artisan key:generate --force
        fi

        workvm_project_log "LocavApi: migrate + seed + passport + storage:link"
        workvm_locav_api_exec "$uid" "$gid" php artisan migrate --force
        workvm_locav_api_exec "$uid" "$gid" php artisan db:seed --force || \
            workvm_project_log "LocavApi: db:seed falhou; continuando"
        workvm_locav_api_exec "$uid" "$gid" php artisan passport:keys --force || \
            workvm_project_log "LocavApi: passport:keys falhou; continuando"
        workvm_locav_api_exec "$uid" "$gid" \
            php artisan passport:client --personal --no-interaction --name="Locav Personal Access Client" || \
            workvm_project_log "LocavApi: passport:client já existe ou falhou; continuando"
        workvm_locav_api_exec "$uid" "$gid" php artisan storage:link || true

        # README pede storage gravável pelo container; alinha dono ao WWWUSER.
        docker compose -f "${api}/docker-compose.yml" --project-directory "$api" \
            exec -T laravel.test chown -R "${uid}:${gid}" storage bootstrap/cache 2>/dev/null || true

        mkdir -p "$(dirname "$marker")"
        date -Iseconds >"$marker"

        workvm_project_log "LocavApi: restart backend (supervisor php)"
        docker restart locav-backend >/dev/null
        # Dá tempo do php voltar antes do WAIT_URL.
        sleep 3
    else
        workvm_project_log "LocavApi: vendor ok; migrate --force"
        workvm_locav_api_exec "$uid" "$gid" php artisan migrate --force || \
            workvm_project_log "LocavApi: migrate falhou; continuando"
    fi
}
