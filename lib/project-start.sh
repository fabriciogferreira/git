#!/usr/bin/env bash
# Boot único dos projetos. O login e o project-setup chamam este arquivo
# com o diretório do projeto (o de ~/.config/workvm/current).
# Problema: a mesma sequência estava copiada em cada projeto e já divergia
# (compose opcional, timeout, e2e). A diferença fica em project.conf.
# Um passo que não cabe em variável vai em start.hook.sh
# (função workvm_project_after_compose).

workvm_project_log() {
    printf '%s %s\n' "${WORKVM_PROJECT_LOG_TAG:-workvm}" "$*"
}

# Sobe os composes de e2e (Playwright MCP) sem herdar COMPOSE_FILE do app.
# O compose.dev.yaml do Laravel não existe nesses diretórios.
workvm_project_start_e2e() {
    local e2e_dir

    [ "${#E2E_COMPOSE_DIRS[@]}" -gt 0 ] || return 0

    for e2e_dir in "${E2E_COMPOSE_DIRS[@]}"; do
        if [ ! -d "$e2e_dir" ]; then
            workvm_project_log "e2e compose dir ausente: $e2e_dir"
            continue
        fi
        # O container grava relatório com outro uid.
        mkdir -p "$e2e_dir/test-results" "$e2e_dir/playwright-report"
        chmod -R a+rwX "$e2e_dir/test-results" "$e2e_dir/playwright-report" 2>/dev/null || true
        workvm_project_log "docker compose up -d ($e2e_dir) [Playwright MCP]"
        (
            unset COMPOSE_FILE
            workvm_docker_compose_up "$e2e_dir"
        ) || workvm_project_log "e2e compose failed at $e2e_dir; continuing"
    done
}

workvm_project_start() {
    local project_dir="$1"
    local lib_dir repo_root

    if [ -z "$project_dir" ] || [ ! -f "$project_dir/project.conf" ]; then
        echo "error: workvm_project_start <dir com project.conf>" >&2
        return 1
    fi

    # current/ é symlink sob ~/.config/workvm. Sem -P, o project.conf calcula
    # WORKSPACE_FILE pelo path lógico; o Cursor resolve ../../olie a partir
    # dali → ~/.config/olie/* (inexistente) em vez de ~/git/olie/*.
    project_dir="$(cd "$project_dir" && pwd -P)"

    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # shellcheck source=common.sh
    source "$lib_dir/common.sh"

    # check.sh aponta WORKVM_PROJECT_STUBS para trocar fetch, compose e
    # Cursor por funções vazias e exercer set -u sem subir a stack.
    if [ -n "${WORKVM_PROJECT_STUBS:-}" ]; then
        # shellcheck source=/dev/null
        source "$WORKVM_PROJECT_STUBS"
    fi

    CLONE_REPOS=()
    CHROMIUM_URLS=()
    E2E_COMPOSE_DIRS=()
    MCP=
    # shellcheck source=/dev/null
    source "$project_dir/project.conf"
    repo_root="$(cd "$lib_dir/.." && pwd)"

    if [ -f "$project_dir/start.hook.sh" ]; then
        # shellcheck source=/dev/null
        source "$project_dir/start.hook.sh"
    fi

    WORKVM_PROJECT_LOG_TAG="workvm[${PROJECT_NAME}]"

    # sshd does not start with the package. Without it the card chat cannot connect.
    workvm_enable_sshd
    workvm_authorize_workvm_ssh "$repo_root/lib/workvm_ed25519.pub"

    if [ "${#CLONE_REPOS[@]}" -gt 0 ]; then
        workvm_project_log "git fetch nos CLONE_REPOS (somente na branch de origem)"
        workvm_fetch_project_repos "${CLONE_REPOS[@]}"
    fi

    workvm_project_log "aplicando overlay/ em ${PROJECT_NAME}/"
    workvm_apply_files "$project_dir" "$PROJECT_NAME"

    # Depois do overlay: fontes versionados (mcps/, clones, e2e) → ~/.cursor/mcp.json.
    workvm_project_log "MCP do projeto → ~/.cursor/mcp.json"
    workvm_apply_mcp "$repo_root" "${MCP:-}" "$project_dir" \
        || workvm_project_log "MCP não aplicado"

    if [ -n "${COMPOSE_DIR:-}" ]; then
        workvm_project_log "docker compose up -d ($COMPOSE_DIR${COMPOSE_FILE:+ -f $COMPOSE_FILE})"
        if ! workvm_docker_compose_up "$COMPOSE_DIR"; then
            workvm_project_log "docker compose failed; continuing"
        else
            # Hook before WAIT_URL: Locav (e similares) precisam de composer/migrate
            # depois do compose e antes do healthcheck HTTP.
            if declare -F workvm_project_after_compose >/dev/null; then
                workvm_project_after_compose
            fi
            if [ -n "${WAIT_URL:-}" ]; then
                workvm_project_log "waiting for $WAIT_URL"
                workvm_wait_for_http "$WAIT_URL" "${WAIT_TIMEOUT_SECONDS:-180}" \
                    || workvm_project_log "continuing without $WAIT_URL"
            fi
        fi
    else
        workvm_project_log "sem COMPOSE_DIR; pulando docker compose"
        if declare -F workvm_project_after_compose >/dev/null; then
            workvm_project_after_compose
        fi
    fi

    workvm_project_start_e2e

    # A instalação confere o projeto com a janela aberta. O login da VM
    # sobe o compose sem Cursor nem Brave.
    if [ "${WORKVM_OPEN_APPS:-}" = 1 ]; then
        workvm_project_log "opening Cursor workspace"
        workvm_open_cursor "${WORKSPACE_FILE:-$project_dir/workspace.code-workspace}" \
            || workvm_project_log "falha ao abrir Cursor; continuando"

        if [ "${#CHROMIUM_URLS[@]}" -gt 0 ]; then
            workvm_project_log "opening browser (${#CHROMIUM_URLS[@]} urls)"
            workvm_open_chromium "${CHROMIUM_URLS[@]}" \
                || workvm_project_log "falha ao abrir browser; continuando"
        fi
    fi

    workvm_project_log "done"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -euo pipefail
    if [ -z "${1:-}" ]; then
        echo "error: workvm_project_start <dir com project.conf>" >&2
        exit 1
    fi
    workvm_project_start "$1"
fi
