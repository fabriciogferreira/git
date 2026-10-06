#!/usr/bin/env bash
# Attach Looking Glass IVSHMEM to a libvirt session VM and set video=none.
# Usage: ./workvm/bin/vm-looking-glass-attach.sh [domain]
# Default domain: teste-sr-iov
set -euo pipefail

DOMAIN="${1:-teste-sr-iov}"
URI="${LIBVIRT_DEFAULT_URI:-qemu:///session}"
SHMEM_SIZE_MB="${LG_SHMEM_SIZE_MB:-128}"

log() { printf '%s\n' "$*"; }
ok() { log "✓ $*"; }
die() { log "error: $*" >&2; exit 1; }

export LIBVIRT_DEFAULT_URI="$URI"

virsh dominfo "$DOMAIN" >/dev/null || die "domain '$DOMAIN' não encontrada ($URI)"

state="$(virsh domstate "$DOMAIN")"
if [ "$state" != "shut off" ]; then
    log "→ desligando $DOMAIN ($state)"
    virsh destroy "$DOMAIN" >/dev/null 2>&1 || virsh shutdown "$DOMAIN" || true
    for _ in $(seq 1 40); do
        [ "$(virsh domstate "$DOMAIN")" = "shut off" ] && break
        sleep 1
    done
    [ "$(virsh domstate "$DOMAIN")" = "shut off" ] || virsh destroy "$DOMAIN"
fi

TMP="$(mktemp)"
virsh dumpxml "$DOMAIN" >"$TMP"

python3 - "$TMP" "$SHMEM_SIZE_MB" <<'PY'
import re, sys
from pathlib import Path
path, size = sys.argv[1], sys.argv[2]
xml = Path(path).read_text()

# Remove existing looking-glass shmem / video blocks we manage
xml = re.sub(
    r"\s*<shmem name='looking-glass'>.*?</shmem>\s*",
    "\n",
    xml,
    flags=re.S,
)
xml = re.sub(r"\s*<video>.*?</video>\s*", "\n", xml, flags=re.S)

# Disable memballoon (Looking Glass docs: can cause issues)
xml = re.sub(
    r"<memballoon model='[^']*'>\s*.*?</memballoon>",
    "<memballoon model='none'/>",
    xml,
    flags=re.S,
)
xml = re.sub(
    r"<memballoon model='[^']*'/>",
    "<memballoon model='none'/>",
    xml,
)

shmem = f"""    <shmem name='looking-glass'>
      <model type='ivshmem-plain'/>
      <size unit='M'>{size}</size>
    </shmem>
"""
video = """    <video>
      <model type='none'/>
    </video>
"""

if "</devices>" not in xml:
    raise SystemExit("no </devices> in domain XML")
xml = xml.replace("</devices>", shmem + video + "  </devices>", 1)
Path(path).write_text(xml)
print(f"patched: shmem={size}M video=none memballoon=none")
PY

virsh define "$TMP"
rm -f "$TMP"

ok "domain $DOMAIN: IVSHMEM looking-glass ${SHMEM_SIZE_MB}M + video none"
log ""
log "Host (uma vez):"
log "  sudo pacman -S --needed cmake  # se yay pedir"
log "  yay -S --noconfirm looking-glass"
log "  sudo cp workvm/host/tmpfiles.d/10-looking-glass.conf /etc/tmpfiles.d/"
log "  sudo systemd-tmpfiles --create /etc/tmpfiles.d/10-looking-glass.conf"
log ""
log "Subir VM + client:"
log "  virsh -c $URI start $DOMAIN"
log "  # no guest: sudo ./workvm/bin/guest-looking-glass-setup.sh && looking-glass-host"
log "  looking-glass-client -f /dev/shm/looking-glass"
log ""
log "Nota: Looking Glass host no Linux guest ainda é experimental (docs oficiais)."
