
#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")/.." && pwd)

. "$SCRIPT_DIR/lib/terminal.sh"

PROJECTS_FILE="$SCRIPT_DIR/config/projects.conf"

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/project-card-manager"
CARDS_FILE="$DATA_DIR/cards.tsv"

PROJECTS_TMP=$(mktemp)
CARDS_TMP=$(mktemp)
CONFIRM_TMP=$(mktemp)

cleanup() {
    rm -f "$PROJECTS_TMP" "$CARDS_TMP" "$CONFIRM_TMP"
    terminal_cleanup
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$DATA_DIR"

terminal_init

# --------------------------------------------------
# Select project
# --------------------------------------------------

grep -v '^[[:space:]]*#' "$PROJECTS_FILE" |
    grep -v '^[[:space:]]*$' > "$PROJECTS_TMP"

if [ ! -s "$PROJECTS_TMP" ]; then
    terminal_normal
    echo "No projects configured."
    sleep 2
    exit 0
fi

menu "$PROJECTS_TMP" "Select project"

PROJECT="$MENU_RESULT"

# --------------------------------------------------
# Load project cards
# --------------------------------------------------

: > "$CARDS_TMP"

if [ -f "$CARDS_FILE" ]; then
    awk -F '\t' -v project="$PROJECT" '
        $1 == project { print $2 }
    ' "$CARDS_FILE" | sort -u > "$CARDS_TMP"
fi

if [ ! -s "$CARDS_TMP" ]; then
    terminal_normal
    printf '\nNo known cards for project: %s\n' "$PROJECT"
    sleep 2
    exit 0
fi

# --------------------------------------------------
# Select card
# --------------------------------------------------

menu "$CARDS_TMP" "Select card - $PROJECT"

CODE="$MENU_RESULT"

[ -n "$CODE" ] || exit 0

# --------------------------------------------------
# Confirmation
# --------------------------------------------------

cat > "$CONFIRM_TMP" <<'EOF'
No
Yes
EOF

menu "$CONFIRM_TMP" "Destroy $PROJECT / $CODE?"

if [ "$MENU_RESULT" != "Yes" ]; then
    exit 0
fi

# --------------------------------------------------
# Execute destroy
# --------------------------------------------------

DESTROY_SCRIPT="$HOME/git/$PROJECT/sandbox/host-card-destroy.sh"

terminal_normal

printf '\nDestroying %s / %s...\n\n' "$PROJECT" "$CODE"

if [ ! -f "$DESTROY_SCRIPT" ]; then
    printf 'Error: destroy script not found:\n%s\n' "$DESTROY_SCRIPT"
    SUCCESS=0
elif bash "$DESTROY_SCRIPT" --code "$CODE"; then
    SUCCESS=1
else
    SUCCESS=0
fi

# --------------------------------------------------
# Update local history
# --------------------------------------------------

if [ "$SUCCESS" -eq 1 ]; then
    if [ -f "$CARDS_FILE" ]; then
        UPDATED_FILE=$(mktemp "$DATA_DIR/cards.XXXXXX")

        awk -F '\t' -v project="$PROJECT" -v code="$CODE" '
            !($1 == project && $2 == code)
        ' "$CARDS_FILE" > "$UPDATED_FILE"

        mv "$UPDATED_FILE" "$CARDS_FILE"
    fi

    printf '\nCard destroyed successfully.\n'
else
    printf '\nFailed to destroy card. History preserved.\n'
fi

printf '\nPress Enter to continue...'
read -r _
