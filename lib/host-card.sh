# Host card unit (no WorkVM): state, workspace, ensure/destroy.
# Problema: N cards no jarvis colidem sem id/porta/workspace próprios; a domain
# libvirt fazia isso de graça. Este helper é o contrato mínimo do
# host-cards-no-vm.md até o compose namespaced estar completo por projeto.

workvm_host_card_root() {
    printf '%s\n' "${WORKVM_HOST_CARD_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/workvm/host-cards}"
}

workvm_host_card_git_root() {
    printf '%s\n' "${GIT_ROOT:-$HOME/git}"
}

workvm_host_card_meta_repo() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    printf '%s\n' "$here"
}

workvm_host_card_log() {
    printf 'workvm-host-card: %s\n' "$*" >&2
}

# Escreve SB_MEM/SB_CPUS no .env do compose e, por padrão, tira cpus/mem_limit
# dos YAMLs do card. Problema: default 1 CPU/1G por serviço fazia Pest disputar
# mal e o MySQL bater no teto enquanto o host ainda tinha folga; host-card deve
# deixar o CFS do kernel ratear. Teto só se WORKVM_HOST_CARD_MEM e/ou
# WORKVM_HOST_CARD_CPUS estiverem setados (ex.: MEM=2g CPUS=2).
# Uso: workvm_host_card_write_resource_env >> partial; depois
# workvm_host_card_apply_compose_limits "$compose_dir".
workvm_host_card_write_resource_env() {
    if [ -n "${WORKVM_HOST_CARD_MEM:-}" ]; then
        printf 'SB_MEM=%s\n' "$WORKVM_HOST_CARD_MEM"
    else
        # placeholders inócuos se algum YAML ainda interpolar
        printf 'SB_MEM=0\n'
    fi
    if [ -n "${WORKVM_HOST_CARD_CPUS:-}" ]; then
        printf 'SB_CPUS=%s\n' "$WORKVM_HOST_CARD_CPUS"
    else
        printf 'SB_CPUS=0\n'
    fi
}

workvm_host_card_apply_compose_limits() {
    local compose_dir="$1"
    local f
    if [ -n "${WORKVM_HOST_CARD_MEM:-}" ] || [ -n "${WORKVM_HOST_CARD_CPUS:-}" ]; then
        workvm_host_card_log "teto de recurso: MEM=${WORKVM_HOST_CARD_MEM:-∅} CPUS=${WORKVM_HOST_CARD_CPUS:-∅}"
        return 0
    fi
    workvm_host_card_log "sem cpus/mem_limit — containers disputam o host"
    for f in "$compose_dir"/compose.yaml "$compose_dir"/compose.*.yml; do
        [ -f "$f" ] || continue
        # remove hard caps do slim/front (mem_limit / cpus)
        sed -i -E '/^[[:space:]]*(mem_limit|cpus):/d' "$f"
    done
}

# Worktree api-main + cópia do vendor por card.
# Problema: dois host-cards montavam o mesmo clone/vendor; Pest -p em paralelo
# corrompia cache/vendor e estourava schema (api_main_test_* sem tabelas).
# Cursor ainda abre os clones compartilhados; o compose usa estes paths.
# Uso: prepare no ensure; remove no destroy (antes do rm -rf do state dir).
workvm_host_card_api_src() {
    printf '%s/olie/api-main\n' "$(workvm_host_card_git_root)"
}

