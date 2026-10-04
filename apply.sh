#!/usr/bin/env bash
# Deprecated: use ./project-setup.sh --apply [config-name ...]
# Kept as a thin wrapper while callers migrate.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "aviso: apply.sh está deprecado; use: $REPO_ROOT/project-setup.sh --apply ${*:-}" >&2
exec "$REPO_ROOT/project-setup.sh" --apply "$@"
