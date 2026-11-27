#!/bin/sh
# Menu Gap: seed requisitos × testes do change-set → artefato para o agente.
# Problema: gap analysis no chat gastava tokens em MCP + git + skim.

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

. "$SCRIPT_DIR/lib/terminal.sh"

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/project-card-manager"
CARDS_FILE="$DATA_DIR/cards.tsv"
HOST_CARD_GAP_CMD="${HOST_CARD_GAP_CMD:-$HOME/git/bin/workvm-host-card-gap}"

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

if [ ! -f "$HOST_CARD_GAP_CMD" ] && [ ! -x "$HOST_CARD_GAP_CMD" ]; then
    terminal_normal
    printf "Wrapper Gap não encontrado: %s\n" "$HOST_CARD_GAP_CMD"
    read -r _
    exit 1
fi

printf 'olie\nBack\n' > "$PROJECT_MENU"
menu "$PROJECT_MENU" "Gap - Select project"
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
menu "$CARD_MENU" "Gap - Select card"
CODE="$MENU_RESULT"
[ "$CODE" = "Back" ] && exit 0

SAFE_CODE=$(printf '%s' "$CODE" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '_')
ART_DIR="$DATA_DIR/gap/$PROJECT/$SAFE_CODE"
ART_JSON="$ART_DIR/latest.json"
ART_MD="$ART_DIR/latest.md"

terminal_normal
printf 'Projeto:  %s\n' "$PROJECT"
printf 'Card:     %s\n' "$CODE"
printf 'Artefato: %s\n\n' "$ART_JSON"
printf 'Coletando Card Spec + testes do change-set...\n\n'

bash "$HOST_CARD_GAP_CMD" \
    --project "$PROJECT" \
    --code "$CODE"
STATUS=$?

printf '\n========================================\n'
if [ "$STATUS" -eq 0 ]; then
    printf 'Gap seed OK.\n'
else
    printf 'Gap seed falhou (exit %s) — rode Card Spec / Open se faltar.\n' "$STATUS"
fi

if [ -f "$ART_MD" ]; then
    printf '\n--- latest.md (resumo) ---\n'
    # First 40 lines — full text is on disk for the agent
    head -n 40 "$ART_MD"
    printf '\n-----------------\n'
fi

printf '\nJSON: %s\n' "$ART_JSON"
printf 'Cole o path no chat (test-gap-analysis) ou peça para o agente ler o gap.\n'
printf '========================================\n\n'
printf 'Pressione Enter para continuar.'
read -r _
exit 0
