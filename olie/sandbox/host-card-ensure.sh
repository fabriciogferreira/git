# Hook Olie: compose slim + front Vite + DNS por card (sem WorkVM).
# Problema: ensure precisava de API isolada e browser em
# devframe.{slug}.olie.localhost sem colidir entre cards.
# Sourced by lib/host-card.sh — define workvm_host_card_ensure_hook.
# Shared data: olie/sandbox/host-card-shared-data.sh
#
# Stack groups (RAM): back=app; front=http+front-management+olie-e2e.
# Primeira abertura infere e grava meta.stack_groups; reopen reusa.
# Override: WORKVM_HOST_CARD_GROUPS=back|front|back,front ou --groups.

# Para olie-e2e que ficou Up com o stack do card morto (app não running).
# Problema: restart unless-stopped / reboot do Docker deixava só o e2e vivo.
workvm_host_card_olie_stop_orphan_e2e() {
    local root id meta app_st e2e_st
    root="$(workvm_host_card_root)/olie"
    [ -d "$root" ] || return 0
    command -v docker >/dev/null 2>&1 || return 0

    for meta in "$root"/*/meta.json; do
        [ -f "$meta" ] || continue
        id="$(basename "$(dirname "$meta")")"
        app_st="$(docker inspect "hc-${id}-app-1" --format '{{.State.Running}}' 2>/dev/null || printf 'false')"
        e2e_st="$(docker inspect "hc-${id}-olie-e2e-1" --format '{{.State.Running}}' 2>/dev/null || printf 'false')"
        if [ "$e2e_st" = "true" ] && [ "$app_st" != "true" ]; then
            workvm_host_card_log "e2e órfão (app down) → stop hc-${id}-olie-e2e-1"
            docker stop "hc-${id}-olie-e2e-1" >/dev/null 2>&1 || true
        fi
    done
}

# Normaliza lista → sempre inclui back; front implica back.
# Args: tokens back/front. Stdout: "back" ou "back front".
workvm_host_card_olie_normalize_stack_groups() {
    local has_back=0 has_front=0 g
    for g in "$@"; do
        case "$g" in
            back|api) has_back=1 ;;
            front|frontend) has_front=1 ;;
        esac
    done
    [ "$has_front" = 1 ] && has_back=1
    [ "$has_back" = 1 ] || has_back=1
    if [ "$has_front" = 1 ]; then
        printf 'back front\n'
    else
        printf 'back\n'
    fi
}

workvm_host_card_olie_stack_has_front() {
    local g
    for g in "$@"; do
        [ "$g" = "front" ] && return 0
    done
    return 1
}

# Infere back vs front a partir de branches no olie-fronts com o CODE.
# Default: só back (mais barato) quando não há sinal de front.
workvm_host_card_olie_infer_stack_groups() {
    local code="$1"
    local git_root fronts want_front=0
    git_root="$(workvm_host_card_git_root)"
    fronts="${git_root}/olie/olie-fronts"
    if [ -d "${fronts}/.git" ] || [ -f "${fronts}/.git" ]; then
        if git -C "$fronts" branch -a --list "*${code}*" 2>/dev/null | grep -q .; then
            want_front=1
        fi
    fi
    if [ "$want_front" = 1 ]; then
        workvm_host_card_olie_normalize_stack_groups back front
    else
        workvm_host_card_olie_normalize_stack_groups back
    fi
}

# Resolve e persiste meta.stack_groups. Override: WORKVM_HOST_CARD_GROUPS.
workvm_host_card_olie_resolve_stack_groups() {
    local dir="$1"
    local code="$2"
    local meta groups_raw groups
    meta="${dir}/meta.json"

    groups_raw="$(python3 -c "import json;print(' '.join(json.load(open('$meta')).get('stack_groups') or []))" 2>/dev/null || true)"
    if [ -n "${WORKVM_HOST_CARD_GROUPS:-}" ]; then
        # shellcheck disable=SC2086
        groups="$(workvm_host_card_olie_normalize_stack_groups $(printf '%s' "$WORKVM_HOST_CARD_GROUPS" | tr ',+' ' '))"
        workvm_host_card_log "stack_groups override (env): $groups"
    elif [ -n "$groups_raw" ]; then
        # shellcheck disable=SC2086
        groups="$(workvm_host_card_olie_normalize_stack_groups $groups_raw)"
        workvm_host_card_log "stack_groups (meta): $groups"
    else
        groups="$(workvm_host_card_olie_infer_stack_groups "$code")"
        workvm_host_card_log "stack_groups (inferido): $groups"
    fi

    WORKVM_HC_GROUPS="$groups" python3 - "$meta" <<'PY'
import json, os, sys
path = sys.argv[1]
groups = os.environ.get("WORKVM_HC_GROUPS", "back").split()
with open(path, encoding="utf-8") as f:
    meta = json.load(f)
meta["stack_groups"] = groups
with open(path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
PY
    printf '%s\n' "$groups"
}

workvm_host_card_ensure_hook() {
    local id="$1"
    local dir="$2"
    local meta_repo git_root compose_dir port_base wt api_vendor
    local code dns_slug front_env fronts
    local stack_groups want_front=0

    meta_repo="$(workvm_host_card_meta_repo)"
    git_root="$(workvm_host_card_git_root)"
    # shellcheck source=/dev/null
    source "${meta_repo}/lib/sandbox/common.sh"
    # shellcheck source=/dev/null
    source "${meta_repo}/olie/sandbox/project.sh"
    # shellcheck source=/dev/null
    source "${meta_repo}/lib/host-card-proxy.sh"
    # shellcheck source=/dev/null
    source "${meta_repo}/olie/sandbox/host-card-shared-data.sh"

    compose_dir="${dir}/compose"
    # Base = clones em ~/git/olie; runtime = worktrees do card (+ vendor/nm).
    local clone_root card_wt fronts_base
    clone_root="${git_root}/olie"
    fronts_base="${clone_root}/olie-fronts"
    card_wt="${dir}/worktree"
    port_base="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['port_base'])")"
    code="$(python3 -c "import json;print(json.load(open('${dir}/meta.json')).get('code') or '')")"
    stack_groups="$(workvm_host_card_olie_resolve_stack_groups "$dir" "$code")"
    # shellcheck disable=SC2086
    workvm_host_card_olie_stack_has_front $stack_groups && want_front=1
    dns_slug="$(workvm_host_card_dns_slug "$code")"

    if [ ! -d "${clone_root}/api-main" ]; then
        workvm_host_card_log "clone ausente: ${clone_root}/api-main (rode project-setup olie no host)"
        return 1
    fi
    if [ ! -d "$fronts_base" ]; then
        workvm_host_card_log "clone ausente: ${fronts_base}"
        return 1
    fi

    # Worktrees de todos os CLONE_REPOS + meta; vendor/nm a partir da base.
    workvm_host_card_prepare_olie_isolation "$dir" "$code" || return 1
    wt="$card_wt"
    fronts="${card_wt}/olie-fronts"
    api_vendor="${dir}/vendor"
    if [ ! -d "$fronts" ]; then
        workvm_host_card_log "olie-fronts worktree ausente: $fronts"
        return 1
    fi
    if [ ! -f "${api_vendor}/autoload.php" ]; then
        workvm_host_card_log "vendor do card ausente: ${api_vendor}"
        return 1
    fi

    workvm_sandbox_olie_ensure_sandbox_image || return 1
    workvm_host_card_olie_ensure_shared_data || return 1
    workvm_host_card_olie_provision_card_databases "$dns_slug" || return 1

    # Per-card Vite env (urls DNS); template from worktree (tracked) or base.
    front_env="${dir}/front.env.development.local"
    WORKVM_HC_SRC="${fronts}/packages/management/.env.development" \
        WORKVM_HC_SRC_FALLBACK="${fronts_base}/packages/management/.env.development" \
        WORKVM_HC_DEST="$front_env" WORKVM_HC_SLUG="$dns_slug" python3 <<'PY'
import os
from pathlib import Path
src = Path(os.environ["WORKVM_HC_SRC"])
if not src.is_file():
    src = Path(os.environ.get("WORKVM_HC_SRC_FALLBACK") or "")
dest = Path(os.environ["WORKVM_HC_DEST"])
slug = os.environ["WORKVM_HC_SLUG"]
lines = src.read_text(encoding="utf-8").splitlines() if src.is_file() else []
overrides = {
    "VITE_APP_API_URL": f"http://api.{slug}.olie.localhost",
    "VITE_APP_DEFAULT_DOMAIN": f"{slug}.olie.localhost",
    "VITE_APP_DEVELOPMENT_SUBDOMAIN": "devframe",
    "VITE_APP_LANDING_PAGE_URL": f"http://landing-page.{slug}.olie.localhost",
    "VITE_APP_ERP_PAGE_URL": f"http://erp.{slug}.olie.localhost",
    "VITE_REVERB_HOST": f"reverb.{slug}.olie.localhost",
    # Google test site key (pares com RECAPTCHA_SECRET de teste no API)
    "VITE_APP_RECAPTCHA_SITE_KEY": "6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI",
}
seen = set()
out = []
for line in lines:
    if not line or line.startswith("#") or "=" not in line:
        out.append(line)
        continue
    k, _, _ = line.partition("=")
    if k in overrides:
        out.append(f"{k}={overrides[k]}")
        seen.add(k)
    else:
        out.append(line)
for k, v in overrides.items():
    if k not in seen:
        out.append(f"{k}={v}")
dest.write_text("\n".join(out) + "\n", encoding="utf-8")
PY

    # Prefer APP_KEY from clone .env (já copiado para o worktree do card)
    local app_key=""
    if [ -f "${wt}/api-main/.env" ]; then
        app_key="$(grep -E '^APP_KEY=' "${wt}/api-main/.env" | head -1 | cut -d= -f2- || true)"
    fi
    if [ -z "$app_key" ]; then
        app_key="base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    fi

    # e2e no worktree do meta-repo do card (não o ~/git ao vivo).
    local e2e_dir="${card_wt}/git/olie/olie-e2e"
    if [ ! -d "$e2e_dir" ]; then
        workvm_host_card_log "olie-e2e ausente no meta worktree: $e2e_dir"
        return 1
    fi
    # O container grava relatório com outro uid (igual project-start e2e).
    mkdir -p "$e2e_dir/test-results" "$e2e_dir/playwright-report"
    # Artefatos de e2e antigo (0:0 → nobody) — chmod não apaga; chown via Docker.
    if find "$e2e_dir/test-results" "$e2e_dir/playwright-report" \
        -not -user "$(id -u)" -print -quit 2>/dev/null | grep -q .; then
        workvm_host_card_log "chown e2e leftovers → $(id -u):$(id -g)"
        docker run --rm \
            -v "${e2e_dir}:/e2e" \
            alpine:3.20 \
            chown -R "$(id -u):$(id -g)" /e2e/test-results /e2e/playwright-report \
            2>/dev/null || true
    fi
    chmod -R a+rwX "$e2e_dir/test-results" "$e2e_dir/playwright-report" 2>/dev/null || true

    mkdir -p "$compose_dir/artifacts"
    cp -f "${meta_repo}/olie/sandbox/compose.slim.yml" "$compose_dir/compose.yaml"
    cp -f "${meta_repo}/olie/sandbox/compose.gui.yml" "$compose_dir/compose.gui.yml"
    cp -f "${meta_repo}/olie/sandbox/compose.front.yml" "$compose_dir/compose.front.yml"
    # Shared MySQL/Redis/Mongo (compose.host-data) — sem mysql por card.
    cp -f "${meta_repo}/olie/sandbox/compose.host-card-shared-data.yml" \
        "$compose_dir/compose.host-card-shared-data.yml"
    # Playwright MCP + suite — mesmo image olie/e2e da WorkVM
    cp -f "${meta_repo}/olie/sandbox/compose.e2e-host.yml" "$compose_dir/compose.e2e-host.yml"

    local pname="hc-${id}"
    local db_suffix api_db testing_db redis_prefix
    db_suffix="$(workvm_host_card_olie_db_suffix "$dns_slug")"
    api_db="api_${db_suffix}"
    testing_db="testing_${db_suffix}"
    redis_prefix="hc_${db_suffix}_"
    {
        printf 'COMPOSE_PROJECT_NAME=%s\n' "$pname"
        printf 'SB_WORKTREE=%s\n' "$wt"
        printf 'SB_API_VENDOR=%s\n' "$api_vendor"
        printf 'SB_FRONTS=%s\n' "$fronts"
        printf 'SB_FRONT_ENV=%s\n' "$front_env"
        printf 'SB_E2E=%s\n' "$e2e_dir"
        printf 'SB_DNS_SLUG=%s\n' "$dns_slug"
        printf 'SB_DB_DATABASE=%s\n' "$api_db"
        printf 'SB_MONGO_DATABASE=%s\n' "$api_db"
        printf 'SB_REDIS_PREFIX=%s\n' "$redis_prefix"
        printf 'SB_TESTING_DATABASE=%s\n' "$testing_db"
        # Placeholder: slim ainda interpola SB_MYSQL_INIT no serviço mysql
        # (profile unused); path vazio quebra o compose validate.
        printf 'SB_MYSQL_INIT=%s\n' "${meta_repo}/olie/sandbox/host-data-init"
        workvm_host_card_write_resource_env
        printf 'SB_PORT_API=%s\n' "$port_base"
        printf 'SB_PORT_FRONT=%s\n' "$((port_base + 1))"
        printf 'HOST_UID=%s\n' "$(id -u)"
        printf 'HOST_GID=%s\n' "$(id -g)"
        printf 'APP_KEY=%s\n' "$app_key"
        printf 'COMPOSE_FILE=compose.yaml:compose.gui.yml:compose.front.yml:compose.host-card-shared-data.yml:compose.e2e-host.yml\n'
    } >"$compose_dir/.env"

    workvm_host_card_apply_compose_limits "$compose_dir"

    # api-main sem .env (host sem post-clone): FrameSeeder usa
    # env('DEVELOPMENT_FRAME') → subdomain vazio → login
    # "Frame not found for subdomain" com Origin …/devframe.…
    if [ ! -f "${wt}/api-main/.env" ] && [ -f "${wt}/api-main/.env.example" ]; then
        workvm_host_card_log "api-main/.env ausente — copiando de .env.example"
        cp -n "${wt}/api-main/.env.example" "${wt}/api-main/.env" || true
    fi
    if [ -f "${wt}/api-main/.env" ]; then
        if grep -q '^DEVELOPMENT_FRAME=' "${wt}/api-main/.env"; then
            sed -i 's|^DEVELOPMENT_FRAME=.*|DEVELOPMENT_FRAME=devframe|' "${wt}/api-main/.env"
        else
            printf 'DEVELOPMENT_FRAME=devframe\n' >>"${wt}/api-main/.env"
        fi
        if grep -q '^APP_KEY=' "${wt}/api-main/.env"; then
            sed -i "s|^APP_KEY=.*|APP_KEY=${app_key}|" "${wt}/api-main/.env"
        else
            printf 'APP_KEY=%s\n' "$app_key" >>"${wt}/api-main/.env"
        fi
        # Google test secret — pares com site key do front.env (bypass local)
        if grep -q '^RECAPTCHA_SECRET=' "${wt}/api-main/.env"; then
            sed -i 's|^RECAPTCHA_SECRET=.*|RECAPTCHA_SECRET=6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe|' "${wt}/api-main/.env"
        else
            printf 'RECAPTCHA_SECRET=6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe\n' >>"${wt}/api-main/.env"
        fi
    fi

    # Site key de teste no Vite (senão o Google desafia no browser)
    if grep -q '^VITE_APP_RECAPTCHA_SITE_KEY=' "$front_env"; then
        sed -i 's|^VITE_APP_RECAPTCHA_SITE_KEY=.*|VITE_APP_RECAPTCHA_SITE_KEY=6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI|' "$front_env"
    else
        printf 'VITE_APP_RECAPTCHA_SITE_KEY=6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI\n' >>"$front_env"
    fi

    # APP_KEY + DEVELOPMENT_FRAME + RECAPTCHA no processo (mesmo sem .env montado)
    cat >"$compose_dir/compose.appkey.yml" <<EOF
services:
  app:
    environment:
      APP_KEY: \${APP_KEY}
      DEVELOPMENT_FRAME: devframe
      MANAGEMENT_URL: http://{subdomain}.${dns_slug}.olie.localhost
      RECAPTCHA_SECRET: 6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe
  http:
    environment:
      APP_KEY: \${APP_KEY}
      DEVELOPMENT_FRAME: devframe
      MANAGEMENT_URL: http://{subdomain}.${dns_slug}.olie.localhost
      RECAPTCHA_SECRET: 6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe
EOF
    # shellcheck disable=SC2016
    sed -i 's|^COMPOSE_FILE=.*|COMPOSE_FILE=compose.yaml:compose.gui.yml:compose.front.yml:compose.host-card-shared-data.yml:compose.e2e-host.yml:compose.appkey.yml|' \
        "$compose_dir/.env"

    local stack_label="olie-slim+shared-data"
    [ "$want_front" = 1 ] && stack_label="olie-slim+front+shared-data"
    python3 - "$dir/meta.json" "$pname" "$compose_dir" "$dns_slug" "$port_base" "$wt" "$api_vendor" \
        "$api_db" "$testing_db" "$redis_prefix" "$stack_label" <<'PY'
import json, sys
path, pname, compose_dir, slug, port_base, wt, vendor, api_db, testing_db, redis_prefix, stack = sys.argv[1:12]
port_base = int(port_base)
with open(path, encoding="utf-8") as f:
    meta = json.load(f)
meta["compose_project"] = pname
meta["compose_dir"] = compose_dir
meta["stack"] = stack
meta["dns_slug"] = slug
meta["api_dns"] = f"http://api.{slug}.olie.localhost"
meta["front_dns"] = f"http://devframe.{slug}.olie.localhost"
meta["api_url"] = f"http://127.0.0.1:{port_base}"
meta["front_url"] = f"http://127.0.0.1:{port_base + 1}"
meta["api_worktree"] = wt
meta["api_vendor"] = vendor
meta["db_database"] = api_db
meta["testing_database"] = testing_db
meta["redis_prefix"] = redis_prefix
meta["shared_data"] = "hc-olie-data"
with open(path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
PY

    # Outros cards: e2e não pode ficar Up se o app deles morreu.
    workvm_host_card_olie_stop_orphan_e2e || true

    # back=app; front=+http+front-management+olie-e2e (front implica back).
    local -a up_services=(app)
    if [ "$want_front" = 1 ]; then
        up_services+=(http front-management olie-e2e)
        workvm_host_card_log "compose up ($pname profile=slim groups=$stack_groups → ${up_services[*]})"
    else
        workvm_host_card_log "compose up ($pname profile=slim groups=$stack_groups → app; para front)"
    fi
    (
        cd "$compose_dir"
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
        export COMPOSE_PROJECT_NAME="$pname"
        # Sem --build: Compose V2 constrói olie/e2e só se a image não existir
        docker compose --profile slim up -d --remove-orphans "${up_services[@]}"
    ) || return 1

    # Só back: não deixar front/e2e de um ensure antigo comendo RAM.
    if [ "$want_front" != 1 ]; then
        (
            cd "$compose_dir"
            set -a
            # shellcheck disable=SC1091
            source .env
            set +a
            export COMPOSE_PROJECT_NAME="$pname"
            docker compose --profile slim stop http front-management olie-e2e 2>/dev/null || true
        ) || true
    fi

    # Container antigo pode ainda ter unless-stopped — recreate só nesse caso.
    if [ "$want_front" = 1 ]; then
        local e2e_pol
        e2e_pol="$(docker inspect "hc-${id}-olie-e2e-1" --format '{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null || true)"
        if [ "$e2e_pol" = "unless-stopped" ]; then
            workvm_host_card_log "olie-e2e ainda unless-stopped → recreate (restart: no)"
            (
                cd "$compose_dir"
                set -a
                # shellcheck disable=SC1091
                source .env
                set +a
                export COMPOSE_PROJECT_NAME="$pname"
                docker compose --profile slim up -d --force-recreate --no-deps olie-e2e
            ) || true
        fi
    fi

    # MySQL do slim nasce vazio — login no front falha sem migrate/seed
    # (mesma ideia do post-clone.sh da WorkVM).
    workvm_host_card_olie_migrate_seed "$compose_dir" "$pname" "$dir" || return 1

    workvm_host_card_proxy_ensure || workvm_host_card_log "proxy DNS falhou — use portas diretas"

    workvm_host_card_log "API  http://api.${dns_slug}.olie.localhost  (→ :${port_base})"
    if [ "$want_front" = 1 ]; then
        # Playwright MCP aponta para o e2e deste card
        workvm_host_card_set_e2e_container "$id"
        workvm_host_card_log "Front http://devframe.${dns_slug}.olie.localhost  (→ :$((port_base + 1)))"
        workvm_host_card_log "e2e  hc-${id}-olie-e2e-1  (E2E_* → ${dns_slug}.olie.localhost)"
    else
        workvm_host_card_log "Front/e2e off (stack_groups=back) — use: workvm-host-card add --project olie --code ${code} --group front"
    fi
}

# Espera MySQL e aplica migrate (+ seed na primeira vez).
workvm_host_card_olie_migrate_seed() {
    local compose_dir="$1"
    local pname="$2"
    local dir="$3"

    # Subshell so cd/.env do compose não vaza para o caller.
    (
        set -euo pipefail
        local i seeded=0
        cd "$compose_dir"
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
        export COMPOSE_PROJECT_NAME="$pname"

        workvm_host_card_log "aguardando MySQL compartilhado (olie-hc-mysql)…"
        for i in $(seq 1 60); do
            if docker exec olie-hc-mysql mysqladmin ping -h 127.0.0.1 -psandbox --silent 2>/dev/null; then
                break
            fi
            sleep 2
            if [ "$i" -eq 60 ]; then
                workvm_host_card_log "olie-hc-mysql não ficou healthy a tempo"
                exit 1
            fi
        done

        # Shared DB novo pode estar vazio mesmo com meta db_seeded=1 (migração do modelo antigo).
        db_name="${SB_DB_DATABASE:-api_main}"
        tables="$(docker exec olie-hc-mysql mysql -uroot -psandbox -N -e \
            "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db_name}'" 2>/dev/null || echo 0)"
        seeded="$(python3 -c "import json;print(json.load(open('${dir}/meta.json')).get('db_seeded') or 0)" 2>/dev/null || echo 0)"
        if [ "$seeded" = "1" ] && [ "${tables:-0}" -gt 0 ] 2>/dev/null; then
            workvm_host_card_log "migrate (banco já seedado: $db_name)"
            docker compose --profile slim exec -T app php artisan migrate --force
        else
            workvm_host_card_log "migrate --seed (banco vazio: $db_name; memory_limit=1G)"
            docker compose --profile slim exec -T app \
                php -d memory_limit=1G artisan migrate --seed --force
            python3 - "$dir/meta.json" <<'PY'
import json, sys
p = sys.argv[1]
m = json.load(open(p, encoding="utf-8"))
m["db_seeded"] = 1
json.dump(m, open(p, "w", encoding="utf-8"), indent=2)
open(p, "a", encoding="utf-8").write("\n")
PY
        fi
        # Seed sem DEVELOPMENT_FRAME cria work frame com subdomain ""
        # (já com FrameRelationship + Property). Origin pede "devframe".
        # Só promove o frame com vínculos — nunca cria órfão novo.
        workvm_host_card_log "garantindo frame subdomain=devframe (rename, sem órfão)"
        docker compose --profile slim exec -T -e DEVELOPMENT_FRAME=devframe app php -r '
require "vendor/autoload.php";
$app = require "bootstrap/app.php";
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use App\Models\Frame;
use App\Enums\Marketplace\FrameTypeEnum;
$empty = Frame::where("subdomain", "")->where("type", FrameTypeEnum::WORK->value)->first();
$dev = Frame::where("subdomain", "devframe")->first();
if ($empty && $dev && $empty->id !== $dev->id) {
    $dev->subdomain = "devframe-orphan-" . substr($dev->id, -8);
    $dev->save();
    $empty->subdomain = "devframe";
    $empty->save();
    echo "promoted {$empty->id}\n";
} elseif ($empty && ! $dev) {
    $empty->subdomain = "devframe";
    $empty->save();
    echo "renamed {$empty->id}\n";
} else {
    echo "ok subdomain=" . ($dev?->subdomain ?? "none") . "\n";
}
' || true
        docker compose --profile slim exec -T app php artisan config:clear || true
    ) || return 1
}
