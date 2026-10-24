#!/usr/bin/env bash
# Libvirt rename (nomeDoProjeto-dop-24) does not change the guest hostname.
# The image stays jarvis-vm, so every VM looks the same on the site.
#
# Call from bin/workvm-libvirt-qemu-hook.sh on started/begin and restore/begin.
# That hook also publishes vid2agent-code. Do not point the libvirt hook at this file alone.
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

# Reload keeps the name Avahi already published. A restart reads the new hostname.
# sshd stays disabled after the openssh package install; enable it on each start.
pub_file="$(cd "$(dirname "$script_path")/.." && pwd)/lib/workvm_ed25519.pub"
ssh_fix="systemctl enable --now sshd"

if [ -f "$pub_file" ]; then
    pub=$(tr -d '\n' < "$pub_file")
    ssh_fix="${ssh_fix}; mkdir -p /home/fabricio/.ssh; touch /home/fabricio/.ssh/authorized_keys; grep -qxF '${pub}' /home/fabricio/.ssh/authorized_keys || printf '%s\n' '${pub}' >> /home/fabricio/.ssh/authorized_keys; chown -R fabricio:fabricio /home/fabricio/.ssh; chmod 700 /home/fabricio/.ssh; chmod 600 /home/fabricio/.ssh/authorized_keys"
fi

inner="hostnamectl set-hostname ${domain} && systemctl restart avahi-daemon.service; ${ssh_fix}"
escaped=$(printf '%s' "$inner" | sed 's/\\/\\\\/g; s/"/\\"/g')
payload=$(printf '{"execute":"guest-exec","arguments":{"path":"/bin/sh","arg":["-c","%s"],"capture-output":true}}' "$escaped")
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
