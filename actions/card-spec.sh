#!/bin/sh
# Menu Card Spec: dump project/Caderno/media → olie/cards/<CODE>/
# Problema: agente gastava tokens em MCP get-project/notebook/media no implementation.

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

. "$SCRIPT_DIR/lib/terminal.sh"

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/project-card-manager"
CARDS_FILE="$DATA_DIR/cards.tsv"
DUMP_CMD="${DUMP_CMD:-$HOME/git/bin/workvm-olie-card-dump}"
CARDS_ROOT="${CARDS_ROOT:-$HOME/git/olie/cards}"

PROJECT_MENU=$(mktemp)
CARD_MENU=$(mktemp)

trap 'rm -f "$PROJECT_MENU" "$CARD_MENU"; terminal_cleanup' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

terminal_init

if [ ! -f "$CARDS_FILE" ]; then
    terminal_normal
    printf "Nenhum card registrado.\n"
    printf "Pressione Enter para continuar."
    read -r _
    exit 0
fi

if [ ! -x "$DUMP_CMD" ] && [ ! -f "$DUMP_CMD" ]; then
    terminal_normal
    printf "Dump não encontrado: %s\n" "$DUMP_CMD"
    read -r _
    exit 1
fi

printf 'olie\nBack\n' > "$PROJECT_MENU"
menu "$PROJECT_MENU" "Card Spec - Select project"
PROJECT="$MENU_RESULT"
[ "$PROJECT" = "Back" ] && exit 0

awk -F '\t' -v project="$PROJECT" '
    $1 == project && $2 != "" { print $2 }
' "$CARDS_FILE" > "$CARD_MENU"

if [ ! -s "$CARD_MENU" ]; then
    terminal_normal
    printf "Nenhum card registrado para %s.\n" "$PROJECT"
    printf "Pressione Enter para continuar."
    read -r _
    exit 0
fi

printf 'Back\n' >> "$CARD_MENU"
menu "$CARD_MENU" "Card Spec - Select card"
CODE="$MENU_RESULT"
[ "$CODE" = "Back" ] && exit 0

CODE=$(printf '%s' "$CODE" | tr '[:lower:]' '[:upper:]')
OUT_DIR="$CARDS_ROOT/$CODE"

terminal_normal
printf 'Projeto: %s\n' "$PROJECT"
printf 'Card:    %s\n' "$CODE"
printf 'Destino: %s\n\n' "$OUT_DIR"
printf 'Baixando project + Caderno + media...\n\n'

bash "$DUMP_CMD" --code "$CODE" --cards-root "$CARDS_ROOT"
STATUS=$?

printf '\n========================================\n'
if [ "$STATUS" -eq 0 ]; then
    printf 'Card Spec OK.\n'
    printf 'Abra: %s/README.md\n' "$OUT_DIR"
else
    printf 'Card Spec falhou (exit %s).\n' "$STATUS"
fi
printf '========================================\n\n'
printf 'Pressione Enter para continuar.'
read -r _
exit 0
