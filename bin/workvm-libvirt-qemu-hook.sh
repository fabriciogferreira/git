#!/usr/bin/env bash
# Session libvirt has no hook, so a VM start does not copy the guest hostname
# and vid2agent-code does not publish its API or start Ollama.
# libvirt 12.8 only reads /etc/libvirt/hooks/qemu, including the session daemon.
# Install: sudo ln -sfn <repo>/bin/workvm-libvirt-qemu-hook.sh /etc/libvirt/hooks/qemu
# virtqemud caches that list until it is restarted.
# Always exits 0. A non-zero qemu hook aborts start and kills the guest on reconnect.
set -euo pipefail

dir=$(dirname "$(readlink -f "$0")")
state_dir=${XDG_STATE_HOME:-${HOME:-/tmp}/.local/state}/workvm-hooks
mkdir -p "$state_dir"
printf '%s qemu-hook: %s\n' "$(date -Iseconds)" "$*" >>"$state_dir/qemu.log"

"$dir/workvm-set-guest-hostname.sh" "$@" || true
"$dir/workvm-vid2agent-hook.sh" "$@" || true

exit 0
