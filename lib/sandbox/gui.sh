# GUI sob demanda: publica portas do sandbox na guest sem derrubar serviços.
# Problema: interactive não pode ser obrigatório para manter o sandbox vivo.

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
# shellcheck source=backend-container.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backend-container.sh"

workvm_sandbox_gui_attach() {
    local id="${1:-}"
    if [ -z "$id" ]; then
        workvm_sandbox_log "uso: gui attach <id>"
        return 2
    fi
    if ! workvm_sandbox_meta_exists "$id"; then
        workvm_sandbox_log "sandbox ausente: $id"
        return 1
    fi

    workvm_sandbox_container_publish_gui "$id" 1 || return 1
    workvm_sandbox_meta_set "$id" gui_attached true
    workvm_sandbox_meta_set "$id" updated_at "$(workvm_sandbox_now_iso)"

    local port_base
    port_base="$(workvm_sandbox_meta_get "$id" port_base)"
    local api_port=$((port_base + 0))
    local front_port=$((port_base + 1))
    workvm_sandbox_log "GUI attach $id — API http://127.0.0.1:${api_port}  front http://127.0.0.1:${front_port}"
    printf 'api=http://127.0.0.1:%s\n' "$api_port"
    printf 'front=http://127.0.0.1:%s\n' "$front_port"
}

workvm_sandbox_gui_detach() {
    local id="${1:-}"
    if [ -z "$id" ]; then
        workvm_sandbox_log "uso: gui detach <id>"
        return 2
    fi
    if ! workvm_sandbox_meta_exists "$id"; then
        workvm_sandbox_log "sandbox ausente: $id"
        return 1
    fi

    workvm_sandbox_container_publish_gui "$id" 0 || return 1
    workvm_sandbox_meta_set "$id" gui_attached false
    workvm_sandbox_meta_set "$id" updated_at "$(workvm_sandbox_now_iso)"
    workvm_sandbox_log "GUI detach $id — serviços seguem; portas host removidas"
}
