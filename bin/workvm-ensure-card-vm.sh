#!/usr/bin/env bash
# A card needs a VM named projeto-codigo. The site calls this on the host over SSH.
# If that domain exists, start it. Otherwise clone the shut-off project VM and start the copy.
# Usage: bin/workvm-ensure-card-vm.sh <modelo> <projeto-codigo>
set -euo pipefail

template=${1:-}
clone=${2:-}

name_ok() {
    printf '%s' "$1" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9-]{0,62}[A-Za-z0-9])?$'
}

if ! name_ok "$template" || ! name_ok "$clone"; then
    printf 'workvm-ensure-card-vm: nome inválido\n' >&2
    exit 1
fi

if [ "$template" = "$clone" ]; then
    printf 'workvm-ensure-card-vm: o clone não pode ter o nome da modelo\n' >&2
    exit 1
fi

virsh_bin=/usr/bin/virsh

if [ ! -x "$virsh_bin" ]; then
    virsh_bin=$(command -v virsh || true)
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

# User-mode NIC always looks like 10.0.2.15 inside the guest. That address is this VM
# from the site container, so the chat would SSH into the wrong machine.
publish_ssh() {
    local uri=$1
    local name=$2
    local kind hash port

    kind=$("$virsh_bin" -c "$uri" domiflist "$name" | awk 'NR > 2 && $2 != "" { print $2; exit }' || true)

    if [ "$kind" != "user" ]; then
        print_ip "$uri" "$name"
        printf 'port=22\n'
        return 0
    fi

    hash=$(printf '%s' "$name" | cksum | awk '{ print $1 }')
    port=$((22000 + hash % 1000))
    "$virsh_bin" -c "$uri" qemu-monitor-command "$name" --hmp "hostfwd_add hostnet0 tcp::${port}-:22" >/dev/null 2>&1 || true
    printf 'ip=192.168.122.1\n'
    printf 'port=%s\n' "$port"
}

print_ip() {
    local uri=$1
    local name=$2
    local source line ip

    for _ in $(seq 1 10); do
        for source in lease agent; do
            line=$("$virsh_bin" -c "$uri" domifaddr "$name" --source "$source" 2>/dev/null | awk '/ipv4/ { print $NF; exit }' || true)
            ip=${line%%/*}

            if printf '%s' "$ip" | grep -Eq '^[0-9]+(\.[0-9]+){3}$'; then
                printf 'ip=%s\n' "$ip"
                return 0
            fi
        done

        sleep 1
    done
}

start_if_needed() {
    local uri=$1
    local name=$2
    local state

    state=$("$virsh_bin" -c "$uri" domstate "$name")

    case "$state" in
        running|paused)
            printf '%s já está ligada\n' "$name"
            ;;
        "shut off")
            "$virsh_bin" -c "$uri" start "$name"
            printf '%s ligada\n' "$name"
            ;;
        *)
            printf 'workvm-ensure-card-vm: estado %s em %s\n' "$state" "$name" >&2
            return 1
            ;;
    esac
}

if uri=$(find_uri "$clone"); then
    start_if_needed "$uri" "$clone"
    publish_ssh "$uri" "$clone"
    exit 0
fi

if ! uri=$(find_uri "$template"); then
    printf 'workvm-ensure-card-vm: VM modelo ausente: %s\n' "$template" >&2
    exit 1
fi

state=$("$virsh_bin" -c "$uri" domstate "$template")

if [ "$state" != "shut off" ]; then
    printf 'workvm-ensure-card-vm: VM modelo ligada (%s). Desligue para clonar.\n' "$template" >&2
    exit 1
fi

virt_clone=$(command -v virt-clone || true)

if [ -z "$virt_clone" ]; then
    printf 'workvm-ensure-card-vm: virt-clone ausente no host\n' >&2
    exit 1
fi

"$virt_clone" --connect "$uri" --original "$template" --name "$clone" --auto-clone
"$virsh_bin" -c "$uri" start "$clone"
printf '%s clonada e ligada\n' "$clone"
publish_ssh "$uri" "$clone"
