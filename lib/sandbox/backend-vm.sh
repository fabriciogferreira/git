# Backend VM (futuro): Sandbox = domain libvirt leve via ensure/drop.
# Problema: container não basta para isolamento de kernel/OS; a API do
# Manager precisa do mesmo create/destroy sem mudar a CLI.
# Não implementa clone ainda — só a superfície e erro claro.

# shellcheck source=common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

workvm_sandbox_vm_create() {
    workvm_sandbox_log "backend=vm ainda não implementado (use --backend container)"
    return 1
}

workvm_sandbox_vm_destroy() {
    local id="$1"
    local domain
    domain="$(workvm_sandbox_meta_get "$id" vm_domain 2>/dev/null || true)"
    if [ -z "$domain" ]; then
        workvm_sandbox_log "sandbox $id sem vm_domain; nada a destruir no backend vm"
        return 0
    fi
    workvm_sandbox_log "backend=vm destroy não implementado (domain=$domain)"
    return 1
}

workvm_sandbox_vm_exec() {
    workvm_sandbox_log "backend=vm exec ainda não implementado"
    return 1
}
