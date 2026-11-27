#!/bin/sh
# Menu Coverage do project-card manager.
# Problema: medir coverage no chat do agente gasta tokens; aqui o usuário dispara
# a medição e o artefato vai para o agente só implementar (ARTIFACT.md).

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

. "$SCRIPT_DIR/lib/terminal.sh"

PROJECTS_FILE="$SCRIPT_DIR/config/projects.conf"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/project-card-manager"
CARDS_FILE="$DATA_DIR/cards.tsv"
HOST_CARD_COVERAGE_CMD="${HOST_CARD_COVERAGE_CMD:-$HOME/git/bin/workvm-host-card-coverage}"

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

if [ ! -f "$PROJECTS_FILE" ]; then
    terminal_normal
    printf "Arquivo de projetos não encontrado: %s\n" "$PROJECTS_FILE"
    read -r _
    exit 1
fi

if [ ! -f "$HOST_CARD_COVERAGE_CMD" ]; then
    terminal_normal
    printf "Wrapper Coverage não encontrado: %s\n" "$HOST_CARD_COVERAGE_CMD"
    read -r _
    exit 1
fi

# Coverage v1: só Olie (mesmo escopo do pest host-card).
printf 'olie\nBack\n' > "$PROJECT_MENU"

menu "$PROJECT_MENU" "Coverage - Select project"
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

menu "$CARD_MENU" "Coverage - Select card"
CODE="$MENU_RESULT"

[ "$CODE" = "Back" ] && exit 0

SAFE_CODE=$(printf '%s' "$CODE" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '_')
ART_DIR="$DATA_DIR/coverage/$PROJECT/$SAFE_CODE"
ART_JSON="$ART_DIR/latest.json"
ART_MD="$ART_DIR/latest.md"

terminal_normal

printf 'Projeto:  %s\n' "$PROJECT"
printf 'Card:     %s\n' "$CODE"
printf 'Artefato: %s\n\n' "$ART_JSON"
printf 'Medindo coverage do change-set...\n\n'

bash "$HOST_CARD_COVERAGE_CMD" \
    --project "$PROJECT" \
    --code "$CODE"
STATUS=$?

printf '\n========================================\n'

if [ "$STATUS" -eq 0 ]; then
    printf 'Coverage OK (pass/empty).\n'
else
    printf 'Coverage precisa de trabalho (exit %s).\n' "$STATUS"
fi

if [ -f "$ART_MD" ]; then
    printf '\n--- latest.md ---\n'
    cat "$ART_MD"
    printf '\n-----------------\n'
fi

printf '\nJSON: %s\n' "$ART_JSON"
printf 'Cole esse path no chat (ou peça para o agente olhar o coverage).\n'
printf '========================================\n\n'

printf 'Pressione Enter para continuar.'
read -r _

exit 0
