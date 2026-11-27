#!/bin/sh
# Menu Pre-QA: commitlint + gh PR + checklist + forms + move → artefato.
# Problema: handoff mecânico no chat do agente gastava tokens e pedia MCP/gh à mão.

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

. "$SCRIPT_DIR/lib/terminal.sh"

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/project-card-manager"
CARDS_FILE="$DATA_DIR/cards.tsv"
HOST_CARD_PRE_QA_CMD="${HOST_CARD_PRE_QA_CMD:-$HOME/git/bin/workvm-host-card-pre-qa}"

PROJECT_MENU=$(mktemp)
CARD_MENU=$(mktemp)
DOCS_MENU=$(mktemp)
MODE_MENU=$(mktemp)

trap 'rm -f "$PROJECT_MENU" "$CARD_MENU" "$DOCS_MENU" "$MODE_MENU"; terminal_cleanup' EXIT
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

if [ ! -f "$HOST_CARD_PRE_QA_CMD" ] && [ ! -x "$HOST_CARD_PRE_QA_CMD" ]; then
    terminal_normal
    printf "Wrapper Pre-QA não encontrado: %s\n" "$HOST_CARD_PRE_QA_CMD"
    read -r _
    exit 1
fi

printf 'olie\nBack\n' > "$PROJECT_MENU"
menu "$PROJECT_MENU" "Pre-QA - Select project"
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
menu "$CARD_MENU" "Pre-QA - Select card"
CODE="$MENU_RESULT"
[ "$CODE" = "Back" ] && exit 0

printf 'nao\nsim\nunknown (agent)\nBack\n' > "$DOCS_MENU"
menu "$DOCS_MENU" "API docs update (Postman)?"
DOCS_CHOICE="$MENU_RESULT"
[ "$DOCS_CHOICE" = "Back" ] && exit 0
case "$DOCS_CHOICE" in
    nao) DOCS=nao ;;
    sim) DOCS=sim ;;
    *) DOCS=unknown ;;
esac

printf 'Apply (PR+checklist+move)\nDry-run (plan only)\nBack\n' > "$MODE_MENU"
menu "$MODE_MENU" "Pre-QA - Mode"
MODE="$MENU_RESULT"
[ "$MODE" = "Back" ] && exit 0

SAFE_CODE=$(printf '%s' "$CODE" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '_')
ART_JSON="$DATA_DIR/pre-qa/$PROJECT/$SAFE_CODE/latest.json"
ART_MD="$DATA_DIR/pre-qa/$PROJECT/$SAFE_CODE/latest.md"

EXTRA="--docs $DOCS"
case "$MODE" in
    Dry-run*) EXTRA="$EXTRA --dry-run" ;;
esac

terminal_normal
printf 'Projeto:  %s\n' "$PROJECT"
printf 'Card:     %s\n' "$CODE"
printf 'Docs:     %s\n' "$DOCS"
printf 'Mode:     %s\n' "$MODE"
printf 'Artefato: %s\n\n' "$ART_JSON"
printf 'Rodando Pre-QA mecânico...\n\n'

# shellcheck disable=SC2086
bash "$HOST_CARD_PRE_QA_CMD" \
    --project "$PROJECT" \
    --code "$CODE" \
    $EXTRA
STATUS=$?

printf '\n========================================\n'
if [ "$STATUS" -eq 0 ]; then
    printf 'Pre-QA OK.\n'
else
    printf 'Pre-QA precisa de trabalho (exit %s).\n' "$STATUS"
fi

if [ -f "$ART_MD" ]; then
    printf '\n--- latest.md ---\n'
    cat "$ART_MD"
    printf '\n-----------------\n'
fi

printf '\nJSON: %s\n' "$ART_JSON"
printf 'Cole no chat (pre-qa.md) — agente posta evidência / fecha gaps do artefato.\n'
printf '========================================\n\n'
printf 'Pressione Enter para continuar.'
read -r _
exit 0
