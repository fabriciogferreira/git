#!/usr/bin/env bash
# Startup for the Opbed development project (run by workvm.service).
set -euo pipefail

REAL_PROJECT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REAL_REPO_ROOT="$(cd "$REAL_PROJECT_DIR/../../.." && pwd)"

# shellcheck source=/dev/null
source "$REAL_REPO_ROOT/workvm/lib/common.sh"
# shellcheck source=/dev/null
source "$REAL_PROJECT_DIR/project.conf"

LOG_TAG="workvm[${PROJECT_NAME}]"
log() { printf '%s %s\n' "$LOG_TAG" "$*"; }

main() {
    if [ "${#CLONE_REPOS[@]}" -gt 0 ]; then
        log "git fetch nos CLONE_REPOS (somente na branch de origem)"
        workvm_fetch_project_repos "${CLONE_REPOS[@]}"
    fi

    log "waiting for Wayland/Hyprland"
    if ! workvm_wait_for_wayland 90; then
        log "Wayland indisponível; tentando abrir apps mesmo assim"
        workvm_ensure_session_env
    fi

    log "docker compose up -d ($COMPOSE_DIR)"
    if ! workvm_docker_compose_up "$COMPOSE_DIR"; then
        log "docker compose failed; continuing with editor/browser"
    elif [ -n "${WAIT_URL:-}" ]; then
        log "waiting for $WAIT_URL"
        workvm_wait_for_http "$WAIT_URL" "${WAIT_TIMEOUT_SECONDS:-180}" || log "continuing without $WAIT_URL"
    fi

    log "opening Cursor workspace"
    workvm_open_cursor "${WORKSPACE_FILE:-$REAL_PROJECT_DIR/workspace.code-workspace}" \
        || log "falha ao abrir Cursor; continuando"

    if [ "${#CHROMIUM_URLS[@]}" -gt 0 ]; then
        log "opening Chromium (${#CHROMIUM_URLS[@]} urls)"
        workvm_open_chromium "${CHROMIUM_URLS[@]}" \
            || log "falha ao abrir Chromium; continuando"
    fi

    log "done"
}

main "$@"
