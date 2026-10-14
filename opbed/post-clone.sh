#!/usr/bin/env bash
# One-time bootstrap after cloning Opbed repos (run by project-setup.sh).
set -euo pipefail

GIT_ROOT="${GIT_ROOT:-$HOME/git}"
BACKEND="${GIT_ROOT}/opbed/opbed-backend"

if [ ! -f "${BACKEND}/.env.example" ]; then
    echo "error: .env.example ausente: ${BACKEND}/.env.example" >&2
    exit 1
fi

echo "→ opbed-backend: cp -n .env.example → .env"
cp -n "${BACKEND}/.env.example" "${BACKEND}/.env"

echo "✓ Pós-clone Opbed concluído"
