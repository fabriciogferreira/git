#!/usr/bin/env bash
# Host-side Intel iGPU SR-IOV setup (Omarchy + Limine + QEMU/KVM).
# Usage: sudo ./workvm/bin/host-igpu-sriov-setup.sh [--skip-dkms] [--skip-limine] [--no-enable]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKVM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LIMINE_SRC="$WORKVM_ROOT/host/limine-entry-tool.d/i915-sriov.conf"
LIMINE_DST="/etc/limine-entry-tool.d/i915-sriov.conf"
UNIT_SRC="$WORKVM_ROOT/host/systemd/workvm-igpu-sriov.service"
UNIT_DST="/etc/systemd/system/workvm-igpu-sriov.service"

PF="${SRIOV_PF:-0000:00:02.0}"
NUMVFS="${SRIOV_NUMVFS:-4}"
DKMS_REPO="${I915_SRIOV_DKMS_REPO:-https://github.com/strongtz/i915-sriov-dkms.git}"
DKMS_DIR="${I915_SRIOV_DKMS_DIR:-/usr/src/i915-sriov-dkms}"

SKIP_DKMS=0
SKIP_LIMINE=0
NO_ENABLE=0

log() { printf '%s\n' "$*"; }
ok() { log "✓ $*"; }
step() { log ""; log "==> $*"; }
die() { log "error: $*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: sudo $0 [options]

Options:
  --skip-dkms     Não clona/instala i915-sriov-dkms
  --skip-limine   Não copia drop-in nem roda limine-update
  --no-enable     Instala a unit mas não faz enable/start
  -h, --help      Esta ajuda

Env:
  SRIOV_PF          PCI BDF do PF (default: 0000:00:02.0)
  SRIOV_NUMVFS      Quantidade de VFs (default: 4)
  I915_SRIOV_DKMS_REPO / I915_SRIOV_DKMS_DIR
EOF
}

for arg in "$@"; do
    case "$arg" in
        --skip-dkms) SKIP_DKMS=1 ;;
        --skip-limine) SKIP_LIMINE=1 ;;
        --no-enable) NO_ENABLE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "opção desconhecida: $arg" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || die "rode como root (sudo $0)"

install_limine_dropin() {
    step "Limine drop-in i915 SR-IOV"

    [ -f "$LIMINE_SRC" ] || die "faltando $LIMINE_SRC"
    mkdir -p /etc/limine-entry-tool.d
    install -m 644 "$LIMINE_SRC" "$LIMINE_DST"
    ok "instalado: $LIMINE_DST"
}

# Rebuild UKI/initramfs AFTER DKMS so the patched i915 is embedded (kms hook).
rebuild_boot() {
    step "Rebuild Limine UKI (após DKMS)"

    if command -v limine-update >/dev/null 2>&1; then
        limine-update
        ok "limine-update ok"
    else
        log "aviso: limine-update não encontrado; rode mkinitcpio -P manualmente"
    fi

    if ! grep -q 'i915.max_vfs=7' /proc/cmdline 2>/dev/null \
        || ! grep -q 'module_blacklist=xe' /proc/cmdline 2>/dev/null; then
        log "aviso: cmdline atual incompleta — reboot necessário"
        log "        esperado: i915.enable_guc=3 i915.max_vfs=7 module_blacklist=xe"
    else
        ok "cmdline já contém params i915 SR-IOV + blacklist xe"
    fi

    local live src
    live="$(cat /sys/module/i915/srcversion 2>/dev/null || true)"
    src="$(modinfo -F srcversion i915 2>/dev/null || true)"
    if [ -n "$live" ] && [ -n "$src" ] && [ "$live" != "$src" ]; then
        log "aviso: i915 em memória ($live) ≠ disco DKMS ($src) — reboot para carregar o módulo patched"
    fi
}

install_dkms() {
    step "DKMS i915-sriov"

    if ! command -v dkms >/dev/null 2>&1; then
        die "dkms não instalado (pacman -S dkms)"
    fi

    local headers_pkg="linux-omarchy-headers"
    if ! pacman -Q "$headers_pkg" >/dev/null 2>&1; then
        die "instale headers do kernel: pacman -S $headers_pkg"
    fi

    if dkms status 2>/dev/null | grep -qi 'i915-sriov'; then
        ok "DKMS i915-sriov já registrado:"
        dkms status | grep -i i915-sriov || true
        return 0
    fi

    if [ ! -d "$DKMS_DIR/.git" ] && [ ! -f "$DKMS_DIR/dkms.conf" ]; then
        log "→ clonando $DKMS_REPO → $DKMS_DIR"
        rm -rf "$DKMS_DIR"
        git clone --depth 1 "$DKMS_REPO" "$DKMS_DIR"
    else
        ok "fonte DKMS já em $DKMS_DIR"
    fi

    [ -f "$DKMS_DIR/dkms.conf" ] || die "dkms.conf não encontrado em $DKMS_DIR"

    local pkg_name pkg_ver
    pkg_name="$(sed -n 's/^PACKAGE_NAME="\(.*\)"/\1/p' "$DKMS_DIR/dkms.conf" | head -1)"
    pkg_ver="$(sed -n 's/^PACKAGE_VERSION="\(.*\)"/\1/p' "$DKMS_DIR/dkms.conf" | head -1)"
    [ -n "$pkg_name" ] && [ -n "$pkg_ver" ] || die "não li PACKAGE_NAME/VERSION de dkms.conf"

    local src_link="/usr/src/${pkg_name}-${pkg_ver}"
    if [ ! -e "$src_link" ]; then
        ln -sfn "$DKMS_DIR" "$src_link"
    fi

    log "→ dkms add/install ${pkg_name}/${pkg_ver} -k $(uname -r)"
    dkms add -m "$pkg_name" -v "$pkg_ver" 2>/dev/null || true
    dkms install -m "$pkg_name" -v "$pkg_ver" -k "$(uname -r)"
    ok "DKMS instalado para $(uname -r)"
    dkms status | grep -i "$pkg_name" || true
}

