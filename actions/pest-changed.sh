
#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

. "$SCRIPT_DIR/lib/terminal.sh"

PROJECTS_FILE="$SCRIPT_DIR/config/projects.conf"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/project-card-manager"
CARDS_FILE="$DATA_DIR/cards.tsv"

HOST_CARD_ROOT="$HOME/git"
HOST_CARD_PEST_CMD="${HOST_CARD_PEST_CMD:-$HOST_CARD_ROOT/bin/workvm-host-card-pest}"
HOST_CARD_LIB="$HOST_CARD_ROOT/lib/host-card.sh"

PROJECT_MENU=$(mktemp)
CARD_MENU=$(mktemp)
CANDIDATES=$(mktemp)
UNIQUE_FILES=$(mktemp)
TEST_FILES=$(mktemp)

trap 'rm -f "$PROJECT_MENU" "$CARD_MENU" "$CANDIDATES" "$UNIQUE_FILES" "$TEST_FILES"; terminal_cleanup' EXIT
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

if [ ! -f "$HOST_CARD_PEST_CMD" ]; then
    terminal_normal
    printf "Wrapper Pest não encontrado: %s\n" "$HOST_CARD_PEST_CMD"
    read -r _
    exit 1
fi

if [ ! -f "$HOST_CARD_LIB" ]; then
    terminal_normal
    printf "Biblioteca host-card não encontrada: %s\n" "$HOST_CARD_LIB"
    read -r _
    exit 1
fi

while IFS= read -r PROJECT || [ -n "$PROJECT" ]; do
    [ -n "$PROJECT" ] && printf '%s\n' "$PROJECT"
done < "$PROJECTS_FILE" > "$PROJECT_MENU"

printf 'Back\n' >> "$PROJECT_MENU"

menu "$PROJECT_MENU" "Pest Changed - Select project"
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

menu "$CARD_MENU" "Pest Changed - Select card"
CODE="$MENU_RESULT"

[ "$CODE" = "Back" ] && exit 0

# Obtém o worktree do card usando as mesmas funções do wrapper.
CARD_GIT_DIR=$(
    bash -c '
        set -euo pipefail

        ROOT="$1"
        PROJECT="$2"
        CODE="$3"

        source "$ROOT/lib/host-card.sh"

        ID="$(workvm_host_card_id "$PROJECT" "$CODE")"
        META="$(workvm_host_card_meta_path "$PROJECT" "$ID")"

        if [ ! -f "$META" ]; then
            echo "Metadata do card não encontrada: $META" >&2
            exit 1
        fi

        API_WORKTREE="$(python3 -c \
            '\''import json,sys; print(json.load(open(sys.argv[1])).get("api_worktree") or "")'\'' \
            "$META")"

        if [ -z "$API_WORKTREE" ]; then
            API_WORKTREE="$(workvm_host_card_dir "$PROJECT" "$ID")/worktree"
        fi

        if [ -d "$API_WORKTREE/api-main" ]; then
            printf "%s\n" "$API_WORKTREE/api-main"
        else
            printf "%s\n" "$API_WORKTREE"
        fi
    ' _ "$HOST_CARD_ROOT" "$PROJECT" "$CODE"
)

if [ -z "$CARD_GIT_DIR" ]; then
    terminal_normal
    printf "Não foi possível localizar o worktree do card.\n"
    printf "Pressione Enter para continuar."
    read -r _
    exit 1
fi

GIT_ROOT=$(git -C "$CARD_GIT_DIR" rev-parse --show-toplevel 2>/dev/null)

if [ -z "$GIT_ROOT" ]; then
    terminal_normal
    printf "O diretório do card não é um repositório Git:\n%s\n" "$CARD_GIT_DIR"
    printf "Pressione Enter para continuar."
    read -r _
    exit 1
fi

# A branch precisa ter develop disponível localmente.
if ! git -C "$GIT_ROOT" rev-parse --verify 'develop^{commit}' >/dev/null 2>&1; then
    terminal_normal
    printf "A referência local 'develop' não foi encontrada.\n"
    printf "Atualize ou crie a referência develop antes de executar.\n"
    printf "Pressione Enter para continuar."
    read -r _
    exit 1
fi

# 1. Arquivos de teste alterados pela branch desde develop.
git -C "$GIT_ROOT" diff \
    --name-only \
    --diff-filter=ACMR \
    --find-renames \
    develop...HEAD > "$CANDIDATES"

