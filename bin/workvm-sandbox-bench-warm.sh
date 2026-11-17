#!/usr/bin/env bash
# Benchmark cold (create/destroy per file) vs warm pool for Olie mutation shards.
# Problema: medir se reusar K sandboxes corta wall-clock vs create×N no colleague review.
# Uso (local, sem commit): bin/workvm-sandbox-bench-warm.sh cold|warm [--pool N]
# Não altera o contrato in-scope/+1pp — só orquestra sandbox + Pest mutate one-pass.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-}"
shift || true
POOL_SIZE=4
while [ $# -gt 0 ]; do
    case "$1" in
        --pool) POOL_SIZE="$2"; shift 2 ;;
        *)
            printf 'uso: %s cold|warm [--pool N]\n' "$(basename "$0")" >&2
            exit 2
            ;;
    esac
done

if [ "$MODE" != "cold" ] && [ "$MODE" != "warm" ]; then
    printf 'uso: %s cold|warm [--pool N]\n' "$(basename "$0")" >&2
    exit 2
fi

OUT_DIR="${WORKVM_BENCH_DIR:-/tmp/workvm-bench-dop1258}"
mkdir -p "$OUT_DIR/$MODE"
SHA="$(cat "$OUT_DIR/sha.txt")"
mapfile -t FILES <"$OUT_DIR/tests.txt"
SB=~/git/bin/workvm-sandbox
# Short prefix: sandbox id max ~48 chars (workvm_sandbox_id_ok).
PREFIX="b58${MODE:0:1}"

log() { printf '[bench-%s] %s\n' "$MODE" "$*" >&2; }

slug_file() {
    # id_ok rejects trailing '-'; keep slug short for PREFIX+slug.
    basename "$1" .php | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' \
        | sed -E 's/-+/-/g; s/^-//; s/-$//' | cut -c1-28
}

run_jobs_on_sandbox() {
    local id="$1"
    local file="$2"
    local t0 t1 t2 rc1=0 rc2=0
    t0=$(date +%s.%N)
    "$SB" job run "$id" -- php artisan test --compact "$file" || rc1=$?
    t1=$(date +%s.%N)
    # Real mutate needs --class=FQCN (or covers()/mutates() in the test).
    # Optional: WORKVM_BENCH_MUTATE_CLASS='App\Foo' (one class) for this harness.
    # Without it, Pest aborts after the test run ("requires covers()/mutates()").
    if [ -n "${WORKVM_BENCH_MUTATE_CLASS:-}" ]; then
        "$SB" job run "$id" -- \
            vendor/bin/pest --mutate --covered-only --min=100 \
            --ignore-min-score-on-zero-mutations \
            --class="${WORKVM_BENCH_MUTATE_CLASS}" \
            "$file" || rc2=$?
    else
        "$SB" job run "$id" -- \
            vendor/bin/pest --mutate --covered-only --ignore-min-score-on-zero-mutations \
            "$file" || rc2=$?
    fi
    t2=$(date +%s.%N)
    python3 - "$OUT_DIR/$MODE/$(slug_file "$file").json" "$file" "$id" "$t0" "$t1" "$t2" "$rc1" "$rc2" <<'PY'
import json, sys
path, file, sid, t0, t1, t2, rc1, rc2 = sys.argv[1:]
t0, t1, t2 = map(float, (t0, t1, t2))
json.dump({
    "file": file,
    "sandbox": sid,
    "baseline_s": round(t1 - t0, 2),
    "mutate_s": round(t2 - t1, 2),
    "jobs_s": round(t2 - t0, 2),
    "baseline_rc": int(rc1),
    "mutate_rc": int(rc2),
}, open(path, "w"), indent=2)
print(path)
PY
}

destroy_prefix() {
    local id
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        case "$id" in
            ${PREFIX}*) "$SB" destroy "$id" 2>/dev/null || true ;;
        esac
    done < <("$SB" list 2>/dev/null | awk 'NR>1 {print $1}')
}

