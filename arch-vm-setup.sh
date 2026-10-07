#!/usr/bin/env bash
# Prepare an Arch Linux + Hyprland development VM base:
# bootstrap (base-devel, yay), Hyprland stack, apps, Docker,
# clipboard Host↔VM, passwordless user/sudo, GRUB timeout=0,
# SDDM autologin (no login prompt), optional LUKS auto-unlock,
# apply $GIT_ROOT/.config → ~/.config.
set -euo pipefail

USER_NAME="${USER_NAME:-fabricio}"
GIT_ROOT="${GIT_ROOT:-$HOME/git}"
GIT_USER_NAME="${GIT_USER_NAME:-Fabrício Gonçalves Ferreira}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-fabriciof481@gmail.com}"
DOTCONFIG_SRC="${DOTCONFIG_SRC:-$GIT_ROOT/.config}"
DOTCONFIG_DST="${DOTCONFIG_DST:-${XDG_CONFIG_HOME:-$HOME/.config}}"
LUKS_DEVICE="${LUKS_DEVICE:-/dev/vda2}"
LUKS_PARTUUID="${LUKS_PARTUUID:-}"
KEYFILE="${KEYFILE:-/crypto_keyfile.bin}"
WAYLAND_VDAGENT_URL="${WAYLAND_VDAGENT_URL:-https://github.com/v-dermichev/wayland-vdagent/releases/download/v0.3.3/wayland-vdagent-x86_64-linux}"
YAY_TMP="${YAY_TMP:-/tmp/yay-bootstrap}"

log() { printf '%s\n' "$*"; }
ok() { log "✓ $*"; }
step() { log ""; log "==> $*"; }

require_user() {
    if [ "$(id -u)" -eq 0 ]; then
        log "error: rode como $USER_NAME (não como root). HOME/systemd --user iriam para /root." >&2
        exit 1
    fi
    if [ "$(id -un)" != "$USER_NAME" ]; then
        log "error: usuário atual é '$(id -un)'; esperado '$USER_NAME'" >&2
        exit 1
    fi
}

require_aur_helper() {
    if command -v yay >/dev/null 2>&1; then
        AUR_HELPER=yay
        return 0
    fi
    if command -v paru >/dev/null 2>&1; then
        AUR_HELPER=paru
        return 0
    fi
    log "error: precisa de yay ou paru para pacotes AUR" >&2
    exit 1
}

aur_install() {
    require_aur_helper
    "$AUR_HELPER" -S --needed --noconfirm "$@"
}

setup_base() {
    step "Pacotes base (git, base-devel, openssh)"

    sudo pacman -S --needed --noconfirm git base-devel openssh
    ok "git + base-devel + openssh"
}

setup_git_identity() {
    step "git user.name / user.email (global)"

    if ! command -v git >/dev/null 2>&1; then
        log "error: git ausente; rode setup_base antes" >&2
        exit 1
    fi

    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    ok "git identity: $GIT_USER_NAME <$GIT_USER_EMAIL>"
}

setup_yay() {
    step "yay (AUR helper)"

    if command -v yay >/dev/null 2>&1; then
        ok "yay já instalado"
        return 0
    fi

    # makepkg refuses to run as root.
    if [ "$(id -u)" -eq 0 ]; then
        log "error: rode o script como $USER_NAME (não como root) para instalar o yay" >&2
        exit 1
    fi

    rm -rf "$YAY_TMP"
    git clone --depth 1 https://aur.archlinux.org/yay.git "$YAY_TMP"
    (cd "$YAY_TMP" && makepkg -si --noconfirm)
    rm -rf "$YAY_TMP"

    if ! command -v yay >/dev/null 2>&1; then
        log "error: yay não ficou no PATH após makepkg -si" >&2
        exit 1
    fi
    ok "yay instalado"
}

