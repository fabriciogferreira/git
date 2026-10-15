#!/usr/bin/env bash
# Aplica <projeto>/config-vm.xml no libvirt só se a domain já existe e está parada.
# Problema: mudar RAM/vCPU no XML versionado não altera a guest até alguém
# rodar virsh define; com a VM ligada o redefine é inseguro/incompleto.
# Não cria domain nova. Roda no host (não dentro da WorkVM).
# Usage:
#   bin/apply-config-vm.sh              # todo projeto com config-vm.xml
#   bin/apply-config-vm.sh olie         # um projeto
# URI: $LIBVIRT_DEFAULT_URI se setado; senão localiza a domain em
# qemu:///session e depois qemu:///system.
set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$BIN_DIR/../lib/common.sh"

REPO_ROOT="$(workvm_discover_repo_root "$BIN_DIR")"

workvm_config_vm_domain_name() {
    local xml="${1:-}"
    local name
    if [ -z "$xml" ] || [ ! -f "$xml" ]; then
        echo "error: workvm_config_vm_domain_name <config-vm.xml>" >&2
        return 1
    fi
    name="$(sed -n 's|.*<name>\([^<]*\)</name>.*|\1|p' "$xml" | head -n1)"
    if [ -z "$name" ]; then
        echo "error: sem <name> em $xml" >&2
        return 1
    fi
    printf '%s\n' "$name"
}

# Prints the URI that already has this domain, or returns 1.
workvm_config_vm_find_uri() {
    local name="${1:-}"
    local uri
    if [ -z "$name" ]; then
        return 1
    fi
    if [ -n "${LIBVIRT_DEFAULT_URI-}" ]; then
        if virsh -c "$LIBVIRT_DEFAULT_URI" dominfo "$name" >/dev/null 2>&1; then
            printf '%s\n' "$LIBVIRT_DEFAULT_URI"
            return 0
        fi
        return 1
    fi
    for uri in qemu:///session qemu:///system; do
        if virsh -c "$uri" dominfo "$name" >/dev/null 2>&1; then
            printf '%s\n' "$uri"
            return 0
        fi
    done
    return 1
}

# Apply one project's config-vm.xml. Returns:
#   0 applied or nothing to do (no xml / domain absent)
#   2 domain exists but is running (skipped)
#   1 hard error
workvm_apply_config_vm() {
    local project_dir="${1:-}"
    local xml name uri state
    local id

    if [ -z "$project_dir" ] || [ ! -d "$project_dir" ]; then
        echo "error: workvm_apply_config_vm <project-dir>" >&2
        return 1
    fi
    id="$(basename "$project_dir")"
    xml="$project_dir/config-vm.xml"
    if [ ! -f "$xml" ]; then
        echo "→ $id: sem config-vm.xml — skip"
        return 0
    fi
    if ! command -v virsh >/dev/null 2>&1; then
        echo "error: virsh ausente (rode no host com libvirt)" >&2
        return 1
    fi

    name="$(workvm_config_vm_domain_name "$xml")" || return 1
    if ! uri="$(workvm_config_vm_find_uri "$name")"; then
        echo "→ $id: domain '$name' não existe no libvirt — skip (não cria VM nova)"
        return 0
    fi

    state="$(virsh -c "$uri" domstate "$name" 2>/dev/null | tr -d '\r')"
    case "$state" in
        'shut off')
            echo "→ $id: define $name ($uri) a partir de $xml"
            virsh -c "$uri" define "$xml"
            echo "  ok: $name atualizada (próximo boot usa a config nova)"
            return 0
            ;;
        *)
            echo "→ $id: domain '$name' está '$state' — skip (pare a VM e rode de novo)" >&2
            return 2
            ;;
    esac
}

main() {
    local arg="${1:-}"
    local id dir
    local -a ids=()
    local rc=0
    local skipped_running=0

    if [ -n "$arg" ]; then
        if ! id="$(workvm_resolve_project_id "$REPO_ROOT" "$arg")"; then
            echo "error: projeto desconhecido: $arg" >&2
            exit 1
        fi
        ids=("$id")
    else
        mapfile -t ids < <(workvm_list_project_ids "$REPO_ROOT")
    fi

    if [ "${#ids[@]}" -eq 0 ]; then
        echo "error: nenhum projeto encontrado em $REPO_ROOT" >&2
        exit 1
    fi

    for id in "${ids[@]}"; do
        [ -n "$id" ] || continue
        dir="$(workvm_project_dir "$REPO_ROOT" "$id")" || continue
        if workvm_apply_config_vm "$dir"; then
            :
        else
            rc=$?
            if [ "$rc" -eq 2 ]; then
                skipped_running=$((skipped_running + 1))
            else
                exit "$rc"
            fi
        fi
    done

    if [ "$skipped_running" -gt 0 ] && [ -n "$arg" ]; then
        exit 2
    fi
    exit 0
}

main "$@"
