#!/usr/bin/env bash
# Content fingerprint for mutation/coverage ledger rows (file@blob).
# Problema: sem SHA o dispatcher reabre sandbox no mesmo diff entre chats;
# path-only skip também fecha o olho quando o tip mudou.
# Uso: workvm-ledger-sha.sh <git-repo> <path> [<path>...]
# Imprime: sha:<12>+<12>+... (paths sorted; dirty/untracked → git hash-object)
set -euo pipefail

if [ "$#" -lt 2 ]; then
    printf 'uso: %s <git-repo> <path> [<path>...]\n' "$(basename "$0")" >&2
    exit 2
fi

REPO=$(cd "$1" && pwd)
shift

blob12() {
    local path="$1"
    local full="$REPO/$path"
    if [ ! -e "$full" ]; then
        printf 'workvm-ledger-sha: missing path %s (in %s)\n' "$path" "$REPO" >&2
        return 1
    fi
    (
        cd "$REPO"
        # Clean tracked file → tree blob; otherwise content hash (dirty/untracked).
        if git ls-files --error-unmatch -- "$path" >/dev/null 2>&1 \
            && git diff --quiet HEAD -- "$path" 2>/dev/null; then
            git rev-parse --short=12 "HEAD:$path"
        else
            git hash-object -- "$path" | cut -c1-12
        fi
    )
}

mapfile -t paths < <(printf '%s\n' "$@" | LC_ALL=C sort -u)
parts=()
for path in "${paths[@]}"; do
    [ -n "$path" ] || continue
    parts+=("$(blob12 "$path")")
done

IFS=+
printf 'sha:%s\n' "${parts[*]}"
