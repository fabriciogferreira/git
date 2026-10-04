#!/usr/bin/env bash
# Manual apply of configs/<name>/ into paths from config.json.
# Prefer project-setup.sh for project VMs (uses APPLY_CONFIGS from project.conf).
# Usage: ./apply.sh [config-name ...]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$REPO_ROOT/vm/lib/apply-configs.sh"

if [ "$#" -gt 0 ]; then
    workvm_apply_configs "$@"
else
    mapfile -t configs < <(jq -r 'keys[]' "$REPO_ROOT/config.json")
    workvm_apply_configs "${configs[@]}"
fi
