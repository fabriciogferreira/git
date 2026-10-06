#!/usr/bin/env bash
# Guest: install Looking Glass Linux host (experimental) for IVSHMEM capture.
# Run inside the VM after vm-looking-glass-attach.sh on the hypervisor.
#
# Usage:
#   ./workvm/bin/guest-looking-glass-setup.sh          # preferred (yay as you)
#   sudo ./workvm/bin/guest-looking-glass-setup.sh     # ok — yay runs as SUDO_USER
set -euo pipefail

log() { printf '%s\n' "$*"; }
ok() { log "✓ $*"; }
step() { log ""; log "==> $*"; }
die() { log "error: $*" >&2; exit 1; }

# User that may run AUR helpers (never root).
if [ "$(id -u)" -eq 0 ]; then
    REAL_USER="${SUDO_USER:-}"
    [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ] \
        || die "rode sem sudo, ou: sudo -u <user> … / sudo ./script (com SUDO_USER)"
    as_user() { runuser -u "$REAL_USER" -- "$@"; }
    root_ok=1
else
    REAL_USER="$(id -un)"
    as_user() { "$@"; }
    root_ok=0
fi

run_root() {
    if [ "$root_ok" -eq 1 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

step "Aviso"
log "Looking Glass host no Linux é experimental (https://looking-glass.io/docs/B7/install_host/)."
log "Se não ficar estável, alternativa fluida: Sunshine/Moonlight com VAAPI na VF."
log "AUR como usuário: $REAL_USER"

step "AUR helper"
if as_user bash -lc 'command -v yay >/dev/null'; then
    AUR=yay
elif as_user bash -lc 'command -v paru >/dev/null'; then
    AUR=paru
else
    die "instale yay/paru no guest (como $REAL_USER)"
fi
ok "helper: $AUR"

step "Instalar looking-glass-host (AUR, não-root)"
# looking-glass-host-git: Linux capture via PipeWire.
if ! as_user bash -lc "command -v looking-glass-host >/dev/null 2>&1"; then
    as_user "$AUR" -S --needed --noconfirm looking-glass-host-git \
        || as_user "$AUR" -S --needed --noconfirm looking-glass-rc-host \
        || die "falha ao instalar looking-glass-host (AUR)"
fi

LG_BIN="$(as_user bash -lc 'command -v looking-glass-host || command -v looking-glass-host-bin || true')"
[ -n "$LG_BIN" ] || die "binário looking-glass-host não encontrado no PATH de $REAL_USER"
ok "looking-glass-host: $LG_BIN"

step "PipeWire / portal (Hyprland)"
run_root pacman -S --needed --noconfirm \
    pipewire pipewire-pulse wireplumber xdg-desktop-portal-hyprland \
    2>/dev/null \
    || run_root pacman -S --needed --noconfirm pipewire wireplumber xdg-desktop-portal-wlr \
    || true

step "IVSHMEM no guest"
if lspci | grep -qi ivshmem; then
    ok "dispositivo IVSHMEM visível:"
    lspci | grep -i ivshmem || true
else
    log "aviso: lspci sem 'ivshmem' — confira shmem na domain XML do host"
fi

log ""
log "Uso (sessão gráfica do guest, como $REAL_USER — sem sudo):"
log "  looking-glass-host"
log "No hypervisor:"
log "  looking-glass-client -f /dev/shm/looking-glass"
log ""
log "Mantenha Virtio/SPICE só para emergência; o viewer fluido é o client LG."
