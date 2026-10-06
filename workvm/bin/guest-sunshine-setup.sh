#!/usr/bin/env bash
# Guest: install Sunshine (Moonlight host) using Intel iGPU VF via VAAPI.
# Prefer this over Looking Glass for Linux guests on Intel SR-IOV.
#
# Usage (inside the VM, as your user — may ask sudo for pacman):
#   ./workvm/bin/guest-sunshine-setup.sh
set -euo pipefail

log() { printf '%s\n' "$*"; }
ok() { log "✓ $*"; }
step() { log ""; log "==> $*"; }
die() { log "error: $*" >&2; exit 1; }

if [ "$(id -u)" -eq 0 ]; then
    die "rode sem root: ./workvm/bin/guest-sunshine-setup.sh"
fi

run_root() { sudo "$@"; }

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sunshine"
CONF_FILE="$CONF_DIR/sunshine.conf"

step "Pacotes"
run_root pacman -S --needed --noconfirm sunshine libva-utils intel-media-driver \
    pipewire wireplumber xdg-desktop-portal-hyprland \
    || run_root pacman -S --needed --noconfirm sunshine libva-utils intel-media-driver pipewire wireplumber

ok "sunshine: $(command -v sunshine)"

step "VAAPI (Intel VF)"
if command -v vainfo >/dev/null 2>&1; then
    if ! vainfo 2>/dev/null | head -40; then
        log "aviso: vainfo falhou — confira i915 na VF (lspci -nnk | grep -A3 a780)"
    fi
else
    log "aviso: vainfo não instalado"
fi

step "Config $CONF_FILE"
mkdir -p "$CONF_DIR"
if [ ! -f "$CONF_FILE" ]; then
    cat >"$CONF_FILE" <<'EOF'
# workvm — Sunshine on Intel iGPU VF (VAAPI)
# Docs: https://docs.lizardbyte.dev/projects/sunshine/

# Prefer Intel hardware encode
encoder = vaapi

# Capture Wayland / Hyprland via portal when possible
capture = wlr

# Lower latency defaults for LAN / localhost port-forward
min_log_level = info
EOF
    ok "criado $CONF_FILE"
else
    ok "já existe $CONF_FILE (não sobrescrito)"
fi

step "Serviço de usuário"
systemctl --user daemon-reload
systemctl --user enable --now sunshine.service 2>/dev/null \
    || systemctl --user enable --now sunshine 2>/dev/null \
    || {
        log "aviso: unit sunshine não encontrada — inicie manualmente: sunshine &"
        true
    }

if systemctl --user is-active sunshine.service >/dev/null 2>&1 \
    || systemctl --user is-active sunshine >/dev/null 2>&1; then
    ok "sunshine ativo (user systemd)"
else
    log "aviso: serviço não ativo; rode: sunshine"
fi

log ""
log "UI web do Sunshine (na VM): https://localhost:47990"
log "  — abra no Chromium da VM, veja o PIN e emparelhe no Moonlight."
log ""
log "No host (Moonlight já costuma estar em omarchy):"
log "  moonlight"
log "  Adicionar PC → 127.0.0.1  (com port-forward na domain; ver docs)"
log ""
log "Se Moonlight não achar a VM: confira port-forward no host"
log "  ./workvm/bin/vm-sunshine-ports.sh teste-sr-iov"
log "e use 127.0.0.1 no Moonlight."
