#!/usr/bin/env bash
# Smoke do Sandbox Manager (piloto Televisão) sem clones da empresa.
# Problema: precisa validar isolamento DB/Redis/rede sem subir a Card VM.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export GIT_ROOT="${GIT_ROOT:-$ROOT}"
export WORKVM_SANDBOX_ROOT="${WORKVM_SANDBOX_ROOT:-$(mktemp -d /tmp/workvm-sandbox-smoke.XXXXXX)}"
export WORKVM_SANDBOX_MAX="${WORKVM_SANDBOX_MAX:-3}"

SB="$ROOT/bin/workvm-sandbox"
cleanup() {
    "$SB" destroy smoke-a >/dev/null 2>&1 || true
    "$SB" destroy smoke-b >/dev/null 2>&1 || true
    if [[ "${WORKVM_SANDBOX_ROOT}" == /tmp/workvm-sandbox-smoke.* ]]; then
        rm -rf "$WORKVM_SANDBOX_ROOT"
    fi
}
trap cleanup EXIT

echo "→ create smoke-a / smoke-b"
"$SB" create --name smoke-a --project televisao --profile tests
"$SB" create --name smoke-b --project televisao --profile tests

echo "→ job: marker em A + FLUSHALL só no Redis de A"
"$SB" job run smoke-a -- sh -c 'echo only-a > /artifacts/marker-a.txt'
job_flush="$("$SB" job run smoke-a --service redis -- redis-cli FLUSHALL)"
"$SB" job run smoke-a --service redis -- redis-cli SET sb A >/dev/null
"$SB" job run smoke-b --service redis -- redis-cli SET sb B >/dev/null
job_get="$("$SB" job run smoke-b --service redis -- redis-cli GET sb)"

val_b="$("$SB" job logs smoke-b "$job_get" stdout | tr -d '\r' | grep -v '^$' | tail -1)"
case "$val_b" in
    *B*) echo "✓ Redis B intacto após FLUSHALL em A (job flush=$job_flush)" ;;
    *)
        echo "error: esperado B no redis de smoke-b, veio: [$val_b]" >&2
        "$SB" job logs smoke-b "$job_get" both >&2 || true
        exit 1
        ;;
esac

echo "→ teto de sandboxes"
if WORKVM_SANDBOX_MAX=2 "$SB" create --name smoke-c --project televisao --profile tests 2>/dev/null; then
    echo "error: create deveria falhar no teto 2" >&2
    "$SB" destroy smoke-c || true
    exit 1
fi
echo "✓ teto respeitado"

echo "→ gui attach/detach A"
"$SB" gui attach smoke-a >/dev/null
"$SB" gui detach smoke-a >/dev/null

echo "→ destroy A; B permanece"
"$SB" destroy smoke-a
"$SB" status smoke-b >/dev/null
if "$SB" status smoke-a >/dev/null 2>&1; then
    echo "error: smoke-a ainda existe" >&2
    exit 1
fi

"$SB" destroy smoke-b
echo "smoke ok"
