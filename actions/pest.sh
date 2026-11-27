#!/bin/sh
# Menu Pest (suite full) do project-card manager.
# Problema: pest-parallel.md media no chat; aqui grava artefato/ledger e o agente
# só conserta fails (lib/pest/ARTIFACT.md).

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

. "$SCRIPT_DIR/lib/terminal.sh"

PROJECTS_FILE="$SCRIPT_DIR/config/projects.conf"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/project-card-manager"
CARDS_FILE="$DATA_DIR/cards.tsv"
HOST_CARD_PEST_CMD="${HOST_CARD_PEST_CMD:-$HOME/git/bin/workvm-host-card-pest}"
SCORE_PY="$SCRIPT_DIR/lib/pest/score.py"
LEDGER_DEFAULT="$SCRIPT_DIR/olie/prompts/pest-ledger.md"

PROJECT_MENU=$(mktemp)
CARD_MENU=$(mktemp)

trap 'rm -f "$PROJECT_MENU" "$CARD_MENU"; terminal_cleanup' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

terminal_init

if [ ! -f "$CARDS_FILE" ]; then
    printf "Nenhum card registrado.\n"
    printf "Pressione Enter para continuar."
    read -r _
    exit 0
fi

if [ ! -f "$PROJECTS_FILE" ]; then
    printf "Arquivo de projetos não encontrado: %s\n" "$PROJECTS_FILE"
    read -r _
    exit 1
fi

if [ ! -f "$HOST_CARD_PEST_CMD" ]; then
    printf "Wrapper Pest não encontrado: %s\n" "$HOST_CARD_PEST_CMD"
    read -r _
    exit 1
fi

while IFS= read -r PROJECT || [ -n "$PROJECT" ]; do
    [ -n "$PROJECT" ] && printf '%s\n' "$PROJECT"
done < "$PROJECTS_FILE" > "$PROJECT_MENU"

printf 'Back\n' >> "$PROJECT_MENU"

menu "$PROJECT_MENU" "Pest - Select project"
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

menu "$CARD_MENU" "Pest - Select card"
CODE="$MENU_RESULT"

[ "$CODE" = "Back" ] && exit 0

SAFE_CODE=$(printf '%s' "$CODE" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '_')

LOG_DIR="$DATA_DIR/logs/$PROJECT/$SAFE_CODE"
ART_DIR="$DATA_DIR/pest/$PROJECT/$SAFE_CODE"
mkdir -p "$LOG_DIR" "$ART_DIR" || exit 1

TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
LOG_FILE="$LOG_DIR/$TIMESTAMP.log"
SUFFIX=1

while [ -e "$LOG_FILE" ]; do
    LOG_FILE="$LOG_DIR/$TIMESTAMP-$SUFFIX.log"
    SUFFIX=$((SUFFIX + 1))
done

terminal_normal

printf 'Projeto:  %s\n' "$PROJECT"
printf 'Card:     %s\n' "$CODE"
printf 'Log:      %s\n' "$LOG_FILE"
printf 'Artefato: %s\n\n' "$ART_DIR/latest.json"
printf 'Executando Pest (suite full)...\n\n'

bash "$HOST_CARD_PEST_CMD" \
    --project "$PROJECT" \
    --code "$CODE" \
    > "$LOG_FILE" 2>&1

STATUS=$?

LEDGER="$LEDGER_DEFAULT"
if [ -f "$SCORE_PY" ]; then
    python3 "$SCORE_PY" \
        --project "$PROJECT" \
        --code "$CODE" \
        --exit-code "$STATUS" \
        --log "$LOG_FILE" \
        --out-dir "$ART_DIR" \
        --git-root "$HOME/git" \
        --ledger "$LEDGER" \
        >/dev/null 2>&1 || true
    cp -f "$ART_DIR/latest.json" "$ART_DIR/$TIMESTAMP.json" 2>/dev/null || true
    cp -f "$ART_DIR/latest.md" "$ART_DIR/$TIMESTAMP.md" 2>/dev/null || true
fi

printf '\n========================================\n'

if [ "$STATUS" -eq 0 ]; then
    printf 'Pest OK (pass).\n'
else
    printf 'Pest precisa de trabalho (exit %s).\n' "$STATUS"
fi

if [ -f "$ART_DIR/latest.md" ]; then
    printf '\n--- latest.md ---\n'
    cat "$ART_DIR/latest.md"
    printf '\n-----------------\n'
fi

printf '\nLog: %s\n' "$LOG_FILE"
printf 'JSON: %s\n' "$ART_DIR/latest.json"
printf 'Cole o JSON no chat se precisar que o agente arrume fails.\n'
printf '========================================\n\n'

printf 'Pressione Enter para continuar.'
read -r _

exit 0
