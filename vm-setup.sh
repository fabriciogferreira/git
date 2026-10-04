#!/usr/bin/env bash
# Prepare an Omarchy/Arch development VM base:
# clipboard Host↔VM, passwordless user/sudo, LUKS auto-unlock, SDDM autologin,
# Hyprland scrolling layout, Cursor, DBeaver, Postman; strip stock web apps;
# Matte Black wallpaper and Plymouth unlock.
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

# Names must match ~/.local/share/applications/<Name>.desktop (Omarchy stock).
REMOVE_WEBAPPS=(
    Discord
    WhatsApp
    Zoom
    YouTube
    X
    Twitter
    'Google Maps'
    'Google Contacts'
    'Google Messages'
    'Google Photos'
)

remove_webapp() {
    local name="$1"
    local desktop="$HOME/.local/share/applications/${name}.desktop"

    if [ ! -f "$desktop" ]; then
        ok "webapp já ausente: $name"
        return 0
    fi

    OMARCHY_REMOVE_NOTIFY=false omarchy webapp remove "$name"
    ok "webapp removido: $name"
}

setup_remove_webapps() {
    step "Removendo web apps (Discord, WhatsApp, Zoom, X, YouTube, Google *)"

    if ! command -v omarchy >/dev/null 2>&1; then
        log "error: omarchy não está no PATH; não dá para remover web apps" >&2
        exit 1
    fi

    local name
    for name in "${REMOVE_WEBAPPS[@]}"; do
        remove_webapp "$name"
    done
}

# Stock extras not needed on work VMs (omarchy pkg drop skips missing packages).
setup_remove_packages() {
    step "Removendo aether, cliamp, moonlight, obsidian, localsend, OBS, kdenlive, pinta"

    if ! command -v omarchy >/dev/null 2>&1; then
        log "error: omarchy não está no PATH; não dá para remover pacotes" >&2
        exit 1
    fi

    omarchy pkg drop aether cliamp moonlight-qt obsidian localsend obs-studio kdenlive pinta
    ok "pacotes removidos (ou já ausentes)"
}

setup_passwordless() {
    step "Usuário e sudo sem senha"

    # NOPASSWD first so the remaining setup (and passwd -d) do not re-prompt.
    echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/"$USER_NAME" >/dev/null
    sudo chmod 440 /etc/sudoers.d/"$USER_NAME"
    sudo passwd -d "$USER_NAME" >/dev/null
    ok "passwd vazio + sudo NOPASSWD"
}

# Official repos: Cursor (omarchy/cursor-bin) and DBeaver (extra/dbeaver).
# AUR: Postman (postman-bin). omarchy pkg skips packages that are already installed.
setup_apps() {
    step "Cursor, DBeaver, Postman"

    if ! command -v omarchy >/dev/null 2>&1; then
        log "error: omarchy não está no PATH; não dá para instalar os apps" >&2
        exit 1
    fi

    log "Cursor e DBeaver (omarchy pkg add cursor-bin dbeaver)"
    omarchy pkg add cursor-bin dbeaver

    log "Postman (omarchy pkg aur add postman-bin)"
    omarchy pkg aur add postman-bin
    ok "apps instalados (ou já presentes)"
}

CHROMIUM_FLAGS="${XDG_CONFIG_HOME:-$HOME/.config}/chromium-flags.conf"
CHROMIUM_OAUTH_FLAG='--oauth2-client-id=77185425430.apps.googleusercontent.com'

setup_chromium_google_account() {
    step "Chromium Google Account"

    if [ -f "$CHROMIUM_FLAGS" ] && grep -qxF -- "$CHROMIUM_OAUTH_FLAG" "$CHROMIUM_FLAGS"; then
        ok "Chromium Google Account já instalado"
        return 0
    fi

    if ! command -v omarchy >/dev/null 2>&1; then
        log "error: omarchy não está no PATH; não dá para instalar Chromium Google Account" >&2
        exit 1
    fi

    # Official installer only appends if chromium-flags.conf already exists.
    mkdir -p "$(dirname "$CHROMIUM_FLAGS")"
    touch "$CHROMIUM_FLAGS"

    omarchy install chromium google account
    ok "Chromium Google Account instalado"
}