# 2. Arquivos staged.
git -C "$GIT_ROOT" diff \
    --cached \
    --name-only \
    --diff-filter=ACMR \
    --find-renames >> "$CANDIDATES"

# 3. Arquivos unstaged.
git -C "$GIT_ROOT" diff \
    --name-only \
    --diff-filter=ACMR \
    --find-renames >> "$CANDIDATES"

# 4. Arquivos novos ainda não rastreados.
git -C "$GIT_ROOT" ls-files \
    --others \
    --exclude-standard >> "$CANDIDATES"

# Remove duplicados.
sort -u "$CANDIDATES" > "$UNIQUE_FILES"

# Mantém somente arquivos *Test.php que ainda existem.
while IFS= read -r FILE; do
    case "$FILE" in
        *Test.php)
            if [ -f "$GIT_ROOT/$FILE" ]; then
                printf '%s\n' "$FILE"
            fi
            ;;
    esac
done < "$UNIQUE_FILES" > "$TEST_FILES"

TEST_COUNT=$(awk 'END { print NR+0 }' "$TEST_FILES")

if [ "$TEST_COUNT" -eq 0 ]; then
    terminal_normal
    printf "Nenhum arquivo *Test.php alterado foi encontrado.\n"
    printf "Nenhum teste será executado.\n\n"
    printf "Pressione Enter para continuar."
    read -r _
    exit 0
fi

SAFE_CODE=$(printf '%s' "$CODE" | tr -c 'A-Za-z0-9._-' '_')

LOG_DIR="$DATA_DIR/logs/$PROJECT/$SAFE_CODE"
mkdir -p "$LOG_DIR" || exit 1

TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
LOG_FILE="$LOG_DIR/$TIMESTAMP-changed.log"
SUFFIX=1

while [ -e "$LOG_FILE" ]; do
    LOG_FILE="$LOG_DIR/$TIMESTAMP-changed-$SUFFIX.log"
    SUFFIX=$((SUFFIX + 1))
done

# Monta os argumentos sem perder espaços nos nomes dos arquivos.
set --

while IFS= read -r FILE; do
    set -- "$@" "$FILE"
done < "$TEST_FILES"

terminal_normal

printf 'Projeto: %s\n' "$PROJECT"
printf 'Card:    %s\n' "$CODE"
printf 'Branch:  %s\n' "$(git -C "$GIT_ROOT" branch --show-current)"
printf 'Base:    develop\n'
printf 'Testes encontrados: %s\n\n' "$TEST_COUNT"

printf '%s\n' "Arquivos que serão executados:"
while IFS= read -r FILE; do
    printf '  %s\n' "$FILE"
done < "$TEST_FILES"

printf '\nLog: %s\n\n' "$LOG_FILE"

# Mantém o mesmo limite de processos usado pelo wrapper completo.
NPROC_COUNT=$(nproc 2>/dev/null || printf '1')

case "$NPROC_COUNT" in
    ''|*[!0-9]*) NPROC_COUNT=1 ;;
esac

DEFAULT_PROCS="$NPROC_COUNT"

if [ "$NPROC_COUNT" -gt 22 ]; then
    DEFAULT_PROCS=22
fi

PROCS="${WORKVM_HOST_CARD_PEST_PROCESSES:-$DEFAULT_PROCS}"

{
    printf 'Project: %s\n' "$PROJECT"
    printf 'Card: %s\n' "$CODE"
    printf 'Branch: %s\n' "$(git -C "$GIT_ROOT" branch --show-current)"
    printf 'Base: develop\n'
    printf 'Processes: %s\n' "$PROCS"
    printf '\nTest files:\n'
    cat "$TEST_FILES"
    printf '\n========================================\n\n'
} > "$LOG_FILE"

printf 'Executando Pest Changed...\n'

bash "$HOST_CARD_PEST_CMD" \
    --project "$PROJECT" \
    --code "$CODE" \
    -- \
    --compact \
    --parallel \
    --processes="$PROCS" \
    "$@" >> "$LOG_FILE" 2>&1

STATUS=$?

printf '\n========================================\n'

if [ "$STATUS" -eq 0 ]; then
    printf 'Pest Changed finalizado com sucesso.\n'
else
    printf 'Pest Changed terminou com erro (exit code: %s).\n' "$STATUS"
fi

printf 'Testes executados: %s\n' "$TEST_COUNT"
printf 'Log salvo em:\n%s\n' "$LOG_FILE"
printf '========================================\n\n'

printf 'Pressione Enter para continuar.'
read -r _

exit 0
