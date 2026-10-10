#!/usr/bin/env bash
# Funções compartilhadas da work VM.
# Problema: git, Cursor e sessão estavam num arquivo só e achar uma função
# exigia ler tudo. O corpo está em git.sh, cursor.sh e session.sh.

_lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=git.sh
source "$_lib/git.sh"
# shellcheck source=cursor.sh
source "$_lib/cursor.sh"
# shellcheck source=session.sh
source "$_lib/session.sh"
unset _lib