# Mirror versioned overlays from $GIT_ROOT/.config/ into ~/.config/
# Convention: .config/hypr/hyprland.lua → $HOME/.config/hypr/hyprland.lua
# Safe to re-run (rsync -a / cp -a replaces without --delete).
setup_apply_dotconfig() {
    step "Aplicando .config/ do meta-repo → ~/.config"

    if [ ! -d "$DOTCONFIG_SRC" ]; then
        log "aviso: $DOTCONFIG_SRC ausente; pulando overlay de config"
        return 0
    fi

    mkdir -p "$DOTCONFIG_DST"

    local child base dest
    shopt -s nullglob dotglob
    for child in "$DOTCONFIG_SRC"/*; do
        base="$(basename "$child")"
        if [ "$base" = ".gitkeep" ]; then
            continue
        fi
        dest="$DOTCONFIG_DST/$base"
        if [ -d "$child" ]; then
            mkdir -p "$dest"
            log "  sync dir: .config/$base/"
            if command -v rsync >/dev/null 2>&1; then
                rsync -a "$child/" "$dest/"
            else
                cp -a "$child"/. "$dest"/
            fi
        elif [ -f "$child" ]; then
            log "  sync file: .config/$base"
            cp -a "$child" "$dest"
        fi
    done
    shopt -u nullglob dotglob

    ok "overlay aplicado: $DOTCONFIG_SRC → $DOTCONFIG_DST"
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

    # Autostart no Hyprland vem do overlay versionado (.config/hypr/hyprland.lua).
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

# Official repos via pacman; AUR via yay.
setup_apps() {
    step "Hyprland, apps e ferramentas"

    log "oficial: hyprland kitty hyprlauncher swaybg dbeaver"
    sudo pacman -S --needed --noconfirm \
        hyprland \
        kitty \
        hyprlauncher \
        swaybg \
        dbeaver

    log "AUR: cursor-bin google-chrome postman-bin"
    aur_install cursor-bin google-chrome postman-bin
    ok "apps instalados (ou já presentes)"
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

setup_meta_repo_pull() {
    step "Auto git fetch do meta-repo (~/git) no login gráfico"

    local unit_src="$GIT_ROOT/workvm/systemd/workvm-git-pull.service"
    local unit_dst="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/workvm-git-pull.service"
    local pull_script="$GIT_ROOT/workvm/bin/pull-meta.sh"

    if [ ! -f "$unit_src" ]; then
        log "error: unit ausente: $unit_src" >&2
        exit 1
    fi
    if [ ! -f "$pull_script" ]; then
        log "error: script ausente: $pull_script" >&2
        exit 1
    fi

    chmod +x "$pull_script"
    mkdir -p "$(dirname "$unit_dst")"
    ln -sfn "$unit_src" "$unit_dst"

    # Don't abort the whole bootstrap if the user bus isn't up yet.
    if systemctl --user daemon-reload 2>/dev/null \
        && systemctl --user enable workvm-git-pull.service 2>/dev/null; then
        ok "workvm-git-pull.service habilitado (fetch origin se branch=main em $GIT_ROOT)"
    else
        log "aviso: systemctl --user falhou; unit linkada em $unit_dst — enable após o 1º login gráfico"
    fi
}

setup_grub_timeout() {
    step "GRUB timeout=0 (boot direto)"

    if [ ! -f /etc/default/grub ]; then
        ok "GRUB ausente — pulando"
        return 0
    fi

    if grep -qE '^GRUB_TIMEOUT=0$' /etc/default/grub; then
        ok "GRUB_TIMEOUT já é 0"
    else
        sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
        if ! grep -qE '^GRUB_TIMEOUT=' /etc/default/grub; then
            printf '%s\n' 'GRUB_TIMEOUT=0' | sudo tee -a /etc/default/grub >/dev/null
        fi
        ok "GRUB_TIMEOUT=0"
    fi

    if grep -qE '^GRUB_TIMEOUT_STYLE=' /etc/default/grub; then
        sudo sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
    else
        printf '%s\n' 'GRUB_TIMEOUT_STYLE=hidden' | sudo tee -a /etc/default/grub >/dev/null
    fi

    sudo grub-mkconfig -o /boot/grub/grub.cfg
    ok "grub.cfg regenerado"
}

setup_luks() {
    step "LUKS auto-unlock (se aplicável)"

    if [ -b "$LUKS_DEVICE" ] && sudo cryptsetup isLuks "$LUKS_DEVICE" 2>/dev/null; then
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

        if [ -z "$LUKS_PARTUUID" ]; then
            LUKS_PARTUUID="$(sudo blkid -s PARTUUID -o value "$LUKS_DEVICE" 2>/dev/null || true)"
        fi

        if [ -f /etc/default/grub ]; then
            if ! grep -q 'cryptkey=/crypto_keyfile.bin' /etc/default/grub; then
                sudo sed -i \
                    's|GRUB_CMDLINE_LINUX="\([^"]*\)"|GRUB_CMDLINE_LINUX="\1 cryptkey=/crypto_keyfile.bin"|' \
                    /etc/default/grub
                sudo mkinitcpio -P
                sudo grub-mkconfig -o /boot/grub/grub.cfg
                ok "initramfs + GRUB atualizados com cryptkey="
            else
                ok "GRUB já possui cryptkey="
            fi
        elif [ -f /boot/limine.conf ]; then
            if ! grep -q "cryptkey=/crypto_keyfile.bin" /boot/limine.conf; then
                if command -v limine-mkinitcpio >/dev/null 2>&1; then
                    sudo limine-mkinitcpio
                else
                    sudo mkinitcpio -P
                fi
                if [ -n "$LUKS_PARTUUID" ]; then
                    sudo sed -i \
                        "s|cryptdevice=PARTUUID=${LUKS_PARTUUID}:root|cryptdevice=PARTUUID=${LUKS_PARTUUID}:root cryptkey=/crypto_keyfile.bin|g" \
                        /boot/limine.conf
                fi
                ok "initramfs + limine atualizados"
            else
                ok "limine já possui cryptkey="
            fi
        else
            log "aviso: LUKS presente, mas nem GRUB nem Limine encontrados para cryptkey="
            sudo mkinitcpio -P
        fi
    else
        ok "sem LUKS em $LUKS_DEVICE — pulando auto-unlock"
    fi
}

# Boot → SDDM → Hyprland as $USER_NAME, no greeter / password prompt.
# Relies on setup_passwordless (empty passwd + sudo NOPASSWD) as fallback.
setup_autologin() {
    step "SDDM autologin → Hyprland (sem tela de login)"

    sudo pacman -S --needed --noconfirm sddm

    if [ ! -f /usr/share/wayland-sessions/hyprland.desktop ]; then
        log "error: hyprland.desktop ausente; rode setup_apps antes (pacote hyprland)" >&2
        exit 1
    fi

    sudo mkdir -p /etc/sddm.conf.d
    printf '%s\n' \
        '[Autologin]' \
        "User=${USER_NAME}" \
        'Session=hyprland' \
        'Relogin=true' \
        | sudo tee /etc/sddm.conf.d/autologin.conf >/dev/null

    # Become the graphical display manager on next boot.
    sudo systemctl enable sddm.service
    ok "SDDM autologin: User=${USER_NAME} Session=hyprland (enable sddm)"
}

main() {
    log "arch-vm-setup.sh — VM base Arch Linux + Hyprland"
    require_user
    setup_passwordless
    setup_base
    setup_git_identity
    setup_yay
    setup_apps
    setup_docker
    setup_clipboard
    setup_apply_dotconfig
    # Boot path first so a later optional step can't block autologin.
    setup_grub_timeout
    setup_luks
    setup_autologin
    setup_meta_repo_pull
    log ""
    log "VM base pronta. Próximo passo em uma VM clonada:"
    log "  $GIT_ROOT/arch-project-setup.sh <projeto>"
    log "Se o grupo docker ainda não valer nesta sessão: newgrp docker"
    log "Reinicie para testar: GRUB sem menu → SDDM autologin → Hyprland"
    log "Nos próximos logins: workvm-git-pull.service faz git fetch em $GIT_ROOT (se branch=main)"
    log "Com projeto: start.sh faz git fetch nos CLONE_REPOS (se na branch de origem)"
}

main "$@"
