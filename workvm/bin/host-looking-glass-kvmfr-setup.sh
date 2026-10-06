#!/usr/bin/env bash
# Host: install kvmfr (Looking Glass) + udev + modprobe + modules-load.
# Usage: sudo ./workvm/bin/host-looking-glass-kvmfr-setup.sh
set -euo pipefail

SIZE_MB="${KVMFR_SIZE_MB:-128}"
USER_NAME="${SUDO_USER:-fabricio}"

log() { printf '%s\n' "$*"; }
ok() { log "✓ $*"; }
step() { log ""; log "==> $*"; }
die() { log "error: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "rode como root: sudo $0"

step "Pacotes"
if ! pacman -Q looking-glass-module-dkms >/dev/null 2>&1; then
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        log "→ instalando looking-glass-module-dkms via yay (como $SUDO_USER)"
        runuser -u "$SUDO_USER" -- yay -S --needed --noconfirm looking-glass-module-dkms \
            || die "falha no yay looking-glass-module-dkms"
    else
        die "instale: yay -S looking-glass-module-dkms"
    fi
fi
ok "looking-glass-module-dkms instalado"

if ! command -v looking-glass-client >/dev/null 2>&1; then
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        runuser -u "$SUDO_USER" -- yay -S --needed --noconfirm looking-glass \
            || die "falha no yay looking-glass"
    else
        die "instale: yay -S looking-glass"
    fi
fi
ok "looking-glass-client: $(command -v looking-glass-client)"

step "modprobe.d / modules-load (${SIZE_MB} MiB)"
printf 'options kvmfr static_size_mb=%s\n' "$SIZE_MB" >/etc/modprobe.d/kvmfr.conf
printf '%s\n' '# KVMFR Looking Glass module' 'kvmfr' >/etc/modules-load.d/kvmfr.conf
ok "/etc/modprobe.d/kvmfr.conf"

# Remove bogus regular file if QEMU created it
if [ -e /dev/kvmfr0 ] && [ ! -c /dev/kvmfr0 ]; then
    log "aviso: /dev/kvmfr0 não é char device — removendo arquivo espúrio"
    rm -f /dev/kvmfr0
fi

step "Carregar kvmfr"
modprobe -r kvmfr 2>/dev/null || true
modprobe kvmfr static_size_mb="$SIZE_MB"
sleep 0.3
[ -c /dev/kvmfr0 ] || die "/dev/kvmfr0 não apareceu"
ok "/dev/kvmfr0 existe"

step "udev + ownership"
cat >/etc/udev/rules.d/99-kvmfr.rules <<EOF
SUBSYSTEM=="kvmfr", OWNER="${USER_NAME}", GROUP="kvm", MODE="0660"
EOF
udevadm control --reload-rules
udevadm trigger -c add -s kvmfr 2>/dev/null || true
chown "${USER_NAME}:kvm" /dev/kvmfr0
chmod 660 /dev/kvmfr0
ok "/dev/kvmfr0 → ${USER_NAME}:kvm 660"

step "libvirt cgroup ACL (system; session também se usa qemu.conf)"
QEMU_CONF=/etc/libvirt/qemu.conf
if [ -f "$QEMU_CONF" ]; then
    if ! grep -q '/dev/kvmfr0' "$QEMU_CONF" 2>/dev/null; then
        log "aviso: adicione /dev/kvmfr0 em cgroup_device_acl em $QEMU_CONF se system VMs falharem"
        log "        (session qemu:///session costuma bastar com chown acima)"
    fi
fi

dmesg 2>/dev/null | grep -i kvmfr | tail -5 || true
ls -l /dev/kvmfr0

log ""
log "Próximo:"
log "  ./workvm/bin/vm-looking-glass-kvmfr-attach.sh teste-sr-iov"
log "  # guest: looking-glass-host"
log "  looking-glass-client -f /dev/kvmfr0"
