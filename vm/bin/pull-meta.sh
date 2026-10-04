#!/usr/bin/env bash
# Fast-forward the workvm meta-repo (~/git) on graphical login.
# Never fails the session: network/divergence only warn and exit 0.
set -u

GIT_ROOT="${GIT_ROOT:-$HOME/git}"
BRANCH="${WORKVM_META_BRANCH:-main}"

log() { printf 'workvm-git-pull: %s\n' "$*"; }

if [ ! -d "$GIT_ROOT/.git" ]; then
    log "pulado: $GIT_ROOT não é um repositório git"
    exit 0
fi

current="$(git -C "$GIT_ROOT" branch --show-current 2>/dev/null || true)"
if [ "$current" != "$BRANCH" ]; then
    log "pulado: branch atual é '${current:-detached}', esperado '$BRANCH'"
    exit 0
fi

# Skip when the working tree is dirty (staged, unstaged, or untracked).
if [ -n "$(git -C "$GIT_ROOT" status --porcelain --untracked-files=normal 2>/dev/null)" ]; then
    log "pulado: há alterações locais em $GIT_ROOT"
    exit 0
fi

log "fetch + ff-only origin/$BRANCH em $GIT_ROOT"
if ! git -C "$GIT_ROOT" fetch --prune origin; then
    log "aviso: fetch falhou (rede?); seguindo sem atualizar"
    exit 0
fi

if ! git -C "$GIT_ROOT" rev-parse --verify "origin/${BRANCH}" >/dev/null 2>&1; then
    log "aviso: origin/${BRANCH} ausente após fetch"
    exit 0
fi

if ! git -C "$GIT_ROOT" merge --ff-only "origin/${BRANCH}"; then
    log "aviso: ff-only falhou (commits locais divergentes?); seguindo sem atualizar"
    exit 0
fi

log "ok: $(git -C "$GIT_ROOT" rev-parse --short HEAD)"
exit 0
