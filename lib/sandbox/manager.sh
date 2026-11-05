# Ciclo de vida do Sandbox (create/list/status/destroy).
# Problema: create e destroy precisavam ser idempotentes e respeitar teto
# de RAM na guest (Televisão 8 GiB → poucos sandboxes slim).

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=backend-container.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backend-container.sh"
# shellcheck source=backend-vm.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backend-vm.sh"

workvm_sandbox_default_max() {
    local project="$1"
    case "$project" in
        televisao) printf '2\n' ;;
        *) printf '%s\n' "${WORKVM_SANDBOX_MAX:-3}" ;;
    esac
}

workvm_sandbox_create() {
    local id="" project="televisao" profile="tests" from_commit="" backend="container"
    local mem_limit="" cpus=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --name) id="$2"; shift 2 ;;
            --project) project="$2"; shift 2 ;;
            --profile) profile="$2"; shift 2 ;;
            --from-commit) from_commit="$2"; shift 2 ;;
            --backend) backend="$2"; shift 2 ;;
            --mem) mem_limit="$2"; shift 2 ;;
            --cpus) cpus="$2"; shift 2 ;;
            *)
                workvm_sandbox_log "flag desconhecida: $1"
                return 2
                ;;
        esac
    done

    if [ -z "$id" ]; then
        workvm_sandbox_log "uso: create --name <id> [--project televisao] [--profile tests|mutation|e2e] [--from-commit SHA] [--backend container|vm]"
        return 2
    fi
    if ! workvm_sandbox_id_ok "$id"; then
        workvm_sandbox_log "id inválido: $id"
        return 2
    fi
    if workvm_sandbox_meta_exists "$id"; then
        workvm_sandbox_log "sandbox já existe: $id"
        return 1
    fi

    case "$profile" in
        tests|mutation|e2e|slim) ;;
        *)
            workvm_sandbox_log "profile inválido: $profile (tests|mutation|e2e)"
            return 2
            ;;
    esac
    case "$backend" in
        container|vm) ;;
        *)
            workvm_sandbox_log "backend inválido: $backend"
            return 2
            ;;
    esac

    workvm_sandbox_ensure_root
    workvm_sandbox_load_project "$project" || return 1

    local max
    max="${WORKVM_SANDBOX_MAX:-$(workvm_sandbox_default_max "$project")}"
    if declare -F workvm_sandbox_project_max >/dev/null; then
        max="$(workvm_sandbox_project_max)"
    fi
    local count
    count="$(workvm_sandbox_count)"
    if [ "$count" -ge "$max" ]; then
        workvm_sandbox_log "teto de sandboxes atingido ($count/$max). destroy um antes ou WORKVM_SANDBOX_MAX=…"
        return 1
    fi

    if [ -z "$mem_limit" ] && declare -F workvm_sandbox_project_mem_limit >/dev/null; then
        mem_limit="$(workvm_sandbox_project_mem_limit "$profile")"
    fi
    mem_limit="${mem_limit:-1g}"
    if [ -z "$cpus" ] && declare -F workvm_sandbox_project_cpus >/dev/null; then
        cpus="$(workvm_sandbox_project_cpus "$profile")"
    fi
    cpus="${cpus:-1.0}"

    local created
    created="$(workvm_sandbox_now_iso)"
    workvm_sandbox_meta_write "$id" "$(WORKVM_SB_ID="$id" WORKVM_SB_PROJECT="$project" \
        WORKVM_SB_PROFILE="$profile" WORKVM_SB_BACKEND="$backend" \
        WORKVM_SB_COMMIT="$from_commit" WORKVM_SB_CREATED="$created" \
        WORKVM_SB_MEM="$mem_limit" WORKVM_SB_CPUS="$cpus" python3 - <<'PY'
import json, os
print(json.dumps({
    "id": os.environ["WORKVM_SB_ID"],
    "project": os.environ["WORKVM_SB_PROJECT"],
    "profile": os.environ["WORKVM_SB_PROFILE"],
    "backend": os.environ["WORKVM_SB_BACKEND"],
    "from_commit": os.environ.get("WORKVM_SB_COMMIT") or None,
    "state": "creating",
    "created_at": os.environ["WORKVM_SB_CREATED"],
    "updated_at": os.environ["WORKVM_SB_CREATED"],
    "mem_limit": os.environ["WORKVM_SB_MEM"],
    "cpus": os.environ["WORKVM_SB_CPUS"],
    "gui_attached": False,
}, indent=2))
PY
)"

    local rc=0
    case "$backend" in
        container)
            workvm_sandbox_container_create "$id" "$project" "$profile" "$from_commit" "$mem_limit" "$cpus" || rc=$?
            ;;
        vm)
            workvm_sandbox_vm_create "$id" "$project" "$profile" "$from_commit" || rc=$?
            ;;
    esac

    if [ "$rc" -ne 0 ]; then
        workvm_sandbox_meta_set "$id" state "failed"
        workvm_sandbox_meta_set "$id" updated_at "$(workvm_sandbox_now_iso)"
        workvm_sandbox_log "create falhou; rode: workvm-sandbox destroy $id"
        return "$rc"
    fi

    workvm_sandbox_meta_set "$id" state "ready"
    workvm_sandbox_meta_set "$id" updated_at "$(workvm_sandbox_now_iso)"
    workvm_sandbox_log "sandbox ready: $id (backend=$backend profile=$profile)"
    printf '%s\n' "$id"
}

workvm_sandbox_destroy() {
    local id="${1:-}"
    if [ -z "$id" ]; then
        workvm_sandbox_log "uso: destroy <id>"
        return 2
    fi

    if ! workvm_sandbox_meta_exists "$id"; then
        workvm_sandbox_log "sandbox já ausente: $id"
        return 0
    fi

    workvm_sandbox_meta_set "$id" state "destroying"
    workvm_sandbox_meta_set "$id" updated_at "$(workvm_sandbox_now_iso)"

    local backend
    backend="$(workvm_sandbox_meta_get "$id" backend 2>/dev/null || printf 'container')"

    case "$backend" in
        container) workvm_sandbox_container_destroy "$id" || true ;;
        vm) workvm_sandbox_vm_destroy "$id" || true ;;
        *) workvm_sandbox_container_destroy "$id" || true ;;
    esac

    rm -rf "$(workvm_sandbox_dir "$id")"
    workvm_sandbox_log "sandbox destruído: $id"
}

workvm_sandbox_status() {
    local id="${1:-}"
    if [ -z "$id" ]; then
        workvm_sandbox_log "uso: status <id>"
        return 2
    fi
    if ! workvm_sandbox_meta_exists "$id"; then
        workvm_sandbox_log "sandbox ausente: $id"
        return 1
    fi
    cat "$(workvm_sandbox_meta_path "$id")"
}

workvm_sandbox_list() {
    local id state project profile backend
    printf '%-20s %-12s %-12s %-10s %-10s\n' ID STATE PROJECT PROFILE BACKEND
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        state="$(workvm_sandbox_meta_get "$id" state 2>/dev/null || echo '?')"
        project="$(workvm_sandbox_meta_get "$id" project 2>/dev/null || echo '?')"
        profile="$(workvm_sandbox_meta_get "$id" profile 2>/dev/null || echo '?')"
        backend="$(workvm_sandbox_meta_get "$id" backend 2>/dev/null || echo '?')"
        printf '%-20s %-12s %-12s %-10s %-10s\n' "$id" "$state" "$project" "$profile" "$backend"
    done < <(workvm_sandbox_list_ids)
}
