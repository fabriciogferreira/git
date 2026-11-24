# Guardas contra rm/rsync catastróficos (dest vazio → `/`, `$HOME`, etc.).
# Problema: no DOP-1136 um rsync com dest vazio apagou o que dava sob $HOME;
# wt vazio em project.sh vira "/api-main" e "/e2e/" — mesmo pé-de-cabra.
# Sourced por host-card e sandbox. Só path sob workvm / .sandboxes / roots
# explícitos de teste passa.

workvm_safe_fs_log() {
    printf 'workvm-safe-fs: %s\n' "$*" >&2
}

# Recusa path vazio, `/`, `$HOME`, ancestrais de `$HOME`, e tudo fora da
# allowlist (workvm data, `*/.sandboxes/*`, WORKVM_SANDBOX_ROOT /
# WORKVM_HOST_CARD_ROOT quando setados).
workvm_assert_safe_destructive_path() {
    local path="${1:-}"
    local real home_real workvm_real extra
    local -a allowed=()

    if [ -z "$path" ]; then
        workvm_safe_fs_log "recusado: path destrutivo vazio (evita rm/rsync → /)"
        return 1
    fi

    case "$path" in
        /|/.|/..|"$HOME"|"$HOME/"|/home|/home/|/usr|/usr/|/var|/var/|/etc|/etc/|/tmp|/tmp/|/boot|/boot/|/root|/root/|/opt|/opt/|/srv|/srv/)
            workvm_safe_fs_log "recusado: path perigoso: $path"
            return 1
            ;;
    esac

    real="$(realpath -m "$path")"
    home_real="$(realpath -m "$HOME")"

    if [ "$real" = "/" ]; then
        workvm_safe_fs_log "recusado: path resolve para /"
        return 1
    fi
    if [ "$real" = "$home_real" ]; then
        workvm_safe_fs_log "recusado: path é \$HOME ($real)"
        return 1
    fi
    # path ancestral de $HOME (ex.: /home) apagaria a home inteira
    case "$home_real" in
        "$real"|"$real"/*)
            workvm_safe_fs_log "recusado: path contém \$HOME ($real)"
            return 1
            ;;
    esac

    workvm_real="$(realpath -m "${XDG_DATA_HOME:-$HOME/.local/share}/workvm")"
    allowed+=("$workvm_real")

    if [ -n "${WORKVM_SANDBOX_ROOT:-}" ]; then
        allowed+=("$(realpath -m "$WORKVM_SANDBOX_ROOT")")
    fi
    if [ -n "${WORKVM_HOST_CARD_ROOT:-}" ]; then
        allowed+=("$(realpath -m "$WORKVM_HOST_CARD_ROOT")")
    fi

    for extra in "${allowed[@]}"; do
        [ -n "$extra" ] || continue
        case "$real" in
            "$extra"|"$extra"/*) return 0 ;;
        esac
    done

    case "$real" in
        */.sandboxes|/*/.sandboxes/*) return 0 ;;
    esac

    workvm_safe_fs_log "recusado: path fora de workvm/.sandboxes (ou roots de teste): $real"
    return 1
}
