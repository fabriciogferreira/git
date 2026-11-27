
#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

. "$SCRIPT_DIR/lib/terminal.sh"

PROJECTS_FILE="$SCRIPT_DIR/config/projects.conf"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/project-card-manager"
CARDS_FILE="$DATA_DIR/cards.tsv"

HOST_CARD_ROOT="$HOME/git"
HOST_CARD_LIB="$HOST_CARD_ROOT/lib/host-card.sh"

PROJECT_MENU=$(mktemp)
CARD_MENU=$(mktemp)
CONFIRM_MENU=$(mktemp)

trap 'rm -f "$PROJECT_MENU" "$CARD_MENU" "$CONFIRM_MENU"; terminal_cleanup' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

terminal_init

# Valida dependências.
if [ ! -f "$PROJECTS_FILE" ]; then
    terminal_normal
    printf "Arquivo de projetos não encontrado: %s\n" "$PROJECTS_FILE"
    read -r _
    exit 1
fi

if [ ! -f "$CARDS_FILE" ]; then
    terminal_normal
    printf "Nenhum card registrado.\n"
    read -r _
    exit 0
fi

if [ ! -f "$HOST_CARD_LIB" ]; then
    terminal_normal
    printf "Biblioteca host-card não encontrada: %s\n" "$HOST_CARD_LIB"
    read -r _
    exit 1
fi

# Seleção do projeto.
while IFS= read -r PROJECT || [ -n "$PROJECT" ]; do
    [ -n "$PROJECT" ] && printf '%s\n' "$PROJECT"
done < "$PROJECTS_FILE" > "$PROJECT_MENU"

printf 'Back\n' >> "$PROJECT_MENU"

menu "$PROJECT_MENU" "Stop - Select project"
PROJECT="$MENU_RESULT"

[ "$PROJECT" = "Back" ] && exit 0

# Seleção do card.
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

menu "$CARD_MENU" "Stop - Select card"
CODE="$MENU_RESULT"

[ "$CODE" = "Back" ] && exit 0

# Resolve ID, diretório e metadata usando as funções oficiais.
CARD_INFO=$(
    bash -c '
        set -euo pipefail

        ROOT="$1"
        PROJECT="$2"
        CODE="$3"

        source "$ROOT/lib/host-card.sh"

        ID="$(workvm_host_card_id "$PROJECT" "$CODE")"
        DIR="$(workvm_host_card_dir "$PROJECT" "$ID")"
        META="$(workvm_host_card_meta_path "$PROJECT" "$ID")"

        printf "%s\n%s\n%s\n" "$ID" "$DIR" "$META"
    ' _ "$HOST_CARD_ROOT" "$PROJECT" "$CODE"
)

if [ $? -ne 0 ] || [ -z "$CARD_INFO" ]; then
    terminal_normal
    printf "Não foi possível localizar o card.\n"
    printf "Pressione Enter para continuar."
    read -r _
    exit 1
fi

CARD_ID=$(printf '%s\n' "$CARD_INFO" | sed -n '1p')
CARD_DIR=$(printf '%s\n' "$CARD_INFO" | sed -n '2p')
META=$(printf '%s\n' "$CARD_INFO" | sed -n '3p')

if [ ! -f "$META" ]; then
    terminal_normal
    printf "Metadata do card não encontrada:\n%s\n" "$META"
    printf "Pressione Enter para continuar."
    read -r _
    exit 1
fi

# Obtém os dados do Compose.
META_VALUES=$(python3 - "$META" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    meta = json.load(f)

print(meta.get("compose_dir") or "")
print(meta.get("compose_project") or "")
PY
)

COMPOSE_DIR=$(printf '%s\n' "$META_VALUES" | sed -n '1p')
COMPOSE_PROJECT=$(printf '%s\n' "$META_VALUES" | sed -n '2p')

[ -n "$COMPOSE_DIR" ] || COMPOSE_DIR="$CARD_DIR/compose"
[ -n "$COMPOSE_PROJECT" ] || COMPOSE_PROJECT="hc-${CARD_ID}"

if [ ! -d "$COMPOSE_DIR" ] || [ ! -f "$COMPOSE_DIR/compose.yaml" ]; then
    terminal_normal
    printf "Configuração Compose não encontrada:\n%s\n" "$COMPOSE_DIR"
    printf "O card não foi alterado.\n"
    printf "Pressione Enter para continuar."
    read -r _
    exit 1
fi

# Confirmação.
cat > "$CONFIRM_MENU" <<'EOF'
No
Yes
EOF

menu "$CONFIRM_MENU" "Stop card $PROJECT / $CODE?"
CONFIRM="$MENU_RESULT"

[ "$CONFIRM" != "Yes" ] && exit 0

# Executa o stop sem remover containers ou volumes.
terminal_normal

printf 'Parando card %s / %s...\n' "$PROJECT" "$CODE"
printf 'Compose project: %s\n\n' "$COMPOSE_PROJECT"

if bash -c '
    set -euo pipefail

    COMPOSE_DIR="$1"
    COMPOSE_PROJECT="$2"

    cd "$COMPOSE_DIR"

    set -a
    if [ -f .env ]; then
        source .env
    fi
    set +a

    export COMPOSE_PROJECT_NAME="$COMPOSE_PROJECT"

    docker compose --profile "*" stop
' _ "$COMPOSE_DIR" "$COMPOSE_PROJECT"; then
    STATUS=0
else
    STATUS=$?
fi

terminal_raw

printf '\n========================================\n'

if [ "$STATUS" -eq 0 ]; then
    printf 'Card parado com sucesso.\n'
    printf 'Os dados e containers foram preservados.\n'
    printf 'O card continua disponível no histórico.\n'
else
    printf 'Falha ao parar o card (exit code: %s).\n' "$STATUS"
fi

printf '========================================\n\n'

printf 'Pressione Enter para continuar.'
read -r _

exit 0
