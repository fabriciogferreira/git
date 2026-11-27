
#!/bin/sh

terminal_init() {
    if [ -z "${TERMINAL_OLD_STTY:-}" ]; then
        TERMINAL_OLD_STTY=$(stty -g) || return 1
        export TERMINAL_OLD_STTY
    fi

    stty -echo -icanon min 1 time 0
    printf '\033[?25l'
}

terminal_normal() {
    stty "$TERMINAL_OLD_STTY"
    printf '\033[?25h'
}

terminal_raw() {
    stty -echo -icanon min 1 time 0
    printf '\033[?25l'
}

terminal_cleanup() {
    terminal_normal
}

menu() {
    MENU_FILE="$1"
    TITLE="$2"

    TOTAL=$(awk 'END { print NR+0 }' "$MENU_FILE")
    SELECTED=0

    while true; do
        clear
        printf "=== %s ===\n\n" "$TITLE"

        INDEX=0

        while [ "$INDEX" -lt "$TOTAL" ]; do
            OPTION=$(sed -n "$((INDEX + 1))p" "$MENU_FILE")

            if [ "$INDEX" -eq "$SELECTED" ]; then
                printf " > %s\n" "$OPTION"
            else
                printf "   %s\n" "$OPTION"
            fi

            INDEX=$((INDEX + 1))
        done

        KEY=$(dd bs=1 count=1 2>/dev/null |
            od -An -tu1 | tr -d '[:space:]')

        case "$KEY" in
            27)
                SEQUENCE=$(dd bs=1 count=2 2>/dev/null |
                    od -An -tx1 | tr -d '[:space:]')

                case "$SEQUENCE" in
                    5b41)
                        [ "$SELECTED" -gt 0 ] &&
                            SELECTED=$((SELECTED - 1))
                        ;;
                    5b42)
                        [ "$SELECTED" -lt $((TOTAL - 1)) ] &&
                            SELECTED=$((SELECTED + 1))
                        ;;
                esac
                ;;
            10|13)
                MENU_RESULT=$(sed -n "$((SELECTED + 1))p" "$MENU_FILE")
                return 0
                ;;
        esac
    done
}