workvm_host_card_prepare_api_isolation() {
    local dir="$1"
    local src wt_root wt_api vendor_dst head
    src="$(workvm_host_card_api_src)"
    wt_root="${dir}/worktree"
    wt_api="${wt_root}/api-main"
    vendor_dst="${dir}/vendor"

    if [ ! -d "${src}/.git" ] && [ ! -f "${src}/.git" ]; then
        workvm_host_card_log "api-main não é git: $src"
        return 1
    fi
    if [ ! -f "${src}/vendor/autoload.php" ]; then
        workvm_host_card_log "vendor ausente em ${src}/vendor (composer install)"
        return 1
    fi

    mkdir -p "$wt_root"
    if [ -d "$wt_api" ] && { [ -d "${wt_api}/.git" ] || [ -f "${wt_api}/.git" ]; }; then
        workvm_host_card_log "api worktree já existe: $wt_api"
    else
        # Hooks do clone podem chamar docker exec olie-api-main (ausente no host).
        workvm_host_card_log "git worktree add --detach $wt_api"
        rm -rf "$wt_api"
        git -C "$src" -c core.hooksPath=/dev/null worktree add --detach "$wt_api" HEAD || return 1
    fi

    mkdir -p \
        "${wt_api}/storage/logs" \
        "${wt_api}/storage/framework/cache" \
        "${wt_api}/storage/framework/sessions" \
        "${wt_api}/storage/framework/views" \
        "${wt_api}/bootstrap/cache" \
        "${wt_api}/vendor"
    # Placeholder: o vendor real entra via bind SB_API_VENDOR (cópia por card).
    if [ ! -f "${wt_api}/vendor/README.host-card.md" ]; then
        printf '# vendor montado em runtime (SB_API_VENDOR → /var/www/html/vendor)\n' \
            >"${wt_api}/vendor/README.host-card.md"
    fi

    workvm_host_card_log "rsync vendor → $vendor_dst"
    mkdir -p "$vendor_dst"
    rsync -a --delete "${src}/vendor/" "${vendor_dst}/" || return 1

    # .env do card (não o do clone compartilhado)
    if [ -f "${src}/.env" ]; then
        cp -f "${src}/.env" "${wt_api}/.env"
    elif [ -f "${src}/.env.example" ]; then
        cp -f "${src}/.env.example" "${wt_api}/.env"
    else
        printf 'APP_KEY=base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\n' >"${wt_api}/.env"
    fi
}

workvm_host_card_remove_api_isolation() {
    local dir="$1"
    local src wt_api
    src="$(workvm_host_card_api_src)"
    wt_api="${dir}/worktree/api-main"
    if [ -d "$wt_api" ]; then
        workvm_host_card_log "git worktree remove $wt_api"
        git -C "$src" worktree remove --force "$wt_api" 2>/dev/null \
            || rm -rf "$wt_api"
    fi
    rm -rf "${dir}/worktree" "${dir}/vendor"
}

workvm_host_card_normalize_code() {
    # DOP-1165 → dop-1165
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed -E 's/-+/-/g; s/^-//; s/-$//'
}

workvm_host_card_id() {
    local project="$1"
    local code="$2"
    local norm
    norm="$(workvm_host_card_normalize_code "$code")"
    printf '%s-%s\n' "$project" "$norm"
}

workvm_host_card_dir() {
    local project="$1"
    local id="$2"
    printf '%s/%s/%s\n' "$(workvm_host_card_root)" "$project" "$id"
}

workvm_host_card_meta_path() {
    printf '%s/meta.json\n' "$(workvm_host_card_dir "$1" "$2")"
}

workvm_host_card_port_base() {
    # Same formula as workvm_sandbox_port_base (stable 20000–29900).
    local id="$1"
    local hash
    hash=$(printf '%s' "$id" | cksum | awk '{ print $1 }')
    printf '%s\n' $((20000 + hash % 100 * 100))
}

workvm_host_card_project_ok() {
    case "$1" in
        olie|locav|televisao|opbed) return 0 ;;
        *) return 1 ;;
    esac
}

workvm_host_card_workspace_src() {
    local project="$1"
    printf '%s/%s/workspace.code-workspace\n' "$(workvm_host_card_meta_repo)" "$project"
}

