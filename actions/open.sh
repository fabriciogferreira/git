
#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

. "$SCRIPT_DIR/lib/terminal.sh"

PROJECTS_FILE="$SCRIPT_DIR/config/projects.conf"

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/project-card-manager"
CARDS_FILE="$DATA_DIR/cards.tsv"

HOST_CARD_CMD="${HOST_CARD_CMD:-$HOME/git/bin/workvm-host-card}"

PROJECTS_TMP=$(mktemp)
CARDS_TMP=$(mktemp)

cleanup() {
    rm -f "$PROJECTS_TMP" "$CARDS_TMP"
    terminal_cleanup
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$DATA_DIR"

terminal_init

grep -v '^[[:space:]]*#' "$PROJECTS_FILE" |
    grep -v '^[[:space:]]*$' > "$PROJECTS_TMP"

menu "$PROJECTS_TMP" "Select project"
PROJECT="$MENU_RESULT"

: > "$CARDS_TMP"

if [ -f "$CARDS_FILE" ]; then
    awk -F '\t' -v project="$PROJECT" '
        $1 == project { print $2 }
    ' "$CARDS_FILE" | sort -u > "$CARDS_TMP"
fi

printf '%s\n' "+ New card" >> "$CARDS_TMP"

menu "$CARDS_TMP" "Select card - $PROJECT"
CODE="$MENU_RESULT"

if [ "$CODE" = "+ New card" ]; then
    terminal_normal

    printf '\nNew card code: '
    read -r CODE

    terminal_raw
fi

[ -n "$CODE" ] || exit 0

terminal_normal

printf '\nOpening %s / %s...\n\n' "$PROJECT" "$CODE"

if "$HOST_CARD_CMD" open \
    --project "$PROJECT" \
    --code "$CODE"; then

    if ! awk -F '\t' -v p="$PROJECT" -v c="$CODE" \
        '$1 == p && $2 == c { found=1 }
         END { exit !found }' "$CARDS_FILE" 2>/dev/null; then

        printf '%s\t%s\n' "$PROJECT" "$CODE" >> "$CARDS_FILE"
    fi

    printf '\nCard opened successfully.\n'
else
    printf '\nFailed to open card.\n'
fi

printf '\nPress Enter to continue...'
read -r _