wall0=$(date +%s.%N)
log "start files=${#FILES[@]} sha=$SHA pool=$POOL_SIZE"
destroy_prefix

if [ "$MODE" = "cold" ]; then
    pids=()
    for file in "${FILES[@]}"; do
        (
            sid="${PREFIX}-$(slug_file "$file")"
            t0=$(date +%s.%N)
            "$SB" create --name "$sid" --project olie --profile mutation --from-commit "$SHA"
            t1=$(date +%s.%N)
            run_jobs_on_sandbox "$sid" "$file"
            t2=$(date +%s.%N)
            "$SB" destroy "$sid"
            t3=$(date +%s.%N)
            python3 - "$OUT_DIR/$MODE/$(slug_file "$file")-lifecycle.json" "$file" "$sid" "$t0" "$t1" "$t2" "$t3" <<'PY'
import json, sys
path, file, sid, t0, t1, t2, t3 = sys.argv[1:]
t0, t1, t2, t3 = map(float, (t0, t1, t2, t3))
json.dump({
    "file": file,
    "sandbox": sid,
    "create_s": round(t1 - t0, 2),
    "jobs_s": round(t2 - t1, 2),
    "destroy_s": round(t3 - t2, 2),
    "total_s": round(t3 - t0, 2),
}, open(path, "w"), indent=2)
PY
            log "cold done $file"
        ) &
        pids+=("$!")
    done
    ec=0
    for pid in "${pids[@]}"; do
        wait "$pid" || ec=1
    done
else
    # warm: create POOL_SIZE once (in parallel), queue files across free slots,
    # destroy pool at end (in parallel).
    pool=()
    create_pids=()
    for i in $(seq 1 "$POOL_SIZE"); do
        sid="${PREFIX}-slot-${i}"
        pool+=("$sid")
        (
            "$SB" create --name "$sid" --project olie --profile mutation --from-commit "$SHA"
            log "pool ready $sid"
        ) &
        create_pids+=("$!")
    done
    for pid in "${create_pids[@]}"; do
        wait "$pid"
    done

    # Batch queue: up to POOL_SIZE files per wave (no fifo race).
    ec=0
    i=0
    n=${#FILES[@]}
    while [ "$i" -lt "$n" ]; do
        pids=()
        idx=0
        while [ "$idx" -lt "$POOL_SIZE" ] && [ "$i" -lt "$n" ]; do
            file="${FILES[$i]}"
            sid="${pool[$idx]}"
            (
                log "warm assign $file → $sid (wave)"
                run_jobs_on_sandbox "$sid" "$file"
                log "warm done $file"
            ) &
            pids+=("$!")
            idx=$((idx + 1))
            i=$((i + 1))
        done
        for pid in "${pids[@]}"; do
            wait "$pid" || ec=1
        done
    done

    destroy_pids=()
    for sid in "${pool[@]}"; do
        (
            "$SB" destroy "$sid" || true
        ) &
        destroy_pids+=("$!")
    done
    for pid in "${destroy_pids[@]}"; do
        wait "$pid" || true
    done
fi

wall1=$(date +%s.%N)
python3 - "$OUT_DIR/$MODE/summary.json" "$MODE" "$wall0" "$wall1" "$POOL_SIZE" "${#FILES[@]}" "$ec" <<'PY'
import json, sys, glob, os
path, mode, w0, w1, pool, nfiles, ec = sys.argv[1:]
w0, w1 = float(w0), float(w1)
outdir = os.path.dirname(path)
rows = []
for p in sorted(glob.glob(outdir + "/*.json")):
    if p.endswith("summary.json"):
        continue
    rows.append(json.load(open(p)))
summary = {
    "mode": mode,
    "wall_s": round(w1 - w0, 2),
    "pool_size": int(pool),
    "files": int(nfiles),
    "exit": int(ec),
    "shards": rows,
}
json.dump(summary, open(path, "w"), indent=2)
print(json.dumps({"mode": mode, "wall_s": summary["wall_s"], "exit": int(ec)}, indent=2))
PY
exit "$ec"
