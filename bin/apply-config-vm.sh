#!/usr/bin/env bash
# Aplica RAM/vCPU de <projeto>/config-vm.xml na domain libvirt existente e parada.
# Problema: o XML versionado pode ter <name> velho (ex. olie-dop-1206) enquanto a
# domain real é o id do projeto (olie); virsh define no nome errado não muda a VM.
# Não cria domain nova. Não redefine o XML inteiro se o <name> não bate com a
# domain viva (só setmaxmem/setmem/setvcpus). Roda no host.
# Usage:
#   bin/apply-config-vm.sh              # todo projeto com config-vm.xml
#   bin/apply-config-vm.sh olie         # um projeto (falha se a domain não existir)
# URI: $LIBVIRT_DEFAULT_URI se setado; senão session, depois system.
set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$BIN_DIR/../lib/common.sh"

REPO_ROOT="$(workvm_discover_repo_root "$BIN_DIR")"

workvm_config_vm_xml_name() {
    local xml="${1:-}"
    local name
    if [ -z "$xml" ] || [ ! -f "$xml" ]; then
        echo "error: workvm_config_vm_xml_name <config-vm.xml>" >&2
        return 1
    fi
    name="$(sed -n 's|.*<name>\([^<]*\)</name>.*|\1|p' "$xml" | head -n1)"
    if [ -z "$name" ]; then
        echo "error: sem <name> em $xml" >&2
        return 1
    fi
    printf '%s\n' "$name"
}

# Memory in KiB from <memory unit="KiB">…</memory>
workvm_config_vm_xml_memory_kib() {
    local xml="${1:-}"
    local kib
    kib="$(sed -n 's|.*<memory unit="KiB">\([0-9][0-9]*\)</memory>.*|\1|p' "$xml" | head -n1)"
    if [ -z "$kib" ]; then
        echo "error: sem <memory unit=\"KiB\"> em $xml" >&2
        return 1
    fi
    printf '%s\n' "$kib"
}

workvm_config_vm_xml_vcpu() {
    local xml="${1:-}"
    local n
    n="$(sed -n 's|.*<vcpu[^>]*>\([0-9][0-9]*\)</vcpu>.*|\1|p' "$xml" | head -n1)"
    if [ -z "$n" ]; then
        echo "error: sem <vcpu> em $xml" >&2
        return 1
    fi
    printf '%s\n' "$n"
}

# Prints URI if domain exists; return 1 otherwise.
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

# Resolve live domain: XML <name> first, then project id. Prints "uri name".
workvm_config_vm_resolve() {
    local xml_name="${1:-}"
    local project_id="${2:-}"
    local uri

    if uri="$(workvm_config_vm_find_uri "$xml_name")"; then
        printf '%s %s\n' "$uri" "$xml_name"
        return 0
    fi
    if [ -n "$project_id" ] && [ "$project_id" != "$xml_name" ]; then
        if uri="$(workvm_config_vm_find_uri "$project_id")"; then
            printf '%s %s\n' "$uri" "$project_id"
            return 0
        fi
    fi
    return 1
}

# Apply one project. Returns:
#   0 applied or skip (no xml; batch + domain absent)
#   2 domain running
#   3 domain absent (caller turns into error when project was explicit)
#   1 hard error
workvm_apply_config_vm() {
    local project_dir="${1:-}"
    local xml xml_name uri name state mem_kib vcpus
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

    xml_name="$(workvm_config_vm_xml_name "$xml")" || return 1
    mem_kib="$(workvm_config_vm_xml_memory_kib "$xml")" || return 1
    vcpus="$(workvm_config_vm_xml_vcpu "$xml")" || return 1

    if ! read -r uri name < <(workvm_config_vm_resolve "$xml_name" "$id"); then
        echo "→ $id: nenhuma domain '$xml_name' nem '$id' no libvirt — skip (não cria VM)" >&2
        return 3
    fi

    if [ "$name" != "$xml_name" ]; then
        echo "→ $id: aviso: XML tem <name>$xml_name</name>, domain viva é '$name' — aplicando RAM/vCPU nela; atualize o XML" >&2
    fi

    state="$(virsh -c "$uri" domstate "$name" 2>/dev/null | tr -d '\r')"
    case "$state" in
        'shut off')
            ;;
        *)
            echo "→ $id: domain '$name' está '$state' — skip (pare a VM e rode de novo)" >&2
            return 2
            ;;
    esac

    echo "→ $id: $name ($uri) → ${mem_kib} KiB RAM, ${vcpus} vCPU"

    if [ "$name" = "$xml_name" ]; then
        virsh -c "$uri" define "$xml"
    else
        # Nome diverge: não define o XML inteiro (criaria/alteraria outra domain).
        virsh -c "$uri" setmaxmem "$name" "$mem_kib" --config
        virsh -c "$uri" setmem "$name" "$mem_kib" --config
        virsh -c "$uri" setvcpus "$name" "$vcpus" --config --maximum
        virsh -c "$uri" setvcpus "$name" "$vcpus" --config
    fi

    # Confirma na mesma URI (virsh sem -c costuma ser session; olie está em system).
    echo "  ok: próximo boot de '$name' usa a config nova"
    virsh -c "$uri" dumpxml "$name" | grep -E '^\s*<(memory|currentMemory|vcpu) ' || true
    return 0
}

main() {
    local arg="${1:-}"
    local id dir
    local -a ids=()
    local rc=0
    local skipped_running=0
    local missing=0
    local require=0

    if [ -n "$arg" ]; then
        require=1
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
            case "$rc" in
                2) skipped_running=$((skipped_running + 1)) ;;
                3) missing=$((missing + 1)) ;;
                *) exit "$rc" ;;
            esac
        fi
    done

    if [ "$require" -eq 1 ]; then
        if [ "$missing" -gt 0 ]; then
            exit 3
        fi
        if [ "$skipped_running" -gt 0 ]; then
            exit 2
        fi
    fi
    exit 0
}

main "$@"
