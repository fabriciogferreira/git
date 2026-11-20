#!/usr/bin/env bash
# Pós-clone do portfólio Next (project-setup.sh).
# Problema: docker-compose.yaml lê variáveis de .env; sem copiar
# .env.example o compose sobe com container_name/port vazios.
set -euo pipefail

APP="${GIT_ROOT:-$HOME/git}/fabriciogferreira/fabriciogferreira"
if [ ! -d "$APP" ]; then
    printf 'fabriciogferreira post-clone: clone ausente: %s\n' "$APP" >&2
    exit 1
fi

if [ ! -f "${APP}/.env" ] && [ -f "${APP}/.env.example" ]; then
    cp -n "${APP}/.env.example" "${APP}/.env"
    printf 'fabriciogferreira post-clone: .env criado a partir de .env.example\n' >&2
fi
