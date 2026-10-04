#!/usr/bin/env bash
# Bind this VM to a workvm project and enable startup on graphical login.
# Also applies versioned configs (configs/ + config.json) listed in project.conf.
# Usage: ./setup-project.sh <project>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_SRC="$REPO_ROOT/vm/projects"
UNIT_SRC="$REPO_ROOT/vm/systemd/workvm.service"
CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/workvm"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

# shellcheck source=/dev/null
source "$REPO_ROOT/vm/lib/common.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/vm/lib/apply-configs.sh"

usage() {
    echo "Usage: $0 <project>" >&2
    echo >&2
    echo "Available projects:" >&2
    for dir in "$PROJECTS_SRC"/*/; do
        [ -d "$dir" ] || continue
        echo "  $(basename "$dir")" >&2
    done
    exit 1
}

if [ "${1:-}" = "" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
fi

PROJECT="$1"
PROJECT_SRC="$PROJECTS_SRC/$PROJECT"

if [ ! -d "$PROJECT_SRC" ]; then
    echo "error: unknown project '$PROJECT'" >&2
    usage
fi

if [ ! -x "$PROJECT_SRC/start.sh" ] && [ -f "$PROJECT_SRC/start.sh" ]; then
    chmod +x "$PROJECT_SRC/start.sh"
fi

if [ ! -f "$PROJECT_SRC/start.sh" ]; then
    echo "error: missing start.sh in $PROJECT_SRC" >&2
    exit 1
fi

if [ ! -f "$PROJECT_SRC/project.conf" ]; then
    echo "error: missing project.conf in $PROJECT_SRC" >&2
    exit 1
fi

APPLY_CONFIGS=()
CLONE_REPOS=()
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
    echo "==> Clonando repositórios do projeto ($PROJECT)"
    workvm_clone_project_repos "${CLONE_REPOS[@]}"
else
    echo "==> Nenhum CLONE_REPOS definido em project.conf"
fi

if [ "${#APPLY_CONFIGS[@]}" -gt 0 ]; then
    echo "==> Aplicando configs do projeto ($PROJECT)"
    workvm_apply_configs "${APPLY_CONFIGS[@]}"
else
    echo "==> Nenhuma APPLY_CONFIGS definida em project.conf"
fi

systemctl --user daemon-reload
systemctl --user enable workvm.service

echo
echo "✓ Projeto selecionado: $PROJECT"
echo "  current -> $CURRENT_LINK -> $(readlink -f "$CURRENT_LINK")"
echo "  unit    -> $UNIT_DST"
echo
echo "No próximo login gráfico (ou reboot), workvm.service executará:"
echo "  $CURRENT_LINK/start.sh"
echo
echo "Para testar agora (sessão gráfica já ativa):"
echo "  systemctl --user start workvm.service"
echo "  # ou: $CURRENT_LINK/start.sh"
