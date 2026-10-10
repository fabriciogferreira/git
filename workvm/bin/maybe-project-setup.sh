#!/usr/bin/env bash
# If this VM has no project bound yet, run project-setup.sh interactively.
#
# Hyprland autostart (hl.exec_cmd):
#   stdin is often /dev/tty1 (VT) or /dev/null — not a visible Wayland terminal.
#   → wait for the compositor, open Kitty, re-exec this script inside it.
#
# Already in a pts (user ran from an existing terminal):
#   → run project-setup.sh directly.
set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$BIN_DIR/../lib/common.sh"

REPO_ROOT="$(workvm_discover_repo_root "$BIN_DIR")"
SETUP="$REPO_ROOT/project-setup.sh"
SELF="$BIN_DIR/maybe-project-setup.sh"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/workvm"
LOG_FILE="$LOG_DIR/maybe-project-setup.log"

log() {
    mkdir -p "$LOG_DIR"
    printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$LOG_FILE"
}

if workvm_project_is_setup; then
    exit 0
fi

if [ ! -x "$SETUP" ]; then
    log "error: não encontrado: $SETUP"
    echo "error: não encontrado: $SETUP" >&2
    exit 1
fi

# Visible interactive terminal = pts (Kitty/foot/etc). /dev/tty1 from
# hl.exec_cmd is a TTY but not shown on the Hyprland session.
on_visible_pts() {
    case "$(tty 2>/dev/null || true)" in
        /dev/pts/*) return 0 ;;
        *) return 1 ;;
    esac
}

wait_for_wayland() {
    local i sock
    for i in $(seq 1 50); do
        if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
            sock="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
            if [ -S "$sock" ] && hyprctl version >/dev/null 2>&1; then
                return 0
            fi
        elif hyprctl version >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.2
    done
    return 1
}

if ! on_visible_pts; then
    log "no visible pts (tty=$(tty 2>/dev/null || true)); spawning Kitty"
    if ! wait_for_wayland; then
        log "error: Wayland/Hyprland not ready; giving up"
        exit 1
    fi
    # Hold the window on failure so a flash-and-die is debuggable.
    exec /usr/bin/kitty --class workvm-project-setup -e bash -lc \
        'self="$1"; log="$2"; "$self" || { echo; echo "falhou (log: $log)"; read -r -p "Enter para fechar..."; }' \
        bash "$SELF" "$LOG_FILE"
fi

log "on pts; exec project-setup"
exec "$SETUP"
