#!/usr/bin/env bash
# Smoke: mesmo Pest nos dois host-cards Olie em paralelo — não pode colidir.
# Problema: agent Cursor às vezes sem gid docker; rode no terminal onde docker info ok.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HC="$ROOT/bin/workvm-host-card"
TEST_FILE="${1:-tests/Unit/SimpleUnitTest.php}"
if [ ! -f "$ROOT/olie/api-main/$TEST_FILE" ]; then
    echo "teste ausente: $TEST_FILE" >&2
    exit 1
fi

docker info >/dev/null
echo "test=$TEST_FILE"

run_one() {
    local code="$1"
    local id compose_dir pname log
    id="$("$HC" status --project olie --code "$code" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")"
    compose_dir="$("$HC" status --project olie --code "$code" | python3 -c "import sys,json; print(json.load(sys.stdin).get('compose_dir') or '')")"
    pname="$("$HC" status --project olie --code "$code" | python3 -c "import sys,json; print(json.load(sys.stdin)['compose_project'])")"
    if [ -z "$compose_dir" ] || [ ! -d "$compose_dir" ]; then
        compose_dir="${XDG_DATA_HOME:-$HOME/.local/share}/workvm/host-cards/olie/${id}/compose"
    fi
    log="/tmp/hc-test-${code}.log"
    echo "=== $code ($pname) → $log ==="
    (
        cd "$compose_dir"
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
        export COMPOSE_PROJECT_NAME="$pname"
        # marker file unique per stack to prove isolation of the mount/worktree DB
        docker compose --profile slim exec -T app \
            sh -c "echo ${code}-$$ > /tmp/hc-marker && cat /tmp/hc-marker"
        docker compose --profile slim exec -T app \
            php artisan test --compact "$TEST_FILE"
    ) >"$log" 2>&1
    local rc=$?
    echo "$code exit=$rc"
    return "$rc"
}

run_one DOP-1183 &
p1=$!
run_one DOP-1073 &
p2=$!

ec1=0 ec2=0
wait "$p1" || ec1=$?
wait "$p2" || ec2=$?

echo "=== DOP-1183 log (tail) ==="
tail -30 /tmp/hc-test-DOP-1183.log || true
echo "=== DOP-1073 log (tail) ==="
tail -30 /tmp/hc-test-DOP-1073.log || true

echo "=== markers (must differ) ==="
grep -h 'DOP-' /tmp/hc-test-DOP-1183.log /tmp/hc-test-DOP-1073.log | head -10 || true

if [ "$ec1" -ne 0 ] || [ "$ec2" -ne 0 ]; then
    echo "FAIL: exits 1183=$ec1 1073=$ec2" >&2
    exit 1
fi
echo "PASS: same test on both cards, no collision"
