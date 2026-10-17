#!/usr/bin/env bash
# Libvirt rename (nomeDoProjeto-dop-24) does not change the guest hostname.
# The image stays jarvis-vm, so every VM looks the same on the site.
#
# Call from the host qemu hook on started/begin and restore/begin.
# Do not replace ~/.config/libvirt/hooks/qemu: that hook also starts Ollama.
# Add: bin/workvm-set-guest-hostname.sh "$1" "$2" "$3"
#
# Direct: bin/workvm-set-guest-hostname.sh nomeDoProjeto-dop-24
set -euo pipefail

script_path=$(readlink -f "$0")

if [ "$#" -ge 3 ]; then
    operation=$2
    phase=$3

    if [ "$phase" = "begin" ] && { [ "$operation" = "started" ] || [ "$operation" = "restore" ]; }; then
        "$script_path" "$1" >/dev/null 2>&1 &
    fi

    exit 0
fi

domain=${1:-}

if ! printf '%s' "$domain" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9-]{0,62}[A-Za-z0-9])?$'; then
    printf 'workvm-set-guest-hostname: nome inválido: %s\n' "$domain" >&2
    exit 0
fi

virsh_bin=/usr/bin/virsh
virsh_uri=""
last_err=""

if [ ! -x "$virsh_bin" ]; then
    virsh_bin=$(command -v virsh || true)
fi

virsh_agent() {
    if [ -n "$virsh_uri" ]; then
        "$virsh_bin" -c "$virsh_uri" qemu-agent-command "$domain" "$1"
    else
        "$virsh_bin" qemu-agent-command "$domain" "$1"
    fi
}

# opbed is often qemu:///system; the default virsh URI is session.
pick_uri() {
    local uri err

    for uri in "" qemu:///system qemu:///session; do
        if [ -n "$uri" ]; then
            if err=$("$virsh_bin" -c "$uri" qemu-agent-command "$domain" '{"execute":"guest-ping"}' 2>&1); then
                virsh_uri=$uri
                return 0
            fi
        elif err=$("$virsh_bin" qemu-agent-command "$domain" '{"execute":"guest-ping"}' 2>&1); then
            virsh_uri=""
            return 0
        fi

        last_err=$err
    done

    return 1
}

for _ in $(seq 1 30); do
    if pick_uri; then
        break
    fi

    sleep 2
done

if ! pick_uri; then
    printf 'workvm-set-guest-hostname: agente ausente em %s (%s)\n' "$domain" "$last_err" >&2
    exit 0
fi

payload=$(printf '{"execute":"guest-exec","arguments":{"path":"/bin/sh","arg":["-c","hostnamectl set-hostname %s && systemctl try-reload-or-restart avahi-daemon.service"],"capture-output":true}}' "$domain")
response=$(virsh_agent "$payload")
pid=$(printf '%s' "$response" | grep -o '"pid"[[:space:]]*:[[:space:]]*[0-9][0-9]*' | grep -o '[0-9][0-9]*$')

if [ -z "$pid" ]; then
    printf 'workvm-set-guest-hostname: guest-exec sem pid em %s\n' "$domain" >&2
    exit 0
fi

for _ in $(seq 1 20); do
    status=$(virsh_agent "$(printf '{"execute":"guest-exec-status","arguments":{"pid":%s}}' "$pid")")

    if printf '%s' "$status" | grep -q '"exited"[[:space:]]*:[[:space:]]*true'; then
        exit 0
    fi

    sleep 0.5
done

printf 'workvm-set-guest-hostname: hostnamectl não terminou em %s\n' "$domain" >&2
exit 0
