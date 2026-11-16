# Hook Televisão: sobe compose slim namespaced para o host-card (sem WorkVM).
# Problema: ensure só criava workspace; o card precisa de MySQL/Redis isolados.
# Usa ~/git/televisao como SB_WORKTREE (clones reais, não worktree detach).
# Sourced by lib/host-card.sh — define workvm_host_card_ensure_hook.

workvm_host_card_ensure_hook() {
    local id="$1"
    local dir="$2"
    local meta_repo git_root compose_dir port_base wt

    meta_repo="$(workvm_host_card_meta_repo)"
    git_root="$(workvm_host_card_git_root)"
    compose_dir="${dir}/compose"
    wt="${git_root}/televisao"
    port_base="$(python3 -c "import json;print(json.load(open('${dir}/meta.json'))['port_base'])")"

    if [ ! -d "${wt}/televisao-api" ]; then
        workvm_host_card_log "clone ausente: ${wt}/televisao-api (rode project-setup televisao no host)"
        return 1
    fi

    mkdir -p "$compose_dir/artifacts"
    cp -f "${meta_repo}/televisao/sandbox/compose.slim.yml" "$compose_dir/compose.yaml"
    cp -f "${meta_repo}/televisao/sandbox/compose.gui.yml" "$compose_dir/compose.gui.yml"

    local pname="hc-${id}"
    {
        printf 'COMPOSE_PROJECT_NAME=%s\n' "$pname"
        printf 'SB_WORKTREE=%s\n' "$wt"
        workvm_host_card_write_resource_env
        printf 'SB_PORT_API=%s\n' "$port_base"
        printf 'SB_PORT_FRONT=%s\n' "$((port_base + 1))"
        printf 'COMPOSE_FILE=compose.yaml:compose.gui.yml\n'
    } >"$compose_dir/.env"

    workvm_host_card_apply_compose_limits "$compose_dir"

    python3 - "$dir/meta.json" "$pname" "$compose_dir" <<'PY'
import json, sys
path, pname, compose_dir = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as f:
    meta = json.load(f)
meta["compose_project"] = pname
meta["compose_dir"] = compose_dir
meta["stack"] = "televisao-slim"
with open(path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
PY

    workvm_host_card_log "compose up ($pname profile=slim)"
    (
        cd "$compose_dir"
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
        export COMPOSE_PROJECT_NAME="$pname"
        docker compose --profile slim up -d --remove-orphans
    ) || return 1

    workvm_host_card_log "stack slim em http://127.0.0.1:${port_base} (ver compose.gui.yml)"
}
