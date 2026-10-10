#!/usr/bin/env bash
# If this VM has no project bound yet, run project-setup.sh interactively.
#
# Hyprland autostart (no TTY):
#   hl.exec_cmd("~/git/workvm/bin/maybe-project-setup.sh")
#   → opens Kitty and re-execs this script inside it.
#
# Already in a terminal:
#   kitty -e ~/git/workvm/bin/maybe-project-setup.sh
#   → runs project-setup.sh directly.
set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$BIN_DIR/../lib/common.sh"

REPO_ROOT="$(workvm_discover_repo_root "$BIN_DIR")"
SETUP="$REPO_ROOT/project-setup.sh"
SELF="$BIN_DIR/maybe-project-setup.sh"

if workvm_project_is_setup; then
    exit 0
fi

if [ ! -x "$SETUP" ]; then
    echo "error: não encontrado: $SETUP" >&2
    exit 1
fi

# Hyprland hl.exec_cmd has no TTY — spawn Kitty for the interactive menu.
if [ ! -t 0 ] || [ ! -t 1 ]; then
    # Brief wait so the Wayland socket is ready right after hyprland.start.
    sleep 0.5
    exec /usr/bin/kitty -e "$SELF"
fi

exec "$SETUP"
