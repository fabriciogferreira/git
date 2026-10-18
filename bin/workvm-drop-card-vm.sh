#!/usr/bin/env bash
# Dropping a card finishes the work. Remove the clone domain projeto-codigo
# and its own disks. The template VM is not destroyed.
# Usage: bin/workvm-drop-card-vm.sh <modelo> <projeto-codigo>
set -euo pipefail

template=${1:-}
clone=${2:-}

name_ok() {
    printf '%s' "$1" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9-]{0,62}[A-Za-z0-9])?$'
}

if ! name_ok "$template" || ! name_ok "$clone"; then
    printf 'workvm-drop-card-vm: nome inválido\n' >&2
    exit 1
fi

case "$clone" in
    "$template"-*) ;;
    *)
        printf 'workvm-drop-card-vm: o clone não pertence à modelo\n' >&2
        exit 1
        ;;
esac

virsh_bin=/usr/bin/virsh

if [ ! -x "$virsh_bin" ]; then
    virsh_bin=$(command -v virsh || true)
fi

if [ -z "$virsh_bin" ]; then
    printf 'workvm-drop-card-vm: virsh ausente no host\n' >&2
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

disk_paths() {
    local uri=$1
    local name=$2

    "$virsh_bin" -c "$uri" domblklist "$name" --details 2>/dev/null \
        | awk 'NR > 2 && $NF ~ /^\// { print $NF }'
}

if ! uri=$(find_uri "$clone"); then
    printf '%s já ausente\n' "$clone"
    exit 0
fi

if template_uri=$(find_uri "$template"); then
    clone_disks=$(disk_paths "$uri" "$clone")
    template_disks=$(disk_paths "$template_uri" "$template")

    while IFS= read -r path; do
        if [ -z "$path" ]; then
            continue
        fi

        if printf '%s\n' "$template_disks" | grep -Fxq -- "$path"; then
            printf 'workvm-drop-card-vm: disco do clone é o da modelo (%s)\n' "$path" >&2
            exit 1
        fi
    done <<EOF
$clone_disks
EOF
fi

state=$("$virsh_bin" -c "$uri" domstate "$clone")

if [ "$state" != "shut off" ]; then
    "$virsh_bin" -c "$uri" destroy "$clone"
fi

"$virsh_bin" -c "$uri" undefine "$clone" --remove-all-storage --managed-save --snapshots-metadata --nvram
printf '%s apagada\n' "$clone"
