#!/usr/bin/env bash
# Prepare an Omarchy/Arch development VM base:
# clipboard Host↔VM, passwordless user/sudo, LUKS auto-unlock, SDDM autologin, git clones.
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

clone_repo() {
    local repo="$1"
    local destination="$2"

    if [ -d "$destination/.git" ]; then
        ok "Já existe: $destination"
        return 0
    fi

    log "→ Clonando: $repo"
    git clone "$repo" "$destination"
}

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

    sudo passwd -d "$USER_NAME" >/dev/null
    echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/"$USER_NAME" >/dev/null
    sudo chmod 440 /etc/sudoers.d/"$USER_NAME"
    ok "passwd vazio + sudo NOPASSWD"
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

clone_all_repos() {
    step "Clonar repositórios em ${GIT_ROOT}"

    mkdir -p "$GIT_ROOT"

    # This repo (skip if GIT_ROOT already is the clone)
    if [ ! -d "$GIT_ROOT/.git" ]; then
        clone_repo "git@github.com:fabriciogferreira/git.git" "$GIT_ROOT"
    else
        ok "Já existe: $GIT_ROOT"
    fi

    mkdir -p "$GIT_ROOT/olie"
    clone_repo "git@github.com:olie-ai/olie-fronts.git" "$GIT_ROOT/olie/olie-fronts"
    clone_repo "git@github.com:olie-ai/api-main.git" "$GIT_ROOT/olie/api-main"
    clone_repo "git@github.com:olie-ai/backoffice.git" "$GIT_ROOT/olie/backoffice"

    mkdir -p "$GIT_ROOT/opbed"
    clone_repo "git@github.com:Code-TreeOf/opbed-frontend.git" "$GIT_ROOT/opbed/opbed-frontend"
    clone_repo "git@github.com:Code-TreeOf/opbed-backend.git" "$GIT_ROOT/opbed/opbed-backend"

    mkdir -p "$GIT_ROOT/da-o-play"
    clone_repo "git@github.com:musicians-app/da-o-play-api.git" "$GIT_ROOT/da-o-play/da-o-play-api"

    clone_repo "git@github.com:fabriciogferreira/use-url-query.git" "$GIT_ROOT/use-url-query"
    clone_repo "git@github.com:fabriciogferreira/schema-to-query-string.git" "$GIT_ROOT/schema-to-query-string"
    clone_repo "git@github.com:fabriciogferreira/pick-deep-schema.git" "$GIT_ROOT/pick-deep-schema"
    clone_repo "git@github.com:fabriciogferreira/abacatepay-php-sdk.git" "$GIT_ROOT/abacatepay-php-sdk"

    mkdir -p "$GIT_ROOT/televisao"
    clone_repo "git@github.com:TelevisaoHope/televisao-api.git" "$GIT_ROOT/televisao/televisao-api"
    clone_repo "git@github.com:TelevisaoHope/televisao-meet-front.git" "$GIT_ROOT/televisao/televisao-meet-front"
    clone_repo "git@github.com:TelevisaoHope/televisao-front.git" "$GIT_ROOT/televisao/televisao-front"
    clone_repo "git@github.com:TelevisaoHope/televisao-meet-core.git" "$GIT_ROOT/televisao/televisao-meet-core"

    mkdir -p "$GIT_ROOT/boilerplate"
    clone_repo "git@github.com:Boilerplate-es/boilerplate-api.git" "$GIT_ROOT/boilerplate/boilerplate-api"

    ok "Repositórios em $GIT_ROOT"
}

main() {
    log "setup-vm.sh — VM base Omarchy"
    setup_clipboard
    setup_passwordless
    setup_luks_autologin
    clone_all_repos
    log ""
    log "VM base pronta. Próximo passo em uma VM clonada:"
    log "  $GIT_ROOT/setup-project.sh <projeto>"
}

main "$@"
