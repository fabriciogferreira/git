#!/usr/bin/env bash
# Guest-side Intel iGPU VF setup (Omarchy/Arch + Limine or GRUB).
# Installs i915-sriov-dkms and cmdline: i915.enable_guc=3 module_blacklist=xe
# Run inside the VM after the host has passed through one VF.
# Usage: sudo ./workvm/bin/guest-igpu-sriov-setup.sh [--skip-dkms] [--skip-cmdline]
set -euo pipefail

WORKVM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LIMINE_SRC="$WORKVM_ROOT/guest/limine-entry-tool.d/i915-sriov-guest.conf"
LIMINE_DST="/etc/limine-entry-tool.d/i915-sriov-guest.conf"
GUEST_CMDLINE_PARAMS='i915.enable_guc=3 module_blacklist=xe'

DKMS_REPO="${I915_SRIOV_DKMS_REPO:-https://github.com/strongtz/i915-sriov-dkms.git}"
DKMS_DIR="${I915_SRIOV_DKMS_DIR:-/usr/src/i915-sriov-dkms}"

SKIP_DKMS=0
SKIP_CMDLINE=0

log() { printf '%s\n' "$*"; }
ok() { log "✓ $*"; }
step() { log ""; log "==> $*"; }
die() { log "error: $*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: sudo $0 [options]

Instala o DKMS i915-sriov no guest e a cmdline de VF
($GUEST_CMDLINE_PARAMS). Sem i915.max_vfs (só no host/PF).

Options:
  --skip-dkms      Não clona/instala i915-sriov-dkms
  --skip-cmdline   Não altera Limine/GRUB
  -h, --help       Esta ajuda

Env:
  I915_SRIOV_DKMS_REPO / I915_SRIOV_DKMS_DIR
EOF
}

for arg in "$@"; do
    case "$arg" in
        --skip-dkms) SKIP_DKMS=1 ;;
        --skip-cmdline) SKIP_CMDLINE=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "opção desconhecida: $arg" ;;
    esac
done

[ "$(id -u)" -eq 0 ] || die "rode como root (sudo $0)"

require_intel_vf() {
    step "Detectar Intel VF no guest"

    if ! lspci -nn 2>/dev/null | grep -qiE '8086:a7[0-9a-f]{2}|UHD Graphics|Intel.*Graphics'; then
        die "nenhuma GPU Intel vista no guest — passe 1 VF no host antes (ex.: 00:02.1)"
    fi

    log "→ GPUs:"
    lspci -nnk | grep -A3 -iE 'vga|display' || true

    if lspci -nnk 2>/dev/null | grep -A3 -i '8086:a7' | grep -q 'Kernel driver in use: i915'; then
        ok "i915 já em uso na VF"
    else
        log "aviso: VF presente mas i915 ainda não está bound (esperado antes do DKMS/reboot)"
    fi
}

detect_headers_pkg() {
    local kver
    kver="$(uname -r)"
    if [[ "$kver" == *omarchy* ]]; then
        echo "linux-omarchy-headers"
        return
    fi
    if pacman -Ss "^linux-headers$" >/dev/null 2>&1 && pacman -Q linux >/dev/null 2>&1; then
        echo "linux-headers"
        return
    fi
    # fallback: try matching installed kernel package
    if pacman -Qq | grep -qx 'linux-omarchy'; then
        echo "linux-omarchy-headers"
        return
    fi
    echo "linux-headers"
}

