#!/usr/bin/env bash
# The card VM keeps running after the chat. Pause should power it off
# without deleting the clone, so the next Conectar starts the same domain.
# Usage: bin/workvm-shutdown-card-vm.sh <modelo> <projeto-codigo>
set -euo pipefail

template=${1:-}
clone=${2:-}

name_ok() {
    printf '%s' "$1" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9-]{0,62}[A-Za-z0-9])?$'
}

if ! name_ok "$template" || ! name_ok "$clone"; then
    printf 'workvm-shutdown-card-vm: nome inválido\n' >&2
    exit 1
fi

case "$clone" in
    "$template"-*) ;;
    *)
        printf 'workvm-shutdown-card-vm: o clone não pertence à modelo\n' >&2
        exit 1
        ;;
esac

virsh_bin=/usr/bin/virsh

if [ ! -x "$virsh_bin" ]; then
    virsh_bin=$(command -v virsh || true)
fi

if [ -z "$virsh_bin" ]; then
    printf 'workvm-shutdown-card-vm: virsh ausente no host\n' >&2
    exit 1
fi

find_uri() {
    local name=$1
    local uri

    for uri in qemu:///system qemu:///session; do
        if "$virsh_bin" -c "$uri" dominfo "$name" >/dev/null 2>&1; then
            printf '%s\n' "$uri"
            return 0
        fi
    done

    return 1
}

if ! uri=$(find_uri "$clone"); then
    printf '%s desligada\n' "$clone"
    exit 0
fi

state=$("$virsh_bin" -c "$uri" domstate "$clone")

if [ "$state" = "shut off" ]; then
    printf '%s desligada\n' "$clone"
    exit 0
fi

# A libvirt pause does not power off. Destroy leaves the domain and its disks.
if [ "$state" = "paused" ]; then
    "$virsh_bin" -c "$uri" destroy "$clone"
    printf '%s desligada\n' "$clone"
    exit 0
fi

"$virsh_bin" -c "$uri" shutdown "$clone" >/dev/null

for _ in $(seq 1 20); do
    state=$("$virsh_bin" -c "$uri" domstate "$clone")

    if [ "$state" = "shut off" ]; then
        printf '%s desligada\n' "$clone"
        exit 0
    fi

    sleep 2
done

# ACPI shutdown can hang. Destroy stops the guest and keeps the clone.
"$virsh_bin" -c "$uri" destroy "$clone"
printf '%s desligada\n' "$clone"