# Fabio Akita's ai-usagebar: AUR binary + Omarchy Quattro plugin.
USAGEBAR_PLUGIN_ID="${USAGEBAR_PLUGIN_ID:-akitaonrails.ai-usagebar}"
USAGEBAR_PLUGIN_URL="${USAGEBAR_PLUGIN_URL:-https://github.com/akitaonrails/ai-usagebar.git}"

setup_usagebar() {
    step "ai-usagebar (Fabio Akita)"

    if ! command -v omarchy >/dev/null 2>&1; then
        log "error: omarchy não está no PATH; não dá para instalar ai-usagebar" >&2
        exit 1
    fi

    log "binário (omarchy pkg aur add ai-usagebar-bin)"
    omarchy pkg aur add ai-usagebar-bin

    if omarchy plugin list --json 2>/dev/null | jq -e --arg id "$USAGEBAR_PLUGIN_ID" \
        'map(select(.id == $id)) | length > 0' >/dev/null; then
        ok "plugin já instalado: $USAGEBAR_PLUGIN_ID"
    else
        log "plugin (omarchy plugin add --enable --yes)"
        omarchy plugin add "$USAGEBAR_PLUGIN_URL" --enable --yes
        ok "plugin habilitado: $USAGEBAR_PLUGIN_ID"
    fi

    if ! command -v ai-usagebar >/dev/null 2>&1; then
        log "error: ai-usagebar não está no PATH após a instalação" >&2
        exit 1
    fi

    # Enable Cursor and make it the default provider in config.toml + bar widget.
    ai-usagebar settings enable cursor >/dev/null
    printf '%s\n' '{"schema_version":1,"primary":"cursor"}' | ai-usagebar settings apply >/dev/null
    omarchy bar set "$USAGEBAR_PLUGIN_ID" provider cursor >/dev/null
    ok "provider configurado: cursor"
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

THEME_NAME="${THEME_NAME:-matte-black}"

setup_appearance() {
    step "Fundo e unlock: Matte Black"

    if ! command -v omarchy >/dev/null 2>&1; then
        log "error: omarchy não está no PATH; não dá para aplicar tema" >&2
        exit 1
    fi

    local theme_dir bg current_bg current_plymouth shell_json
    theme_dir="$(omarchy theme dir "$THEME_NAME")"
    bg="$(find "$theme_dir/backgrounds" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        ! -name 'omarchy.png' | sort | head -n 1)"

    if [ -z "$bg" ]; then
        log "error: nenhum wallpaper em $theme_dir/backgrounds" >&2
        exit 1
    fi

    current_bg="$(readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null || true)"
    if [ "$current_bg" = "$(readlink -f "$bg")" ]; then
        ok "background já é Matte Black ($(basename "$bg"))"
    else
        omarchy theme bg set "$bg"
        ok "background: $(basename "$bg")"
    fi

    current_plymouth="$(omarchy plymouth current)"
    if [ "$current_plymouth" = "$THEME_NAME" ]; then
        ok "unlock já é Matte Black"
    else
        omarchy plymouth set by theme "$THEME_NAME"
        ok "unlock: Matte Black"
    fi

    shell_json="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
    if [ -f "$shell_json" ] && jq -e '.bar.transparent == true' "$shell_json" >/dev/null 2>&1; then
        ok "barra já transparente"
    else
        omarchy bar transparent true
        ok "barra transparente"
    fi
}

setup_meta_repo_pull() {
    step "Auto git pull do meta-repo (~/git) no login gráfico"

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

    systemctl --user daemon-reload
    systemctl --user enable workvm-git-pull.service
    ok "workvm-git-pull.service habilitado (ff-only origin/main em $GIT_ROOT)"
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
        # Omarchy wraps /usr/local/bin/mkinitcpio and prompts to run limine-mkinitcpio.
        sudo limine-mkinitcpio
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
    setup_remove_webapps
    setup_remove_packages
    setup_apps
    setup_chromium_google_account
    setup_usagebar
    setup_docker
    setup_clipboard
    setup_hypr_scrolling
    setup_appearance
    setup_meta_repo_pull
    setup_luks_autologin
    log ""
    log "VM base pronta. Próximo passo em uma VM clonada:"
    log "  $GIT_ROOT/project-setup.sh <projeto>"
    log "Se o grupo docker ainda não valer nesta sessão: newgrp docker"
    log "Nos próximos logins: workvm-git-pull.service faz git pull --ff-only origin/main em $GIT_ROOT"
}

main "$@"
