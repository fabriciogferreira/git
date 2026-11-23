# Plugin use-url-query para o Sandbox Manager.
# Problema: bun run test (Vitest)/coverage no Card brigavam pelo container_name fixo.
# Isola worktree por sandbox; sem Postgres/Redis (biblioteca TypeScript + bun).

workvm_sandbox_project_max() {
    printf '%s\n' "${WORKVM_SANDBOX_MAX:-2}"
}

workvm_sandbox_project_mem_limit() {
    local profile="$1"
    case "$profile" in
        e2e|mutation) printf '1g\n' ;;
        *) printf '768m\n' ;;
    esac
}

workvm_sandbox_project_cpus() {
    local profile="$1"
    case "$profile" in
        e2e|mutation) printf '1.0\n' ;;
        *) printf '0.75\n' ;;
    esac
}

workvm_sandbox_project_repos() {
    printf '%s\n' use-url-query
}

# Garante use-url-query-sandbox-backend:tests (Bun + Node real).
# Problema: oven/bun só tem `node` → bun; Vitest --coverage quebra nos workers.
# Card continua em oven/bun; só o slim do sandbox usa esta tag.
workvm_sandbox_uq_ensure_backend_image() {
    local meta_repo tag=use-url-query-sandbox-backend:tests
    meta_repo="$(workvm_sandbox_meta_repo)"

    if docker image inspect "$tag" >/dev/null 2>&1; then
        if docker run --rm --entrypoint node "$tag" -e \
            'if (process.versions.bun) process.exit(1)' >/dev/null 2>&1; then
            return 0
        fi
        workvm_sandbox_log "${tag} sem Node real — rebuild"
    fi

    workvm_sandbox_log "build ${tag} (Bun + Node via Dockerfile.backend)"
    docker build -t "$tag" \
        -f "${meta_repo}/use-url-query/sandbox/Dockerfile.backend" \
        "${meta_repo}/use-url-query/sandbox"
}

workvm_sandbox_project_after_up() {
    local id="$1"
    local wt="$2"

    if declare -F workvm_sandbox_meta_set >/dev/null; then
        workvm_sandbox_meta_set "$id" default_service backend
    fi

    # node_modules no worktree: bun install se ainda não existe.
    if [ -d "${wt}/use-url-query" ] && [ ! -d "${wt}/use-url-query/node_modules" ]; then
        local compose_dir pname
        compose_dir="$(workvm_sandbox_meta_get "$id" compose_dir 2>/dev/null || true)"
        pname="$(workvm_sandbox_container_project_name "$id")"
        if [ -n "$compose_dir" ] && [ -d "$compose_dir" ]; then
            workvm_sandbox_log "bun install no worktree $id"
            (
                cd "$compose_dir"
                set -a
                # shellcheck disable=SC1091
                [ -f .env ] && source .env
                set +a
                docker compose -p "$pname" exec -T backend bun install
            ) || workvm_sandbox_log "bun install falhou no after_up — rode no job"
        fi
    fi
}