install_dkms() {
    step "DKMS i915-sriov (guest)"

    if ! command -v dkms >/dev/null 2>&1; then
        log "→ instalando dkms"
        pacman -S --needed --noconfirm dkms git base-devel
    fi

    local headers_pkg
    headers_pkg="$(detect_headers_pkg)"
    if ! pacman -Q "$headers_pkg" >/dev/null 2>&1; then
        log "→ instalando $headers_pkg"
        pacman -S --needed --noconfirm "$headers_pkg"
    fi
    ok "headers: $headers_pkg ($(uname -r))"

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

install_cmdline_limine() {
    [ -f "$LIMINE_SRC" ] || die "faltando $LIMINE_SRC"
    mkdir -p /etc/limine-entry-tool.d
    install -m 644 "$LIMINE_SRC" "$LIMINE_DST"
    ok "drop-in: $LIMINE_DST"

    if command -v limine-update >/dev/null 2>&1; then
        limine-update
        ok "limine-update ok"
    else
        log "aviso: limine-update não encontrado"
    fi
}

install_cmdline_grub() {
    local grub_default="/etc/default/grub"
    [ -f "$grub_default" ] || die "nem Limine nem $grub_default encontrados"

    if grep -q 'i915.enable_guc=3' "$grub_default" \
        && grep -q 'module_blacklist=xe' "$grub_default"; then
        ok "GRUB já contém params de guest VF"
    else
        # Append to GRUB_CMDLINE_LINUX_DEFAULT if missing
        if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$grub_default"; then
            sed -i \
                -e 's/^GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 '"$GUEST_CMDLINE_PARAMS"'"/' \
                "$grub_default"
            # de-dupe crude: collapse double spaces
            sed -i 's/  */ /g' "$grub_default"
            ok "params anexados em $grub_default"
        else
            echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$GUEST_CMDLINE_PARAMS\"" >>"$grub_default"
            ok "GRUB_CMDLINE_LINUX_DEFAULT criado"
        fi
    fi

    if command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg
        ok "grub-mkconfig ok"
    elif command -v update-grub >/dev/null 2>&1; then
        update-grub
        ok "update-grub ok"
    else
        log "aviso: rode grub-mkconfig manualmente"
    fi
}

install_cmdline() {
    step "Cmdline guest VF ($GUEST_CMDLINE_PARAMS)"

    if [ -d /etc/limine-entry-tool.d ] || command -v limine-update >/dev/null 2>&1; then
        install_cmdline_limine
    elif [ -f /etc/default/grub ]; then
        install_cmdline_grub
    else
        die "não achei Limine nem GRUB — adicione manualmente: $GUEST_CMDLINE_PARAMS"
    fi

    # Rebuild initramfs after DKMS when possible (same pitfall as host)
    if command -v limine-update >/dev/null 2>&1; then
        :
    elif command -v mkinitcpio >/dev/null 2>&1; then
        mkinitcpio -P
        ok "mkinitcpio -P ok"
    fi

    if grep -q 'i915.enable_guc=3' /proc/cmdline 2>/dev/null \
        && grep -q 'module_blacklist=xe' /proc/cmdline 2>/dev/null; then
        ok "cmdline atual já tem params de guest"
    else
        log "aviso: cmdline atual ainda sem params — reboot necessário"
    fi
}

verify() {
    step "Checks"

    log "→ lspci Intel / driver:"
    lspci -nnk | grep -A4 -iE '8086:a7|UHD Graphics|Intel.*Graphics' || true

    log "→ cmdline i915:"
    tr ' ' '\n' </proc/cmdline | grep -E 'i915|blacklist=xe' || log "(nenhum match — reboot)"

    if command -v dkms >/dev/null 2>&1; then
        log "→ dkms status:"
        dkms status 2>/dev/null | grep -i i915 || log "(nenhum)"
    fi

    local live src
    live="$(cat /sys/module/i915/srcversion 2>/dev/null || true)"
    src="$(modinfo -F srcversion i915 2>/dev/null || true)"
    if [ -n "$live" ] && [ -n "$src" ]; then
        if [ "$live" = "$src" ]; then
            ok "i915 em memória = DKMS ($live)"
        else
            log "aviso: i915 live ($live) ≠ disco ($src) — reboot"
        fi
    fi

    log ""
    log "Próximos passos:"
    log "  1. reboot da VM"
    log "  2. lspci -nnk -s 07:00.0   # Kernel driver in use: i915"
    log "  3. dmesg | grep -i i915"
    log "  4. (opcional) remover/despriorizar Virtio GPU se Hyprland ainda usar virtio"
    log "Doc: $WORKVM_ROOT/docs/igpu-sriov.md"
}

main() {
    log "guest-igpu-sriov-setup.sh — $(uname -r)"
    require_intel_vf
    [ "$SKIP_DKMS" -eq 0 ] && install_dkms || log "==> DKMS pulado"
    [ "$SKIP_CMDLINE" -eq 0 ] && install_cmdline || log "==> cmdline pulada"
    # Limine UKI must include DKMS i915 — rebuild again after dkms if limine
    if [ "$SKIP_CMDLINE" -eq 0 ] && [ "$SKIP_DKMS" -eq 0 ] && command -v limine-update >/dev/null 2>&1; then
        step "Rebuild Limine UKI (pós-DKMS)"
        limine-update
        ok "limine-update (pós-DKMS) ok"
    fi
    verify
}

main
