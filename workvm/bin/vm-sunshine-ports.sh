#!/usr/bin/env bash
# Host: switch session VM user-net to passt + port-forward Sunshine → localhost.
# (libvirt only allows <portForward> with interface type='user' backend passt.)
#
# Usage: ./workvm/bin/vm-sunshine-ports.sh [domain]
set -euo pipefail

DOMAIN="${1:-teste-sr-iov}"
URI="${LIBVIRT_DEFAULT_URI:-qemu:///session}"

log() { printf '%s\n' "$*"; }
ok() { log "✓ $*"; }
die() { log "error: $*" >&2; exit 1; }

command -v passt >/dev/null || die "instale passt (pacman -S passt)"

export LIBVIRT_DEFAULT_URI="$URI"
virsh dominfo "$DOMAIN" >/dev/null || die "domain '$DOMAIN' não encontrada"

state="$(virsh domstate "$DOMAIN")"
was_running=0
if [ "$state" = "running" ]; then
    was_running=1
    log "→ desligando $DOMAIN para editar rede"
    virsh destroy "$DOMAIN" >/dev/null 2>&1 || true
    sleep 1
fi

TMP="$(mktemp)"
virsh dumpxml "$DOMAIN" >"$TMP"

python3 - "$TMP" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
xml = path.read_text()

new_iface = """    <interface type='user'>
      <mac address='MACADDR'/>
      <model type='virtio'/>
      <backend type='passt'/>
      <portForward proto='tcp'>
        <range start='47984'/>
      </portForward>
      <portForward proto='tcp'>
        <range start='47989'/>
      </portForward>
      <portForward proto='tcp'>
        <range start='47990'/>
      </portForward>
      <portForward proto='tcp'>
        <range start='48010'/>
      </portForward>
      <portForward proto='udp'>
        <range start='47998' end='48000'/>
      </portForward>
      <portForward proto='udp'>
        <range start='48010'/>
      </portForward>
    </interface>
"""

m = re.search(
    r"<interface type='user'>.*?</interface>",
    xml,
    flags=re.S,
)
if not m:
    raise SystemExit("nenhuma <interface type='user'>")

mac_m = re.search(r"<mac address='([^']+)'/>", m.group(0))
mac = mac_m.group(1) if mac_m else "52:54:00:67:2a:0e"
replacement = new_iface.replace("MACADDR", mac)
xml = xml[: m.start()] + replacement + xml[m.end() :]
path.write_text(xml)
print(f"interface user → passt + Sunshine portForward (mac={mac})")
PY

virsh define "$TMP"
rm -f "$TMP"
ok "domain $DOMAIN: passt + port-forwards Sunshine"

if [ "$was_running" -eq 1 ]; then
    virsh start "$DOMAIN"
    ok "VM reiniciada"
fi

log ""
log "No host: moonlight → Add PC → 127.0.0.1"
log "Na VM: https://localhost:47990 → PIN no Moonlight"