workvm_host_card_write_workspace() {
    local project="$1"
    local id="$2"
    local code="${3:-$id}"
    local src project_dir dest
    src="$(workvm_host_card_workspace_src "$project")"
    if [ ! -f "$src" ]; then
        workvm_host_card_log "workspace fonte ausente: $src"
        return 1
    fi
    # Paths relative to the file; keep beside project workspace. Only include
    # roots that exist. Two cards share the same clones — window isolation is
    # cursor --new-window, not a fake "card CODE" folder in the explorer.
    project_dir="$(dirname "$src")"
    dest="${project_dir}/${id}.code-workspace"
    WORKVM_HC_SRC="$src" WORKVM_HC_DEST="$dest" \
        WORKVM_HC_PROJECT_DIR="$project_dir" python3 <<'PY'
import json, os
from pathlib import Path
src = Path(os.environ["WORKVM_HC_SRC"])
dest = Path(os.environ["WORKVM_HC_DEST"])
project_dir = Path(os.environ["WORKVM_HC_PROJECT_DIR"])
raw = json.loads(src.read_text(encoding="utf-8"))
folders = []
for ent in raw.get("folders", []):
    rel = ent.get("path") or ""
    name = ent.get("name") or rel
    if not rel or rel == ".":
        continue
    target = (project_dir / rel).resolve()
    if target.exists():
        folders.append({"name": name, "path": rel})
raw["folders"] = folders
raw.setdefault("settings", {})
dest.write_text(json.dumps(raw, indent=2) + "\n", encoding="utf-8")
PY
    printf '%s\n' "$dest"
}

