#!/usr/bin/env bash
# Bind this machine to a workvm project and enable startup on graphical login.
# Usage: ./project-setup.sh <project>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_SRC="$REPO_ROOT/workvm/projects"
UNIT_SRC="$REPO_ROOT/workvm/systemd/workvm.service"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/workvm"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

# shellcheck source=/dev/null
source "$REPO_ROOT/workvm/lib/common.sh"

list_projects() {
    local dir
    for dir in "$PROJECTS_SRC"/*/; do
        [ -d "$dir" ] || continue
        echo "  $(basename "$dir")"
    done
}

show_valid_projects() {
    echo "Projetos válidos:"
    list_projects
}

# Returns 0 if $1 is a usable project name.
project_is_valid() {
    local name="$1"
    [ -n "$name" ] || return 1
    [ -d "$PROJECTS_SRC/$name" ] || return 1
    [ -f "$PROJECTS_SRC/$name/start.sh" ] || return 1
    [ -f "$PROJECTS_SRC/$name/project.conf" ] || return 1
    return 0
}

resolve_project() {
    local answer="${1:-}"

    while true; do
        if project_is_valid "$answer"; then
            PROJECT="$answer"
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

mkdir -p "$CONFIG_ROOT/projects" "$SYSTEMD_USER_DIR"

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
echo "  start   -> Cursor + Chromium (agora) e workvm.service nos próximos logins"
echo
echo "Nos próximos logins gráficos, workvm.service executará de novo:"
echo "  $CURRENT_LINK/start.sh"