workvm_sandbox_project_prepare_worktrees() {
    local id="$1"
    local wt="$2"
    local from_commit="${3:-}"
    local git_root project_root repo src dest
    git_root="$(workvm_sandbox_git_root)"
    project_root="${git_root}/use-url-query"

    mkdir -p "$wt"
    printf 'sandbox=%s\n' "$id" >"$wt/.sandbox-id"

    local exclude="${project_root}/.git/info/exclude"
    if [ -d "${project_root}/.git" ] || [ -f "${project_root}/.git" ]; then
        mkdir -p "$(dirname "$exclude")"
        touch "$exclude"
        if ! grep -qxF '/.sandboxes/' "$exclude" 2>/dev/null; then
            printf '/.sandboxes/\n' >>"$exclude"
        fi
    fi
    exclude="$(workvm_sandbox_meta_repo)/.git/info/exclude"
    if [ -d "$(dirname "$exclude")" ]; then
        mkdir -p "$(dirname "$exclude")"
        touch "$exclude"
        if ! grep -qxF '/use-url-query/.sandboxes/' "$exclude" 2>/dev/null; then
            printf '/use-url-query/.sandboxes/\n' >>"$exclude"
        fi
    fi

    while IFS= read -r repo; do
        [ -n "$repo" ] || continue
        src="${project_root}/${repo}"
        dest="${wt}/${repo}"
        if [ -d "${src}/.git" ] || [ -f "${src}/.git" ]; then
            if [ -d "$dest" ]; then
                continue
            fi
            workvm_sandbox_log "worktree $repo → $dest"
            if [ -n "$from_commit" ] && git -C "$src" cat-file -e "${from_commit}^{commit}" 2>/dev/null; then
                git -C "$src" worktree add --detach "$dest" "$from_commit"
            elif [ -n "$from_commit" ]; then
                workvm_sandbox_log "from_commit $from_commit absent in $repo; using HEAD"
                git -C "$src" worktree add --detach "$dest" HEAD
            else
                git -C "$src" worktree add --detach "$dest" HEAD
            fi
        else
            mkdir -p "$dest"
            printf '# clone %s ausente neste host; dir vazio no sandbox\n' "$repo" >"$dest/README.sandbox.md"
        fi
    done < <(workvm_sandbox_project_repos)
}

workvm_sandbox_project_remove_worktrees() {
    local id="$1"
    local wt="$2"
    local git_root project_root repo src dest
    git_root="$(workvm_sandbox_git_root)"
    project_root="${git_root}/use-url-query"

    while IFS= read -r repo; do
        [ -n "$repo" ] || continue
        src="${project_root}/${repo}"
        dest="${wt}/${repo}"
        if [ -d "${src}/.git" ] || [ -f "${src}/.git" ]; then
            if [ -d "$dest" ]; then
                git -C "$src" worktree remove --force "$dest" 2>/dev/null \
                    || rm -rf "$dest"
            fi
        fi
    done < <(workvm_sandbox_project_repos)

    rm -rf "$wt"
}

workvm_sandbox_project_render_compose() {
    local id="$1"
    local compose_dir="$2"
    local wt="$3"
    local profile="$4"
    local port_base="$5"
    local mem="${6:-1g}"
    local cpus="${7:-1.0}"
    local gui="${WORKVM_SANDBOX_GUI:-0}"
    local meta_repo tmpl
    local bun_image host_uid host_gid pname

    meta_repo="$(workvm_sandbox_meta_repo)"
    tmpl="${meta_repo}/use-url-query/sandbox/compose.slim.yml"
    # Override opcional; default = imagem Bun+Node do Dockerfile.backend.
    bun_image="${HC_BUN_IMAGE:-use-url-query-sandbox-backend:tests}"
    host_uid="$(id -u)"
    host_gid="$(id -g)"

    workvm_sandbox_uq_ensure_backend_image || return 1

    mkdir -p "$compose_dir/artifacts"
    cp -f "$tmpl" "$compose_dir/compose.yaml"
    cp -f "${meta_repo}/use-url-query/sandbox/compose.gui.yml" "$compose_dir/compose.gui.yml"

    pname="$(workvm_sandbox_container_project_name "$id")"
    {
        printf 'COMPOSE_PROJECT_NAME=%s\n' "$pname"
        printf 'SB_WORKTREE=%s\n' "$wt"
        printf 'SB_BUN_IMAGE=%s\n' "$bun_image"
        printf 'HOST_UID=%s\n' "$host_uid"
        printf 'HOST_GID=%s\n' "$host_gid"
        printf 'SB_MEM=%s\n' "$mem"
        printf 'SB_CPUS=%s\n' "$cpus"
        printf 'SB_PORT_API=%s\n' "$((port_base + 0))"
        if [ "$gui" = "1" ] || [ "$gui" = "true" ]; then
            printf 'COMPOSE_FILE=compose.yaml:compose.gui.yml\n'
        else
            printf 'COMPOSE_FILE=compose.yaml\n'
        fi
    } >"$compose_dir/.env"

    if declare -F workvm_sandbox_meta_set >/dev/null; then
        workvm_sandbox_meta_set "$id" default_service backend
        workvm_sandbox_meta_set "$id" shared_data ""
    fi
}
