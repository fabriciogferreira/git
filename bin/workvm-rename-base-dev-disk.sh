#!/usr/bin/env bash
# A domain já se chama base-dev; o disco ainda pode ser archlinux.qcow2
# (root). Este script renomeia o arquivo e atualiza o XML. VM precisa
# estar shut off. Uso: sudo -E bin/workvm-rename-base-dev-disk.sh
set -euo pipefail

URI="${WORKVM_LIBVIRT_URI:-qemu:///system}"
OLD_DISK=/var/lib/libvirt/images/archlinux.qcow2
NEW_DISK=/var/lib/libvirt/images/base-dev.qcow2
NAME=base-dev

if [ "$(id -u)" -ne 0 ]; then
    printf 'workvm-rename-base-dev-disk: rode como root (sudo -E)\n' >&2
    exit 1
fi

if ! virsh -c "$URI" dominfo "$NAME" >/dev/null 2>&1; then
    printf 'workvm-rename-base-dev-disk: domain %s ausente\n' "$NAME" >&2
    exit 1
fi

state=$(virsh -c "$URI" domstate "$NAME")
if [ "$state" != "shut off" ]; then
    printf 'workvm-rename-base-dev-disk: %s precisa estar shut off (agora: %s)\n' "$NAME" "$state" >&2
    exit 1
fi

if [ -f "$NEW_DISK" ] && [ ! -f "$OLD_DISK" ]; then
    printf 'disco já é %s\n' "$NEW_DISK"
    exit 0
fi

if [ ! -f "$OLD_DISK" ]; then
    printf 'workvm-rename-base-dev-disk: %s ausente\n' "$OLD_DISK" >&2
    exit 1
fi

TMP=$(mktemp)
virsh -c "$URI" dumpxml "$NAME" >"$TMP"
sed -i "s|$OLD_DISK|$NEW_DISK|g" "$TMP"
mv "$OLD_DISK" "$NEW_DISK"
virsh -c "$URI" undefine "$NAME"
virsh -c "$URI" define "$TMP"
rm -f "$TMP"
printf 'disco → %s; domain %s ok\n' "$NEW_DISK" "$NAME"
