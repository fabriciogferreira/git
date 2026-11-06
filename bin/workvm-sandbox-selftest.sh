#!/usr/bin/env bash
# Self-test sem Docker: valida CLI, meta.json, teto e destroy idempotente.
# Problema: no host jarvis o usuário pode não estar no grupo docker; o
# smoke completo (workvm-sandbox-smoke.sh) roda na guest do Card.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP=$(mktemp -d /tmp/workvm-sandbox-selftest.XXXXXX)
export GIT_ROOT="$ROOT"
export WORKVM_SANDBOX_ROOT="$TMP/sandboxes"
export WORKVM_SANDBOX_MAX=2
export PATH="$TMP/bin:$PATH"

mkdir -p "$TMP/bin"
cat >"$TMP/bin/docker" <<'EOF'
#!/usr/bin/env bash
# Minimal stub: compose up/down/exec succeed; network ls empty.
set -euo pipefail
if [ "${1:-}" = "compose" ]; then
  case "${2:-}" in
    exec|run)
      # print remaining args as fake command output for GET sb → B
      if printf '%s ' "$@" | grep -q 'GET sb'; then
        printf 'B\n'
      elif printf '%s ' "$@" | grep -q 'FLUSHALL'; then
        printf 'OK\n'
      elif printf '%s ' "$@" | grep -q 'SET sb'; then
        printf 'OK\n'
      else
        printf 'stub-ok\n'
      fi
      exit 0
      ;;
    *)
      exit 0
      ;;
  esac
fi
if [ "${1:-}" = "network" ]; then
  exit 0
fi
exit 0
EOF
chmod +x "$TMP/bin/docker"

SB="$ROOT/bin/workvm-sandbox"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

echo "→ create a + b"
"$SB" create --name a --project televisao --profile tests >/dev/null
"$SB" create --name b --project televisao --profile mutation >/dev/null
test -f "$WORKVM_SANDBOX_ROOT/a/meta.json"
test -f "$WORKVM_SANDBOX_ROOT/b/meta.json"
grep -q '"state": "ready"' "$WORKVM_SANDBOX_ROOT/a/meta.json"

echo "→ teto"
if "$SB" create --name c --project televisao --profile tests 2>/dev/null; then
  echo "error: teto 2 deveria bloquear" >&2
  exit 1
fi

echo "→ job + logs"
jid="$("$SB" job run a --service redis -- redis-cli GET sb)"
test -f "$WORKVM_SANDBOX_ROOT/a/jobs/$jid/meta.json"
grep -q '"exit_code": 0' "$WORKVM_SANDBOX_ROOT/a/jobs/$jid/meta.json"
out="$("$SB" job logs a "$jid" stdout)"
case "$out" in *B*) ;; *) echo "error: logs sem B: $out" >&2; exit 1 ;; esac

echo "→ gui flags"
"$SB" gui attach a >/dev/null
python3 - <<PY
import json
m = json.load(open("$WORKVM_SANDBOX_ROOT/a/meta.json"))
assert m.get("gui_attached") in (True, "true"), m
PY
"$SB" gui detach a >/dev/null
python3 - <<PY
import json
m = json.load(open("$WORKVM_SANDBOX_ROOT/a/meta.json"))
assert m.get("gui_attached") in (False, "false"), m
PY

echo "→ destroy a; b ok; destroy a de novo idempotente"
"$SB" destroy a
"$SB" status b >/dev/null
"$SB" destroy a
"$SB" destroy b

echo "→ create olie (project.sh + slim)"
"$SB" create --name olie-a --project olie --profile mutation >/dev/null
test -f "$WORKVM_SANDBOX_ROOT/olie-a/meta.json"
grep -q '"project": "olie"' "$WORKVM_SANDBOX_ROOT/olie-a/meta.json"
"$SB" destroy olie-a

# backend vm stub
if "$SB" create --name v --project televisao --backend vm --profile tests 2>/dev/null; then
  echo "error: backend vm deveria falhar" >&2
  exit 1
fi
# failed create may leave meta — destroy cleans
"$SB" destroy v >/dev/null 2>&1 || true

echo "selftest ok"