install_unit() {
    step "systemd unit (sriov_numvfs=${NUMVFS})"

    [ -f "$UNIT_SRC" ] || die "faltando $UNIT_SRC"
    install -m 644 "$UNIT_SRC" "$UNIT_DST"

    # Bake PF/NUMVFS into a drop-in so defaults match this host.
    local drop_in="/etc/systemd/system/workvm-igpu-sriov.service.d/override.conf"
    mkdir -p "$(dirname "$drop_in")"
    cat >"$drop_in" <<EOF
[Service]
Environment=SRIOV_NUMVFS=${NUMVFS}
Environment=SRIOV_PF=${PF}
EOF
    ok "unit: $UNIT_DST (PF=$PF NUMVFS=$NUMVFS)"

    systemctl daemon-reload

    if [ "$NO_ENABLE" -eq 1 ]; then
        log "pulado: enable/start (--no-enable)"
        return 0
    fi

    systemctl enable workvm-igpu-sriov.service

    local numvfs_path="/sys/bus/pci/devices/${PF}/sriov_numvfs"
    if [ ! -e "$numvfs_path" ]; then
        log "aviso: $numvfs_path ausente — unit habilitada; start após reboot/DKMS"
        return 0
    fi

    if grep -q 'i915.max_vfs' /proc/cmdline 2>/dev/null || [ "${FORCE_START_VFS:-0}" = "1" ]; then
        if systemctl start workvm-igpu-sriov.service; then
            ok "VFs ativas: $(cat "$numvfs_path")"
        else
            log "aviso: falha ao start da unit (cmdline/DKMS incompletos?). Veja: journalctl -u workvm-igpu-sriov.service"
        fi
    else
        log "aviso: cmdline sem i915.max_vfs — unit habilitada; reboot antes de start"
    fi
}

verify() {
    step "Checks"

    local totalvfs_path="/sys/bus/pci/devices/${PF}/sriov_totalvfs"
    local numvfs_path="/sys/bus/pci/devices/${PF}/sriov_numvfs"

    if [ -e "$totalvfs_path" ]; then
        ok "sriov_totalvfs=$(cat "$totalvfs_path") (PF $PF)"
    else
        log "aviso: sem sriov_totalvfs em $PF"
    fi

    if [ -e "$numvfs_path" ]; then
        ok "sriov_numvfs=$(cat "$numvfs_path")"
    fi

    log "→ lspci (VGA/Display):"
    lspci -nn | grep -iE 'vga|display' || true

    log "→ cmdline i915/iommu:"
    tr ' ' '\n' </proc/cmdline | grep -E 'iommu|i915' || log "(nenhum match)"

    if command -v dkms >/dev/null 2>&1; then
        log "→ dkms status (i915):"
        dkms status 2>/dev/null | grep -i i915 || log "(nenhum módulo i915-sriov)"
    fi

    log ""
    log "Próximos passos:"
    log "  1. Se acabou de instalar limine/DKMS: reboot"
    log "  2. Após reboot: sudo systemctl start workvm-igpu-sriov.service"
    log "  3. Validar: lspci -nn | grep -i display"
    log "  4. Passo 2: anexar 1 VF à VM teste-sr-iov"
    log "Doc: $WORKVM_ROOT/docs/igpu-sriov.md"
}

main() {
    log "host-igpu-sriov-setup.sh — PF=$PF NUMVFS=$NUMVFS"
    log "repo: $REPO_ROOT"

    [ "$SKIP_LIMINE" -eq 0 ] && install_limine_dropin || log "==> Limine pulado (--skip-limine)"
    [ "$SKIP_DKMS" -eq 0 ] && install_dkms || log "==> DKMS pulado (--skip-dkms)"
    # UKI must be rebuilt after DKMS so initramfs embeds the patched i915.
    [ "$SKIP_LIMINE" -eq 0 ] && rebuild_boot
    install_unit
    verify
}

main
