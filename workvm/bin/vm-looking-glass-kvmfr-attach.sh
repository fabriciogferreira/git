#!/usr/bin/env bash
# Attach Looking Glass via kvmfr (/dev/kvmfr0) to a session VM.
# Requires: sudo ./workvm/bin/host-looking-glass-kvmfr-setup.sh first
# Usage: ./workvm/bin/vm-looking-glass-kvmfr-attach.sh [domain]
set -euo pipefail

DOMAIN="${1:-teste-sr-iov}"
URI="${LIBVIRT_DEFAULT_URI:-qemu:///session}"
SIZE_MB="${KVMFR_SIZE_MB:-128}"
SIZE_BYTES=$((SIZE_MB * 1024 * 1024))

log() { printf '%s\n' "$*"; }
ok() { log "✓ $*"; }
die() { log "error: $*" >&2; exit 1; }

export LIBVIRT_DEFAULT_URI="$URI"

[ -c /dev/kvmfr0 ] || die "/dev/kvmfr0 ausente — rode host-looking-glass-kvmfr-setup.sh"
virsh dominfo "$DOMAIN" >/dev/null || die "domain '$DOMAIN' não encontrada"

state="$(virsh domstate "$DOMAIN")"
if [ "$state" != "shut off" ]; then
    log "→ desligando $DOMAIN"
    virsh destroy "$DOMAIN" >/dev/null 2>&1 || true
    sleep 1
fi

TMP="$(mktemp)"
virsh dumpxml "$DOMAIN" >"$TMP"

python3 - "$TMP" "$SIZE_BYTES" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
size_bytes = int(sys.argv[2])
xml = path.read_text()

# Remove plain shmem looking-glass (breaks VFIO DMA on this host)
xml = re.sub(
    r"\s*<shmem name='looking-glass'>.*?</shmem>\s*",
    "\n",
    xml,
    flags=re.S,
)

# Ensure xmlns:qemu on domain root
if "xmlns:qemu=" not in xml:
    xml = xml.replace(
        "<domain type='kvm'",
        "<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'",
        1,
    )

# Remove existing qemu:commandline looking-glass / ivshmem blocks (whole commandline if only LG)
# Safer: strip any qemu:commandline and recreate
xml = re.sub(r"\s*<qemu:commandline>.*?</qemu:commandline>\s*", "\n", xml, flags=re.S)

# video none for LG path (SPICE will be blank — use looking-glass-client)
xml = re.sub(r"\s*<video>.*?</video>\s*", "\n", xml, flags=re.S)
video = """    <video>
      <model type='none'/>
    </video>
"""
if "</devices>" not in xml:
    raise SystemExit("no </devices>")
xml = xml.replace("</devices>", video + "  </devices>", 1)

# memoryBacking shared helps VFIO + shared mem
if "<memoryBacking>" not in xml:
    xml = xml.replace(
        "</vcpu>",
        "</vcpu>\n  <memoryBacking>\n    <source type='memfd'/>\n    <access mode='shared'/>\n  </memoryBacking>",
        1,
    )

# memballoon none
xml = re.sub(
    r"<memballoon model='[^']*'>\s*.*?</memballoon>",
    "<memballoon model='none'/>",
    xml,
    flags=re.S,
)
xml = re.sub(r"<memballoon model='[^']*'/>", "<memballoon model='none'/>", xml)

cmdline = f"""
  <qemu:commandline>
    <qemu:arg value='-device'/>
    <qemu:arg value="{{'driver':'ivshmem-plain','id':'shmem0','memdev':'looking-glass'}}"/>
    <qemu:arg value='-object'/>
    <qemu:arg value="{{'qom-type':'memory-backend-file','id':'looking-glass','mem-path':'/dev/kvmfr0','size':{size_bytes},'share':true}}"/>
  </qemu:commandline>
"""

if "</domain>" not in xml:
    raise SystemExit("no </domain>")
xml = xml.replace("</domain>", cmdline + "</domain>", 1)
path.write_text(xml)
print(f"patched kvmfr size={size_bytes} video=none")
PY

virsh define "$TMP"
rm -f "$TMP"
ok "domain $DOMAIN: kvmfr IVSHMEM ${SIZE_MB}M + video none"

log ""
log "Subir:"
log "  virsh -c $URI start $DOMAIN"
log "Na VM (sessão gráfica): looking-glass-host"
log "No host: looking-glass-client -f /dev/kvmfr0"
log ""
log "SPICE/Virt-Manager fica sem vídeo — use só o Looking Glass client."
log "Rollback vídeo: recoloque virtio com virt-xml se precisar de emergência."
