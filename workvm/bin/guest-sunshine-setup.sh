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
if ! run_root pacman -S --needed --noconfirm sunshine libva-utils intel-media-driver \
    pipewire wireplumber xdg-desktop-portal-hyprland 2>/dev/null \
    && ! run_root pacman -S --needed --noconfirm sunshine libva-utils intel-media-driver \
        pipewire wireplumber 2>/dev/null; then
    log "pacman não achou sunshine — tentando AUR (yay/paru)"
    if command -v yay >/dev/null 2>&1; then
        yay -S --needed --noconfirm sunshine-bin || yay -S --needed --noconfirm sunshine
    elif command -v paru >/dev/null 2>&1; then
        paru -S --needed --noconfirm sunshine-bin || paru -S --needed --noconfirm sunshine
    else
        die "pacote 'sunshine' não encontrado. Confira o digitado (sunshine, não shunsine) ou: yay -S sunshine-bin"
    fi
    run_root pacman -S --needed --noconfirm libva-utils intel-media-driver pipewire wireplumber || true
fi

command -v sunshine >/dev/null || die "sunshine não está no PATH após a instalação"
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

# Prefer Intel hardware encode (set render node after: ls -l /dev/dri/by-path)
encoder = vaapi
# Uncomment and point at the Intel render node (not virtio):
# adapter_name = /dev/dri/renderD129

# Capture Wayland / Hyprland
capture = wlr

# Session VM often has no tray/dbus — keep process alive
system_tray = disabled

min_log_level = info
EOF
    ok "criado $CONF_FILE"
else
    ok "já existe $CONF_FILE (não sobrescrito)"
fi

step "Serviço de usuário"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_FILE="$UNIT_DIR/sunshine.service"
mkdir -p "$UNIT_DIR"
if [ ! -f "$UNIT_FILE" ] && [ ! -f /usr/lib/systemd/user/sunshine.service ]; then
    cat >"$UNIT_FILE" <<EOF
[Unit]
Description=Sunshine GameStream host
After=graphical-session.target
PartOf=graphical-session.target

[Service]
ExecStart=/usr/bin/sunshine
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
EOF
    ok "unit criada: $UNIT_FILE"
fi

systemctl --user daemon-reload
systemctl --user enable --now sunshine.service 2>/dev/null \
    || systemctl --user enable --now sunshine 2>/dev/null \
    || true

if systemctl --user is-active sunshine.service >/dev/null 2>&1; then
    ok "sunshine ativo (user systemd)"
else
    log "iniciando sunshine em background..."
    nohup sunshine >/tmp/sunshine.log 2>&1 &
    sleep 1
    if pgrep -x sunshine >/dev/null; then
        ok "sunshine rodando (pid $(pgrep -x sunshine))"
    else
        log "aviso: falhou ao iniciar — veja /tmp/sunshine.log"
        log "        rode na sessão gráfica: sunshine"
    fi
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
