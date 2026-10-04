#!/usr/bin/env bash
# Prepare an Omarchy/Arch development VM base:
# clipboard Host↔VM, passwordless user/sudo, LUKS auto-unlock, SDDM autologin,
# Hyprland scrolling layout.
set -euo pipefail

USER_NAME="${USER_NAME:-fabricio}"
GIT_ROOT="${GIT_ROOT:-$HOME/git}"
LUKS_DEVICE="${LUKS_DEVICE:-/dev/vda2}"
LUKS_PARTUUID="${LUKS_PARTUUID:-023acdd4-02}"
KEYFILE="${KEYFILE:-/crypto_keyfile.bin}"
WAYLAND_VDAGENT_URL="${WAYLAND_VDAGENT_URL:-https://github.com/v-dermichev/wayland-vdagent/releases/download/v0.3.3/wayland-vdagent-x86_64-linux}"

log() { printf '%s\n' "$*"; }
ok() { log "✓ $*"; }
step() { log ""; log "==> $*"; }

setup_clipboard() {
    step "Clipboard Host ↔ VM"

    sudo pacman -S --needed --noconfirm spice-vdagent

    if [ ! -x /usr/local/bin/wayland-vdagent ]; then
        sudo curl -fsSL "$WAYLAND_VDAGENT_URL" -o /usr/local/bin/wayland-vdagent
        sudo chmod +x /usr/local/bin/wayland-vdagent
    else
        ok "wayland-vdagent já instalado"
    fi

    sudo systemctl enable --now spice-vdagentd.service
    systemctl --user mask spice-vdagent.service 2>/dev/null || true

    mkdir -p "$HOME/.config/autostart"
    printf '%s\n' '[Desktop Entry]' 'Hidden=true' >"$HOME/.config/autostart/spice-vdagent.desktop"

    local autostart_lua="$HOME/.config/hypr/autostart.lua"
    local launch_line='o.launch_on_start("/usr/local/bin/wayland-vdagent")'
    if [ -f "$autostart_lua" ]; then
        if ! grep -qxF "$launch_line" "$autostart_lua"; then
            sed -i "1a ${launch_line}" "$autostart_lua"
        else
            ok "wayland-vdagent já no autostart.lua"
        fi
    else
        log "aviso: $autostart_lua não encontrado; pulando autostart Hyprland"
    fi

    pkill -x spice-vdagent 2>/dev/null || true
    pkill -x wayland-vdagent 2>/dev/null || true
    /usr/local/bin/wayland-vdagent >/tmp/wayland-vdagent.log 2>&1 &
    ok "Clipboard configurado"
}

setup_passwordless() {
    step "Usuário e sudo sem senha"

    # NOPASSWD first so the remaining setup (and passwd -d) do not re-prompt.
    echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/"$USER_NAME" >/dev/null
    sudo chmod 440 /etc/sudoers.d/"$USER_NAME"
    sudo passwd -d "$USER_NAME" >/dev/null
    ok "passwd vazio + sudo NOPASSWD"
}

setup_docker() {
    step "Docker sem sudo (grupo docker)"

    sudo pacman -S --needed --noconfirm docker docker-compose

    if ! getent group docker >/dev/null; then
        sudo groupadd --system docker
    fi

    sudo usermod -aG docker "$USER_NAME"
    sudo systemctl enable --now docker.service

    # Socket must be group-writable by docker.
    if [ -S /var/run/docker.sock ]; then
        sudo chgrp docker /var/run/docker.sock
        sudo chmod 660 /var/run/docker.sock
    fi

    ok "$USER_NAME ∈ grupo docker; docker.service ativo"
    log "  (nova sessão necessária para o grupo valer: logout/login ou: newgrp docker)"
}

setup_hypr_scrolling() {
    step "Hyprland layout: scrolling"

    local looknfeel="$HOME/.config/hypr/looknfeel.lua"
    mkdir -p "$HOME/.config/hypr"

    if [ -f "$looknfeel" ] && grep -qE '^[[:space:]]*layout[[:space:]]*=[[:space:]]*"scrolling"' "$looknfeel"; then
        ok "layout scrolling já configurado"
        return 0
    fi

    if [ ! -f "$looknfeel" ]; then
        cat >"$looknfeel" <<'EOF'
-- Change the default Omarchy look'n'feel.

hl.config({
  general = {
    layout = "scrolling",
  },
})
EOF
    else
        cat >>"$looknfeel" <<'EOF'

-- Set by vm-setup.sh: default workspace layout
hl.config({
  general = {
    layout = "scrolling",
  },
})
EOF
    fi

    ok "layout scrolling em $looknfeel"
}

setup_luks_autologin() {
    step "LUKS auto-unlock + SDDM autologin"

    if [ ! -f "$KEYFILE" ]; then
        sudo dd if=/dev/urandom of="$KEYFILE" bs=1024 count=4 status=none
        sudo chmod 000 "$KEYFILE"
        sudo cryptsetup luksAddKey "$LUKS_DEVICE" "$KEYFILE"
        ok "keyfile criado e adicionado ao LUKS"
    else
        ok "keyfile já existe: $KEYFILE"
    fi

    if ! grep -q '/crypto_keyfile.bin' /etc/mkinitcpio.conf; then
        sudo sed -i 's|^FILES=.*|FILES=(/crypto_keyfile.bin)|' /etc/mkinitcpio.conf
    fi

    if ! grep -q "cryptkey=/crypto_keyfile.bin" /boot/limine.conf 2>/dev/null; then
        sudo mkinitcpio -P
        sudo sed -i \
            "s|cryptdevice=PARTUUID=${LUKS_PARTUUID}:root|cryptdevice=PARTUUID=${LUKS_PARTUUID}:root cryptkey=/crypto_keyfile.bin|g" \
            /boot/limine.conf
        ok "initramfs + limine atualizados"
    else
        ok "limine já possui cryptkey="
    fi

    sudo mkdir -p /etc/sddm.conf.d
    if [ ! -f /etc/sddm.conf.d/autologin.conf ]; then
        printf '%s\n' \
            '[Autologin]' \
            "User=${USER_NAME}" \
            'Session=omarchy.desktop' \
            'Relogin=true' \
            | sudo tee /etc/sddm.conf.d/autologin.conf >/dev/null
        ok "SDDM autologin criado"
    else
        ok "SDDM autologin já existe"
    fi
}

main() {
    log "vm-setup.sh — VM base Omarchy"
    setup_passwordless
    setup_docker
    setup_clipboard
    setup_hypr_scrolling
    setup_luks_autologin
    log ""
    log "VM base pronta. Próximo passo em uma VM clonada:"
    log "  $GIT_ROOT/project-setup.sh <projeto>"
    log "Se o grupo docker ainda não valer nesta sessão: newgrp docker"
}

main "$@"
