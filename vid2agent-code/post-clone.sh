#!/usr/bin/env bash
# Pós-clone do vid2agent-code (project-setup.sh).
# O .env, o UID do volume e o compose.dev.yaml estão em lib/laravel-post-clone.sh.
set -euo pipefail

_project_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
_root="$_project_dir"
while [ "$_root" != "/" ] && [ ! -f "$_root/lib/laravel-post-clone.sh" ]; do
    _root="$(dirname "$_root")"
done
if [ ! -f "$_root/lib/laravel-post-clone.sh" ]; then
    echo "error: lib/laravel-post-clone.sh não encontrado a partir de $_project_dir" >&2
    exit 1
fi

exec "$_root/lib/laravel-post-clone.sh" \
    "${GIT_ROOT:-$HOME/git}/vid2agent-code/vid2agent-code"
