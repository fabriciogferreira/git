#!/usr/bin/env bash
# git fetch the workvm meta-repo (~/git) on graphical login.
# Only when on the origin branch (default: main). Never fails the session.
set -u

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

GIT_ROOT="${GIT_ROOT:-$HOME/git}"
BRANCH="${WORKVM_META_BRANCH:-main}"

log() { printf 'workvm-git-pull: %s\n' "$*"; }

if [ ! -d "$GIT_ROOT/.git" ]; then
    log "pulado: $GIT_ROOT não é um repositório git"
    exit 0
fi

workvm_fetch_repo "$GIT_ROOT" "$BRANCH"
exit 0
