#!/usr/bin/env bash
# Guest: install Looking Glass Linux host (experimental) for IVSHMEM capture.
# Run inside the VM after vm-looking-glass-attach.sh on the hypervisor.
# Usage: sudo ./workvm/bin/guest-looking-glass-setup.sh
set -euo pipefail

log() { printf '%s\n' "$*"; }
ok() { log "✓ $*"; }
step() { log ""; log "==> $*"; }
die() { log "error: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "rode como root (sudo $0)"

step "Aviso"
log "Looking Glass host no Linux é experimental (https://looking-glass.io/docs/B7/install_host/)."
log "Se não ficar estável, alternativa fluida: Sunshine/Moonlight com VAAPI na VF."

step "Dependências"
if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
    die "instale yay/paru no guest ou compile looking-glass-host do AUR manualmente"
fi

AUR="${AUR_HELPER:-}"
if [ -z "$AUR" ]; then
    command -v yay >/dev/null && AUR=yay || AUR=paru
fi

# looking-glass-host-git provides the Linux capture binary (PipeWire).
# looking-glass-module-dkms: useful for VM↔VM; with libvirt ivshmem-plain the
# host app usually talks to the PCI IVSHMEM / uio device.
"$AUR" -S --needed --noconfirm looking-glass-host-git 2>&1 || \
    "$AUR" -S --needed --noconfirm looking-glass-rc-host 2>&1 || \
    die "falha ao instalar looking-glass-host (AUR)"

if command -v looking-glass-host >/dev/null 2>&1; then
    ok "looking-glass-host: $(command -v looking-glass-host)"
else
    # some packages install with versioned name
    lg="$(command -v looking-glass-host-bin 2>/dev/null || true)"
    [ -n "$lg" ] || die "binário looking-glass-host não encontrado no PATH"
    ok "host binary: $lg"
fi

step "PipeWire / portal (Hyprland)"
pacman -S --needed --noconfirm pipewire pipewire-pulse wireplumber xdg-desktop-portal-hyprland \
    2>/dev/null || pacman -S --needed --noconfirm pipewire wireplumber xdg-desktop-portal-wlr || true

step "IVSHMEM no guest"
if lspci | grep -qi ivshmem; then
    ok "dispositivo IVSHMEM visível:"
    lspci | grep -i ivshmem || true
else
    log "aviso: lspci sem 'ivshmem' — confira shmem na domain XML do host"
fi

log ""
log "Uso (sessão gráfica do guest, usuário normal):"
log "  looking-glass-host"
log "No hypervisor:"
log "  looking-glass-client -f /dev/shm/looking-glass"
log ""
log "Mantenha Virtio/SPICE só para emergência; o viewer fluido é o client LG."
