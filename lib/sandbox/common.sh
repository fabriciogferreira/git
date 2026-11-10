# Paths, meta.json e validação do Sandbox Manager.
# Problema: N ambientes no mesmo Card brigavam pelo mesmo compose/DB/Redis.
# Este arquivo só define estado e helpers; create/destroy ficam nos backends.

workvm_sandbox_root() {
    printf '%s\n' "${WORKVM_SANDBOX_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/workvm/sandboxes}"
}

workvm_sandbox_git_root() {
    printf '%s\n' "${GIT_ROOT:-$HOME/git}"
}

workvm_sandbox_meta_repo() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    printf '%s\n' "$here"
}

workvm_sandbox_log() {
    printf 'workvm-sandbox: %s\n' "$*" >&2
}

workvm_sandbox_id_ok() {
    printf '%s' "$1" | grep -Eq '^[a-zA-Z0-9]([a-zA-Z0-9_-]{0,46}[a-zA-Z0-9])?$'
}

workvm_sandbox_dir() {
    local id="$1"
    printf '%s/%s\n' "$(workvm_sandbox_root)" "$id"
}

workvm_sandbox_meta_path() {
    printf '%s/meta.json\n' "$(workvm_sandbox_dir "$1")"
}

workvm_sandbox_jobs_dir() {
    printf '%s/jobs\n' "$(workvm_sandbox_dir "$1")"
}

workvm_sandbox_worktrees_dir() {
    local id="$1"
    local project="${2:-}"
    if [ -z "$project" ]; then
        project="$(workvm_sandbox_meta_get "$id" project 2>/dev/null || true)"
    fi
    printf '%s/%s/.sandboxes/%s\n' "$(workvm_sandbox_git_root)" "${project:-televisao}" "$id"
}

workvm_sandbox_ensure_root() {
    mkdir -p "$(workvm_sandbox_root)"
}

# meta.json helpers (python for reliable JSON without jq dependency).
workvm_sandbox_meta_write() {
    local id="$1"
    local json="$2"
    local dir
    dir="$(workvm_sandbox_dir "$id")"
    mkdir -p "$dir" "$(workvm_sandbox_jobs_dir "$id")"
    printf '%s\n' "$json" >"$(workvm_sandbox_meta_path "$id")"
}

workvm_sandbox_meta_get() {
    local id="$1"
    local key="$2"
    local path
    path="$(workvm_sandbox_meta_path "$id")"
    [ -f "$path" ] || return 1
    WORKVM_SB_META="$path" WORKVM_SB_KEY="$key" python3 - <<'PY'
import json, os
data = json.load(open(os.environ["WORKVM_SB_META"]))
key = os.environ["WORKVM_SB_KEY"]
val = data.get(key, "")
if isinstance(val, (dict, list)):
    print(json.dumps(val))
else:
    print(val)
PY
}

workvm_sandbox_meta_set() {
    local id="$1"
    local key="$2"
    local value="$3"
    local path
    path="$(workvm_sandbox_meta_path "$id")"
    [ -f "$path" ] || return 1
    WORKVM_SB_META="$path" WORKVM_SB_KEY="$key" WORKVM_SB_VAL="$value" python3 - <<'PY'
import json, os
path = os.environ["WORKVM_SB_META"]
key = os.environ["WORKVM_SB_KEY"]
raw = os.environ["WORKVM_SB_VAL"]
data = json.load(open(path))
try:
    data[key] = json.loads(raw)
except json.JSONDecodeError:
    data[key] = raw
json.dump(data, open(path, "w"), indent=2, sort_keys=True)
PY
}

workvm_sandbox_meta_exists() {
    [ -f "$(workvm_sandbox_meta_path "$1")" ]
}

workvm_sandbox_list_ids() {
    local root
    root="$(workvm_sandbox_root)"
    [ -d "$root" ] || return 0
    local d
    for d in "$root"/*; do
        [ -d "$d" ] || continue
        [ -f "$d/meta.json" ] || continue
        basename "$d"
    done | sort
}

workvm_sandbox_count() {
    local n=0
    local id
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        n=$((n + 1))
    done < <(workvm_sandbox_list_ids)
    printf '%s\n' "$n"
}

workvm_sandbox_now_iso() {
    date -u +'%Y-%m-%dT%H:%M:%SZ'
}

workvm_sandbox_port_base() {
    # Stable offset in 20000–29900 from sandbox id.
    local id="$1"
    local hash
    hash=$(printf '%s' "$id" | cksum | awk '{ print $1 }')
    printf '%s\n' $((20000 + hash % 100 * 100))
}

workvm_sandbox_load_project() {
    # Sources televisao/sandbox/project.sh (or PROJECT/sandbox/project.sh).
    local project="$1"
    local hook
    hook="$(workvm_sandbox_meta_repo)/${project}/sandbox/project.sh"
    if [ ! -f "$hook" ]; then
        workvm_sandbox_log "projeto sem sandbox/project.sh: $project"
        return 1
    fi
    # shellcheck source=/dev/null
    source "$hook"
}
