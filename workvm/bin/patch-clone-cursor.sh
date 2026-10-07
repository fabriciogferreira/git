#!/usr/bin/env bash
# Local Cursor multi-root patch on project clones (alwaysApply→globs, AGENTS relocate).
# Does not touch remotes. Safe to re-run. Usage:
#   patch-clone-cursor.sh           # all projects with clones present
#   patch-clone-cursor.sh opbed     # one project
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

workvm_patch_all_projects_clone_cursor "${1:-}"
