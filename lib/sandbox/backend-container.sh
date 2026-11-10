# Backend container: um compose project por sandbox (rede/volumes/DB/Redis próprios).
# Problema: container_name e portas fixas impediam N stacks no mesmo guest.

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

workvm_sandbox_container_project_name() {
    local id="$1"
    # Compose project names: [a-z0-9_-]
    local slug
    slug=$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' | sed 's/-\+/-/g; s/^-//; s/-$//')
    printf 'sb-%s\n' "$slug"
}

workvm_sandbox_container_compose_dir() {
    printf '%s/compose\n' "$(workvm_sandbox_dir "$1")"
}

workvm_sandbox_container_create() {
    local id="$1"
    local project="$2"
    local profile="$3"
    local from_commit="$4"
    local backend_mem="${5:-}"
    local backend_cpus="${6:-}"

    workvm_sandbox_load_project "$project" || return 1

    local wt compose_dir project_name port_base
    wt="$(workvm_sandbox_worktrees_dir "$id" "$project")"
    compose_dir="$(workvm_sandbox_container_compose_dir "$id")"
    project_name="$(workvm_sandbox_container_project_name "$id")"
    port_base="$(workvm_sandbox_port_base "$id")"

    mkdir -p "$wt" "$compose_dir"

    if declare -F workvm_sandbox_project_prepare_worktrees >/dev/null; then
        workvm_sandbox_project_prepare_worktrees "$id" "$wt" "$from_commit" || return 1
    fi

    if ! declare -F workvm_sandbox_project_render_compose >/dev/null; then
        workvm_sandbox_log "project.sh sem workvm_sandbox_project_render_compose"
        return 1
    fi

    workvm_sandbox_project_render_compose \
        "$id" "$compose_dir" "$wt" "$profile" "$port_base" \
        "${backend_mem}" "${backend_cpus}" || return 1

    workvm_sandbox_log "compose up ($project_name profile=$profile)"
    workvm_sandbox_container_compose "$id" --profile "$profile" up -d --remove-orphans || return 1

    workvm_sandbox_meta_set "$id" compose_project "$project_name"
    workvm_sandbox_meta_set "$id" port_base "$port_base"
    workvm_sandbox_meta_set "$id" worktrees "$wt"
    workvm_sandbox_meta_set "$id" compose_dir "$compose_dir"
    workvm_sandbox_meta_set "$id" profile "$profile"
}

workvm_sandbox_container_compose() {
    local id="$1"
    shift
    local compose_dir project_name
    compose_dir="$(workvm_sandbox_meta_get "$id" compose_dir 2>/dev/null || true)"
    if [ -z "$compose_dir" ] || [ ! -d "$compose_dir" ]; then
        compose_dir="$(workvm_sandbox_container_compose_dir "$id")"
    fi
    project_name="$(workvm_sandbox_meta_get "$id" compose_project 2>/dev/null || true)"
    if [ -z "$project_name" ]; then
        project_name="$(workvm_sandbox_container_project_name "$id")"
    fi
    (
        cd "$compose_dir"
        set -a
        # shellcheck disable=SC1091
        [ -f .env ] && source .env
        set +a
        export COMPOSE_PROJECT_NAME="$project_name"
        docker compose "$@"
    )
}

workvm_sandbox_container_destroy() {
    local id="$1"
    local compose_dir project_name wt profile

    compose_dir="$(workvm_sandbox_meta_get "$id" compose_dir 2>/dev/null || true)"
    project_name="$(workvm_sandbox_meta_get "$id" compose_project 2>/dev/null || true)"
    wt="$(workvm_sandbox_meta_get "$id" worktrees 2>/dev/null || true)"
    profile="$(workvm_sandbox_meta_get "$id" profile 2>/dev/null || true)"
    profile="${profile:-tests}"

    if [ -n "$compose_dir" ] && [ -d "$compose_dir" ]; then
        workvm_sandbox_log "compose down -v ($project_name)"
        workvm_sandbox_container_compose "$id" --profile "$profile" down -v --remove-orphans 2>/dev/null \
            || workvm_sandbox_container_compose "$id" down -v --remove-orphans 2>/dev/null \
            || true
    elif [ -n "$project_name" ]; then
        docker compose -p "$project_name" down -v --remove-orphans 2>/dev/null || true
    fi

    # Remove leftover networks named after the project.
    if [ -n "$project_name" ]; then
        docker network ls --format '{{.Name}}' | grep -E "^${project_name}" \
            | while read -r net; do
                docker network rm "$net" 2>/dev/null || true
            done
    fi

    if [ -n "$wt" ] && [ -d "$wt" ]; then
        local project
        project="$(workvm_sandbox_meta_get "$id" project 2>/dev/null || true)"
        if declare -F workvm_sandbox_load_project >/dev/null && [ -n "$project" ]; then
            workvm_sandbox_load_project "$project" 2>/dev/null || true
        fi
        if declare -F workvm_sandbox_project_remove_worktrees >/dev/null; then
            workvm_sandbox_project_remove_worktrees "$id" "$wt" || true
        else
            rm -rf "$wt"
        fi
    fi
}

workvm_sandbox_container_exec() {
    local id="$1"
    shift
    local service="${WORKVM_SANDBOX_SERVICE:-app}"
    workvm_sandbox_container_compose "$id" exec -T "$service" "$@"
}

workvm_sandbox_container_run() {
    local id="$1"
    shift
    local service="${WORKVM_SANDBOX_SERVICE:-app}"
    workvm_sandbox_container_compose "$id" run --rm --no-deps "$service" "$@"
}

workvm_sandbox_container_publish_gui() {
    local id="$1"
    local attach="$2" # 1 attach, 0 detach
    local compose_dir project_name port_base profile

    compose_dir="$(workvm_sandbox_meta_get "$id" compose_dir)" || return 1
    project_name="$(workvm_sandbox_meta_get "$id" compose_project)" || return 1
    port_base="$(workvm_sandbox_meta_get "$id" port_base)" || return 1
    profile="$(workvm_sandbox_meta_get "$id" profile)" || true
    profile="${profile:-tests}"

    local project
    project="$(workvm_sandbox_meta_get "$id" project)"
    workvm_sandbox_load_project "$project" || return 1

    if ! declare -F workvm_sandbox_project_render_compose >/dev/null; then
        return 1
    fi

    local wt
    wt="$(workvm_sandbox_meta_get "$id" worktrees)"
    local mem cpus
    mem="$(workvm_sandbox_meta_get "$id" mem_limit 2>/dev/null || true)"
    cpus="$(workvm_sandbox_meta_get "$id" cpus 2>/dev/null || true)"

    WORKVM_SANDBOX_GUI="$attach" \
        workvm_sandbox_project_render_compose \
        "$id" "$compose_dir" "$wt" "$profile" "$port_base" \
        "${mem}" "${cpus}" || return 1

    workvm_sandbox_container_compose "$id" --profile "$profile" up -d --remove-orphans
}