workvm_host_card_meta_write() {
    local project="$1"
    local code="$2"
    local id="$3"
    local dir="$4"
    local port_base="$5"
    local workspace="$6"
    local compose_project="$7"
    local now
    now="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    mkdir -p "$dir"
    WORKVM_HC_PROJECT="$project" WORKVM_HC_CODE="$code" WORKVM_HC_ID="$id" \
        WORKVM_HC_PORT_BASE="$port_base" WORKVM_HC_WORKSPACE="$workspace" \
        WORKVM_HC_COMPOSE="$compose_project" WORKVM_HC_NOW="$now" \
        python3 - "$dir/meta.json" <<'PY'
import json, os, sys
path = sys.argv[1]
meta = {
    "project": os.environ["WORKVM_HC_PROJECT"],
    "code": os.environ["WORKVM_HC_CODE"],
    "id": os.environ["WORKVM_HC_ID"],
    "port_base": int(os.environ["WORKVM_HC_PORT_BASE"]),
    "workspace": os.environ["WORKVM_HC_WORKSPACE"],
    "compose_project": os.environ["WORKVM_HC_COMPOSE"],
    "created_at": os.environ["WORKVM_HC_NOW"],
    "updated_at": os.environ["WORKVM_HC_NOW"],
}
if os.path.isfile(path):
    with open(path, encoding="utf-8") as f:
        old = json.load(f)
    meta["created_at"] = old.get("created_at", meta["created_at"])
with open(path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
PY
}

workvm_host_card_run_hook() {
    local project="$1"
    local phase="$2" # ensure|destroy
    local id="$3"
    local dir="$4"
    local hook
    hook="$(workvm_host_card_meta_repo)/${project}/sandbox/host-card-${phase}.sh"
    if [ -f "$hook" ]; then
        # shellcheck source=/dev/null
        source "$hook"
        "workvm_host_card_${phase}_hook" "$id" "$dir" || return $?
    fi
    return 0
}

# Clone/pull CLONE_REPOS do project.conf (mesmo conjunto da WorkVM).
workvm_host_card_ensure_clones() {
    local project="$1"
    local meta_repo conf
    meta_repo="$(workvm_host_card_meta_repo)"
    conf="${meta_repo}/${project}/project.conf"
    if [ ! -f "$conf" ]; then
        workvm_host_card_log "project.conf ausente: $conf (pula clones)"
        return 0
    fi
    # shellcheck source=/dev/null
    source "${meta_repo}/lib/common.sh"
    # shellcheck source=/dev/null
    source "$conf"
    if ! declare -p CLONE_REPOS >/dev/null 2>&1 || [ "${#CLONE_REPOS[@]}" -eq 0 ]; then
        return 0
    fi
    export GIT_ROOT="$(workvm_host_card_git_root)"
    workvm_host_card_log "CLONE_REPOS ($project) — clone/pull como na WorkVM"
    workvm_clone_project_repos "${CLONE_REPOS[@]}"
}

workvm_host_card_ensure() {
    local project="" code=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --project) project="$2"; shift 2 ;;
            --code) code="$2"; shift 2 ;;
            *)
                workvm_host_card_log "flag desconhecida: $1"
                return 2
                ;;
        esac
    done
    if [ -z "$project" ] || [ -z "$code" ]; then
        workvm_host_card_log "uso: ensure --project <olie|locav|televisao|opbed> --code <CODE>"
        return 2
    fi
    if ! workvm_host_card_project_ok "$project"; then
        workvm_host_card_log "projeto inválido: $project"
        return 2
    fi

    local id dir port_base workspace compose_project resumed=0
    id="$(workvm_host_card_id "$project" "$code")"
    dir="$(workvm_host_card_dir "$project" "$id")"
    compose_project="hc-${id}"
    mkdir -p "$(workvm_host_card_root)/${project}"

    if [ -f "$(workvm_host_card_meta_path "$project" "$id")" ]; then
        resumed=1
        port_base="$(python3 -c "import json;print(json.load(open('$(workvm_host_card_meta_path "$project" "$id")'))['port_base'])")"
        workvm_host_card_log "resume $id (port_base=$port_base)"
    else
        port_base="$(workvm_host_card_port_base "$id")"
        workvm_host_card_log "create $id (port_base=$port_base)"
    fi

    # Same clones as WorkVM project-setup (olie-fronts, backoffice, …).
    workvm_host_card_ensure_clones "$project" || return 1
    workspace="$(workvm_host_card_write_workspace "$project" "$id" "$code")" || return 1

    workvm_host_card_meta_write "$project" "$code" "$id" "$dir" "$port_base" "$workspace" "$compose_project" || return 1
    workvm_host_card_run_hook "$project" ensure "$id" "$dir" || return 1

    # Re-read compose_project after hook (olie/televisao may rewrite it).
    if [ -f "$(workvm_host_card_meta_path "$project" "$id")" ]; then
        compose_project="$(python3 -c "import json;print(json.load(open('$(workvm_host_card_meta_path "$project" "$id")')).get('compose_project','$compose_project'))")"
    fi

    if [ "${WORKVM_HOST_CARD_OPEN_CURSOR:-1}" != "0" ] && [ -f "$workspace" ]; then
        # shellcheck source=session.sh
        source "$(workvm_host_card_meta_repo)/lib/session.sh"
        # --new-window: two cards share clone paths; without -n Cursor reuses one window.
        workvm_open_cursor "$workspace" --new-window \
            || workvm_host_card_log "Cursor não abriu (sem sessão gráfica?); workspace=$workspace"
    fi

    local dns_slug api_dns front_dns
    dns_slug="$(python3 -c "import json;print(json.load(open('$(workvm_host_card_meta_path "$project" "$id")')).get('dns_slug') or '')" 2>/dev/null || true)"
    if [ -z "$dns_slug" ]; then
        # shellcheck source=host-card-proxy.sh
        source "$(workvm_host_card_meta_repo)/lib/host-card-proxy.sh"
        dns_slug="$(workvm_host_card_dns_slug "$code")"
    fi
    api_dns="http://api.${dns_slug}.olie.localhost"
    front_dns="http://devframe.${dns_slug}.olie.localhost"

    printf 'id=%s\n' "$id"
    printf 'project=%s\n' "$project"
    printf 'code=%s\n' "$code"
    printf 'resumed=%s\n' "$resumed"
    printf 'port_base=%s\n' "$port_base"
    printf 'dns_slug=%s\n' "$dns_slug"
    printf 'api_url=http://127.0.0.1:%s\n' "$port_base"
    printf 'front_url=http://127.0.0.1:%s\n' "$((port_base + 1))"
    printf 'api_dns=%s\n' "$api_dns"
    printf 'front_dns=%s\n' "$front_dns"
    printf 'workspace=%s\n' "$workspace"
    printf 'compose_project=%s\n' "$compose_project"
    printf 'state_dir=%s\n' "$dir"
}

