#!/usr/bin/env bash
# Super+R abre o hyprlauncher. No virtio o render node recusa CREATE_DUMB
# (EPERM) e o hyprtoolkit morre ao alocar o GBM. O nó primário aceita o ioctl.
# O preload só redireciona esse open. Não troca o launcher.
set -euo pipefail

script_dir=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
src="$script_dir/../lib/virtio-dri-primary.c"
so="${XDG_DATA_HOME:-$HOME/.local/share}/workvm/libvirtio-dri-primary.so"

if [ ! -f "$so" ] || [ "$src" -nt "$so" ]; then
    mkdir -p "$(dirname "$so")"
    gcc -shared -fPIC -o "$so" "$src" -ldl
fi

export LD_PRELOAD="$so${LD_PRELOAD:+:$LD_PRELOAD}"
exec hyprlauncher "$@"
