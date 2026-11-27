#!/bin/sh
# Menu Mutation do project-card manager.
# Problema: medir mutation no chat do agente gasta tokens; aqui o usuário dispara
# a medição e o artefato vai para o agente só implementar (ARTIFACT.md).

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

. "$SCRIPT_DIR/lib/terminal.sh"

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/project-card-manager"
CARDS_FILE="$DATA_DIR/cards.tsv"
HOST_CARD_MUTATION_CMD="${HOST_CARD_MUTATION_CMD:-$HOME/git/bin/workvm-host-card-mutation}"

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

if [ ! -f "$HOST_CARD_MUTATION_CMD" ]; then
    terminal_normal
    printf "Wrapper Mutation não encontrado: %s\n" "$HOST_CARD_MUTATION_CMD"
    read -r _
    exit 1
fi

printf 'olie\nBack\n' > "$PROJECT_MENU"

menu "$PROJECT_MENU" "Mutation - Select project"
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
    terminal_raw
    exit 0
fi

printf 'Back\n' >> "$CARD_MENU"

menu "$CARD_MENU" "Mutation - Select card"
CODE="$MENU_RESULT"

[ "$CODE" = "Back" ] && exit 0

SAFE_CODE=$(printf '%s' "$CODE" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '_')
ART_JSON="$DATA_DIR/mutation/$PROJECT/$SAFE_CODE/latest.json"
ART_MD="$DATA_DIR/mutation/$PROJECT/$SAFE_CODE/latest.md"

terminal_normal

printf 'Projeto:  %s\n' "$PROJECT"
printf 'Card:     %s\n' "$CODE"
printf 'Artefato: %s\n\n' "$ART_JSON"
printf 'Medindo mutation do change-set (pode demorar)...\n\n'

bash "$HOST_CARD_MUTATION_CMD" \
    --project "$PROJECT" \
    --code "$CODE"
STATUS=$?

printf '\n========================================\n'

if [ "$STATUS" -eq 0 ]; then
    printf 'Mutation OK (pass/empty).\n'
else
    printf 'Mutation precisa de trabalho (exit %s).\n' "$STATUS"
fi

if [ -f "$ART_MD" ]; then
    printf '\n--- latest.md ---\n'
    cat "$ART_MD"
    printf '\n-----------------\n'
fi

printf '\nJSON: %s\n' "$ART_JSON"
printf 'Cole esse path no chat (ou peça para o agente olhar a mutation).\n'
printf '========================================\n\n'

printf 'Pressione Enter para continuar.'
read -r _

exit 0
