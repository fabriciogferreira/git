#!/usr/bin/env bash
# Bind this Arch + Hyprland machine to a workvm project and enable startup on
# graphical login.
# Usage: ./project-setup.sh <project>
# Project id may be nested (olie-ai/televisao) or a unique basename (televisao).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_SRC="$REPO_ROOT/workvm/projects"
UNIT_SRC="$REPO_ROOT/workvm/systemd/workvm.service"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/workvm"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

# shellcheck source=/dev/null
source "$REPO_ROOT/workvm/lib/common.sh"

list_projects() {
    local id
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        echo "  $id"
    done < <(workvm_list_project_ids "$PROJECTS_SRC")
}

show_valid_projects() {
    echo "Projetos válidos:"
    list_projects
}

# Returns 0 if $1 resolves to a usable project id (sets RESOLVED_PROJECT).
project_is_valid() {
    local name="$1"
    local resolved
    [ -n "$name" ] || return 1
    if ! resolved="$(workvm_resolve_project_id "$PROJECTS_SRC" "$name")"; then
        return 1
    fi
    RESOLVED_PROJECT="$resolved"
    return 0
}

resolve_project() {
    local answer="${1:-}"

    while true; do
        if project_is_valid "$answer"; then
            PROJECT="$RESOLVED_PROJECT"
            return 0
        fi

        if [ -z "$answer" ]; then
            echo "Informe um projeto." >&2
        else
            echo "Projeto inválido: '$answer'" >&2
        fi
        show_valid_projects
        echo
        printf 'Projeto: '
        read -r answer || true
        answer="${answer//[[:space:]]/}"
    done
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    echo "Usage: $0 [project]"
    echo
    show_valid_projects
    exit 0
fi

resolve_project "${1:-}"
PROJECT_SRC="$PROJECTS_SRC/$PROJECT"

if [ ! -x "$PROJECT_SRC/start.sh" ]; then
    chmod +x "$PROJECT_SRC/start.sh"
fi

CLONE_REPOS=()
POST_CLONE=()
# shellcheck source=/dev/null
source "$PROJECT_SRC/project.conf"

FILES_PROJECT="${PROJECT_NAME:-$(basename "$PROJECT")}"

mkdir -p "$CONFIG_ROOT/projects" "$SYSTEMD_USER_DIR"
mkdir -p "$(dirname "$CONFIG_ROOT/projects/$PROJECT")"

# ~/.config/environment.d must be a directory (*.conf), not a file — needed for
# Cursor MCP ${env:NAME} headers (e.g. OLIE_FLOW_AI_TOKEN).
echo "==> Garantindo ~/.config/environment.d/"
workvm_ensure_environment_d || true

PROJECT_LINK="$CONFIG_ROOT/projects/$PROJECT"
CURRENT_LINK="$CONFIG_ROOT/current"
UNIT_DST="$SYSTEMD_USER_DIR/workvm.service"

ln -sfn "$PROJECT_SRC" "$PROJECT_LINK"
ln -sfn "$PROJECT_LINK" "$CURRENT_LINK"
ln -sfn "$UNIT_SRC" "$UNIT_DST"

if [ "${#CLONE_REPOS[@]}" -gt 0 ]; then
    echo "==> Clonando/atualizando repositórios do projeto ($PROJECT)"
    workvm_clone_project_repos "${CLONE_REPOS[@]}"
else
    echo "==> Nenhum CLONE_REPOS definido em project.conf"
fi

if [ -f "$PROJECT_SRC/post-clone.sh" ]; then
    echo "==> Pós-clone do projeto ($PROJECT)"
    bash "$PROJECT_SRC/post-clone.sh"
elif [ "${#POST_CLONE[@]}" -gt 0 ]; then
    echo "==> Pós-clone do projeto ($PROJECT)"
    workvm_run_post_clone "${POST_CLONE[@]}"
else
    echo "==> Nenhum pós-clone definido (post-clone.sh / POST_CLONE)"
fi

echo "==> Aplicando files/$FILES_PROJECT → clones"
workvm_apply_files "$REPO_ROOT/files" "$FILES_PROJECT"

echo "==> Gravando workvm/.cursor/rules/workvm-project.mdc (projeto ativo para o agente)"
workvm_write_cursor_project_rule "$REPO_ROOT" "$PROJECT"

systemctl --user daemon-reload
systemctl --user enable workvm.service

# Run in this session (inherits Wayland/DISPLAY/PATH). systemd alone often
# lacks compositor env and would fail or hang on workvm_wait_for_wayland.
echo "==> Iniciando projeto ($PROJECT)"
"$PROJECT_SRC/start.sh"

echo
echo "✓ Projeto selecionado: $PROJECT"
echo "  current -> $CURRENT_LINK -> $(readlink -f "$CURRENT_LINK")"
echo "  unit    -> $UNIT_DST"
echo "  cursor  -> $REPO_ROOT/workvm/.cursor/rules/workvm-project.mdc"
echo "  start   -> Cursor + browser (agora) e workvm.service nos próximos logins"
echo
echo "Nos próximos logins gráficos, workvm.service executará de novo:"
echo "  $CURRENT_LINK/start.sh"
