#!/usr/bin/env bash
# Forum thread bodies are not on MCP olie-flow-ai (only forum stub on
# get-project-details). Auto-review treats inline `source environment.d` +
# Bearer curl as high risk even for these reads. This helper loads
# OLIE_MANAGEMENT_TOKEN without printing it and only allows forum GETs.
# Card/funnel/project reads: MCP first. Writes: MCP or direct curl (prompt).
#
# Preference: MCP → gh (GitHub only) → this helper / curl.
#
# Usage (from any cwd):
#   bin/workvm-olie-management-read.sh get-forum <project-uuid>
#   bin/workvm-olie-management-read.sh get-thread <forum-id> <thread-id>
#   bin/workvm-olie-management-read.sh get-thread-data <forum-id> <thread-id> <version-id>
set -euo pipefail

BASE_URL="${OLIE_MANAGEMENT_BASE_URL:-https://api.olie.ai/api/management}"

workvm_load_management_token() {
  set -a
  local conf
  for conf in "${HOME}/.config/environment.d/"*.conf; do
    [[ -f "$conf" ]] || continue
    # shellcheck disable=SC1090
    . "$conf"
  done
  set +a
  if [[ -z "${OLIE_MANAGEMENT_TOKEN:-}" ]]; then
    echo "error: OLIE_MANAGEMENT_TOKEN empty (set in ~/.config/environment.d/*.conf)" >&2
    exit 1
  fi
}

workvm_curl_json() {
  local method="$1"
  local url="$2"
  shift 2
  curl -sS --url "$url" \
    -H 'accept: application/json' \
    -H "authorization: Bearer ${OLIE_MANAGEMENT_TOKEN}" \
    -H 'content-type: application/json' \
    -X "$method" \
    "$@"
}

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

cmd="${1:-}"
[[ -n "$cmd" ]] || usage
shift || true

workvm_load_management_token

case "$cmd" in
  get-forum)
    [[ $# -eq 1 ]] || usage
    workvm_curl_json POST "${BASE_URL}/get-forum" \
      --data-raw "{\"model_class\":\"App\\\\Models\\\\Project\",\"model_id\":\"$1\"}"
    ;;
  get-thread)
    [[ $# -eq 2 ]] || usage
    workvm_curl_json GET "${BASE_URL}/get-thread/$1/$2"
    ;;
  get-thread-data)
    [[ $# -eq 3 ]] || usage
    workvm_curl_json GET "${BASE_URL}/get-thread-data/$1/$2?version=$3"
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    echo "error: unknown command: $cmd (forum reads only)" >&2
    echo "use MCP for project/funnel (index-projects, get-project-details, index-project-funnels)." >&2
    usage
    ;;
esac