workvm_host_card_status() {
    local project="" code=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --project) project="$2"; shift 2 ;;
            --code) code="$2"; shift 2 ;;
            *)
                workvm_host_card_log "flag desconhecida: $1"
                return 2
                ;;
        esac
    done
    if [ -z "$project" ] || [ -z "$code" ]; then
        workvm_host_card_log "uso: status --project <…> --code <CODE>"
        return 2
    fi
    local id meta
    id="$(workvm_host_card_id "$project" "$code")"
    meta="$(workvm_host_card_meta_path "$project" "$id")"
    if [ ! -f "$meta" ]; then
        workvm_host_card_log "ausente: $id"
        return 1
    fi
    cat "$meta"
}

workvm_host_card_destroy() {
    local project="" code=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --project) project="$2"; shift 2 ;;
            --code) code="$2"; shift 2 ;;
            *)
                workvm_host_card_log "flag desconhecida: $1"
                return 2
                ;;
        esac
    done
    if [ -z "$project" ] || [ -z "$code" ]; then
        workvm_host_card_log "uso: destroy --project <…> --code <CODE>"
        return 2
    fi
    local id dir meta workspace compose_project
    id="$(workvm_host_card_id "$project" "$code")"
    dir="$(workvm_host_card_dir "$project" "$id")"
    meta="$(workvm_host_card_meta_path "$project" "$id")"
    if [ ! -f "$meta" ]; then
        workvm_host_card_log "já ausente: $id"
        return 0
    fi
    workspace="$(python3 -c "import json;print(json.load(open('$meta')).get('workspace',''))")"
    compose_project="$(python3 -c "import json;print(json.load(open('$meta')).get('compose_project',''))")"

    workvm_host_card_run_hook "$project" destroy "$id" "$dir" || true

    if [ -n "$compose_project" ] && command -v docker >/dev/null 2>&1; then
        # Best-effort: no Docker socket / empty project must not fail destroy.
        docker ps -aq --filter "label=com.docker.compose.project=${compose_project}" 2>/dev/null \
            | xargs -r docker rm -f >/dev/null 2>&1 || true
        docker network ls --format '{{.Name}}' 2>/dev/null \
            | grep -E "^${compose_project}" \
            | while read -r net; do docker network rm "$net" >/dev/null 2>&1 || true; done || true
    fi

    if [ -n "$workspace" ] && [ -f "$workspace" ]; then
        rm -f "$workspace"
    fi
    rm -rf "$dir"
    workvm_host_card_log "destroyed $id"

    # Drop DNS routes for this card (meta already gone).
    # shellcheck source=host-card-proxy.sh
    source "$(workvm_host_card_meta_repo)/lib/host-card-proxy.sh"
    workvm_host_card_proxy_reload || true
}

workvm_host_card_list() {
    local root
    root="$(workvm_host_card_root)"
    if [ ! -d "$root" ]; then
        return 0
    fi
    find "$root" -mindepth 3 -maxdepth 3 -name meta.json -print 2>/dev/null \
        | while read -r m; do
            python3 -c "import json;d=json.load(open('$m'));print(d.get('id','?'), d.get('project','?'), d.get('code','?'), d.get('port_base','?'))"
        done
}
