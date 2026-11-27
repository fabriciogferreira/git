
#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)

. "$SCRIPT_DIR/lib/terminal.sh"

MAIN_MENU=$(mktemp)

trap 'rm -f "$MAIN_MENU"; terminal_cleanup' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

terminal_init

cat > "$MAIN_MENU" <<'EOF'
Open
Stop
Destroy
Card Spec
Gap
Pest
Pest Changed
Coverage
Mutation
Pre-QA
Exit
EOF

while true; do
    menu "$MAIN_MENU" "Project Card Manager"

    case "$MENU_RESULT" in
        Open)
            "$SCRIPT_DIR/actions/open.sh"
            terminal_raw
            ;;
        Stop)
            "$SCRIPT_DIR/actions/stop.sh"
            terminal_raw
            ;;
        Destroy)
            "$SCRIPT_DIR/actions/destroy.sh"
            terminal_raw
            ;;
        "Card Spec")
            "$SCRIPT_DIR/actions/card-spec.sh"
            terminal_raw
            ;;
        Gap)
            "$SCRIPT_DIR/actions/gap.sh"
            terminal_raw
            ;;
        Pest)
            "$SCRIPT_DIR/actions/pest.sh"
            terminal_raw
            ;;
        "Pest Changed")
            "$SCRIPT_DIR/actions/pest-changed.sh"
            terminal_raw
            ;;
        Coverage)
            "$SCRIPT_DIR/actions/coverage.sh"
            terminal_raw
            ;;
        Mutation)
            "$SCRIPT_DIR/actions/mutation.sh"
            terminal_raw
            ;;
        Pre-QA)
            "$SCRIPT_DIR/actions/pre-qa.sh"
            terminal_raw
            ;;
        Exit)
            exit 0
            ;;
    esac
done
