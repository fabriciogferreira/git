#!/usr/bin/env bash
# git pull --ff-only do meta-repo (~/git) no login gráfico.
# Só na branch de origin (default: main). Falha de rede/divergência não derruba a sessão.
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

workvm_pull_repo "$GIT_ROOT" "$BRANCH"
exit 0
