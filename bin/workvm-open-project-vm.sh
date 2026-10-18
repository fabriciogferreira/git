#!/usr/bin/env bash
# A project without cards still has its own VM. Start that domain and publish SSH.
# Do not clone. Card clones stay in workvm-ensure-card-vm.sh.
# Usage: bin/workvm-open-project-vm.sh <nome>
set -euo pipefail

name=${1:-}

name_ok() {
    printf '%s' "$1" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9-]{0,62}[A-Za-z0-9])?$'
}

if ! name_ok "$name"; then
    printf 'workvm-open-project-vm: nome inválido\n' >&2
    exit 1
fi

virsh_bin=/usr/bin/virsh

if [ ! -x "$virsh_bin" ]; then
    virsh_bin=$(command -v virsh || true)
fi

if [ -z "$virsh_bin" ]; then
    printf 'workvm-open-project-vm: virsh ausente no host\n' >&2
    exit 1
fi

find_uri() {
    local domain=$1
    local uri

    for uri in qemu:///system qemu:///session; do
        if "$virsh_bin" -c "$uri" dominfo "$domain" >/dev/null 2>&1; then
            printf '%s\n' "$uri"
            return 0
        fi
    done

    return 1
}

print_ip() {
    local uri=$1
    local domain=$2
    local source line ip

    for _ in $(seq 1 10); do
        for source in lease agent; do
            line=$("$virsh_bin" -c "$uri" domifaddr "$domain" --source "$source" 2>/dev/null | awk '/ipv4/ { print $NF; exit }' || true)
            ip=${line%%/*}

            if printf '%s' "$ip" | grep -Eq '^[0-9]+(\.[0-9]+){3}$'; then
                printf 'ip=%s\n' "$ip"
                return 0
            fi
        done

        sleep 1
    done
}

# User-mode NIC always looks like 10.0.2.15. From the site container that is the Opbed VM.
publish_ssh() {
    local uri=$1
    local domain=$2
    local kind hash port

    kind=$("$virsh_bin" -c "$uri" domiflist "$domain" | awk 'NR > 2 && $2 != "" { print $2; exit }' || true)

    if [ "$kind" != "user" ]; then
        print_ip "$uri" "$domain"
        printf 'port=22\n'
        return 0
    fi

    hash=$(printf '%s' "$domain" | cksum | awk '{ print $1 }')
    port=$((22000 + hash % 1000))
    "$virsh_bin" -c "$uri" qemu-monitor-command "$domain" --hmp "hostfwd_add hostnet0 tcp::${port}-:22" >/dev/null 2>&1 || true
    printf 'ip=192.168.122.1\n'
    printf 'port=%s\n' "$port"
}

if ! uri=$(find_uri "$name"); then
    printf 'workvm-open-project-vm: VM ausente: %s\n' "$name" >&2
    exit 1
fi

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
        printf 'workvm-open-project-vm: estado %s em %s\n' "$state" "$name" >&2
        exit 1
        ;;
esac

publish_ssh "$uri" "$name"
