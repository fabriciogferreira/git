#!/usr/bin/env bash
# Bind Intel iGPU VFs to vfio-pci and open /dev/vfio/<group> for the kvm group.
# Run as root after workvm-igpu-sriov.service has created the VFs.
# Usage: sudo ./workvm/bin/host-igpu-vfio-bind.sh [numvfs]
set -euo pipefail

PF="${SRIOV_PF:-0000:00:02.0}"
NUMVFS="${1:-${SRIOV_NUMVFS:-4}}"
VFIO_GROUP="${VFIO_GROUP:-kvm}"

log() { printf '%s\n' "$*"; }
ok() { log "✓ $*"; }
die() { log "error: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "rode como root"

modprobe vfio-pci

numvfs_path="/sys/bus/pci/devices/${PF}/sriov_numvfs"
[ -e "$numvfs_path" ] || die "PF $PF sem sriov_numvfs (DKMS/unit ok?)"

current="$(cat "$numvfs_path")"
if [ "$current" -lt 1 ]; then
    log "→ criando $NUMVFS VFs em $PF"
    echo "$NUMVFS" >"$numvfs_path"
fi

# VFs are typically PF function+1 .. function+N (00:02.1 ..)
pf_bus="$(echo "$PF" | cut -d: -f1-2)" # 0000:00
pf_slot_func="$(echo "$PF" | cut -d: -f3)" # 02.0
pf_slot="${pf_slot_func%.*}"
base_fn="${pf_slot_func#*.}"

bound=0
for ((i = 1; i <= NUMVFS; i++)); do
    fn=$((base_fn + i))
    dev=$(printf '%s:%s.%x' "$pf_bus" "$pf_slot" "$fn")
    sys="/sys/bus/pci/devices/${dev}"
    [ -d "$sys" ] || { log "aviso: $dev não existe"; continue; }

    driver=""
    if [ -L "$sys/driver" ]; then
        driver="$(basename "$(readlink -f "$sys/driver")")"
    fi

    if [ "$driver" = "vfio-pci" ]; then
        ok "$dev já em vfio-pci"
    else
        log "→ bind $dev → vfio-pci (era: ${driver:-none})"
        echo vfio-pci >"$sys/driver_override"
        if [ -n "$driver" ]; then
            echo "$dev" >"$sys/driver/unbind"
        fi
        # Newly unbound devices need to be probed onto vfio-pci
        if [ -e /sys/bus/pci/drivers/vfio-pci/bind ]; then
            echo "$dev" >/sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null \
                || echo "$dev" >/sys/bus/pci/drivers_probe
        else
            echo "$dev" >/sys/bus/pci/drivers_probe
        fi
        sleep 0.2
        driver2=""
        [ -L "$sys/driver" ] && driver2="$(basename "$(readlink -f "$sys/driver")")"
        [ "$driver2" = "vfio-pci" ] || die "falha ao bindar $dev (driver=$driver2)"
        ok "$dev em vfio-pci"
    fi

    group="$(basename "$(readlink -f "$sys/iommu_group")")"
    node="/dev/vfio/${group}"
    if [ -e "$node" ]; then
        chown "root:${VFIO_GROUP}" "$node"
        chmod 660 "$node"
        ok "$node → root:${VFIO_GROUP} 660"
    else
        log "aviso: $node ainda não existe"
    fi
    bound=$((bound + 1))
done

log ""
log "VFs em vfio-pci: $bound"
log "Para session libvirt use hostdev managed='no' (já esperado em teste-sr-iov)."
lspci -nnk -s 00:02 | sed -n '1,40p'
