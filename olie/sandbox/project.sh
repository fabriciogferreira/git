# Plugin Olie para o Sandbox Manager.
# Problema: mutation/Pest no Card VM compartilhavam MySQL `testing` e
# corrompiam `api_main` quando o colleague-review disparava gates em paralelo.
# Isola worktree + MySQL/Redis/Mongo por COMPOSE_PROJECT_NAME (como Televisão).

workvm_sandbox_project_max() {
    # Guest Olie costuma ter 12 GiB — teto inicial 3; calibrar na medição.
    printf '%s\n' "${WORKVM_SANDBOX_MAX:-3}"
}

workvm_sandbox_project_mem_limit() {
    local profile="$1"
    case "$profile" in
        e2e) printf '1536m\n' ;;
        mutation) printf '1536m\n' ;;
        *) printf '1g\n' ;;
    esac
}

workvm_sandbox_project_cpus() {
    local profile="$1"
    case "$profile" in
        e2e) printf '1.5\n' ;;
        mutation) printf '1.5\n' ;;
        *) printf '1.0\n' ;;
    esac
}

workvm_sandbox_project_repos() {
    # Paths relative to ~/git/olie/ (clones da empresa).
    printf '%s\n' api-main olie-fronts
}

workvm_sandbox_olie_ensure_sandbox_image() {
    local meta_repo
    meta_repo="$(workvm_sandbox_meta_repo)"
    if docker image inspect olie/api-main-sandbox:latest >/dev/null 2>&1; then
        return 0
    fi
    if ! docker image inspect olie/api-main:latest >/dev/null 2>&1; then
        workvm_sandbox_log "imagem olie/api-main:latest ausente; suba o compose da Card VM antes"
        return 1
    fi
    workvm_sandbox_log "build olie/api-main-sandbox:latest (PCOV)"
    docker build -t olie/api-main-sandbox:latest \
        -f "${meta_repo}/olie/sandbox/Dockerfile.app" \
        "${meta_repo}/olie/sandbox"
}

workvm_sandbox_olie_link_vendor() {
    # Vendor is bind-mounted via SB_API_VENDOR in compose (absolute host
    # symlinks break inside the container). Only link node_modules for host tools.
    local src="$1"
    local dest="$2"
    if [ -e "${src}/node_modules" ] && [ ! -e "${dest}/node_modules" ]; then
        ln -sfn "${src}/node_modules" "${dest}/node_modules"
    fi
    # Placeholder so accidental host php without the mount fails clearly.
    if [ ! -e "${dest}/vendor" ]; then
        mkdir -p "${dest}/vendor"
        printf '# mounted at runtime as SB_API_VENDOR → /var/www/html/vendor\n' \
            >"${dest}/vendor/README.sandbox.md"
    fi
}

workvm_sandbox_olie_write_env() {
    local src_env="$1"
    local dest_env="$2"
    if [ -f "$src_env" ]; then
        cp -f "$src_env" "$dest_env"
    else
        printf 'APP_KEY=base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\n' >"$dest_env"
    fi
    # Força hosts do compose slim (não o stack da Card VM).
    local key val
    for key in \
        DB_HOST=mysql \
        DB_PORT=3306 \
        DB_DATABASE=api_main \
        DB_USERNAME=sandbox \
        DB_PASSWORD=sandbox \
        MONGODB_HOST=mongo \
        MONGODB_PORT=27017 \
        MONGODB_DATABASE=api_main \
        MONGODB_USERNAME=sandbox \
        MONGODB_PASSWORD=sandbox \
        REDIS_HOST=redis \
        REDIS_PORT=6379 \
        REDIS_PASSWORD=null
    do
        val="${key#*=}"
        key="${key%%=*}"
        if grep -q "^${key}=" "$dest_env" 2>/dev/null; then
            sed -i "s|^${key}=.*|${key}=${val}|" "$dest_env"
        else
            printf '%s=%s\n' "$key" "$val" >>"$dest_env"
        fi
    done
}

workvm_sandbox_project_prepare_worktrees() {
    local id="$1"
    local wt="$2"
    local from_commit="${3:-}"
    local git_root project_root repo src dest
    git_root="$(workvm_sandbox_git_root)"
    project_root="${git_root}/olie"

    mkdir -p "$wt/e2e"
    printf 'sandbox=%s\n' "$id" >"$wt/.sandbox-id"

    # Exclude sandbox worktrees from the meta-repo noise.
    local exclude="${project_root}/.git/info/exclude"
    if [ -d "${project_root}/.git" ] || [ -f "${project_root}/.git" ]; then
        mkdir -p "$(dirname "$exclude")"
        touch "$exclude"
        if ! grep -qxF '/.sandboxes/' "$exclude" 2>/dev/null; then
            printf '/.sandboxes/\n' >>"$exclude"
        fi
    fi
    # Meta-repo root also lists olie/.sandboxes when project_root is not a git dir.
    exclude="$(workvm_sandbox_meta_repo)/.git/info/exclude"
    if [ -d "$(dirname "$exclude")" ]; then
        mkdir -p "$(dirname "$exclude")"
        touch "$exclude"
        if ! grep -qxF '/olie/.sandboxes/' "$exclude" 2>/dev/null; then
            printf '/olie/.sandboxes/\n' >>"$exclude"
        fi
    fi

    while IFS= read -r repo; do
        [ -n "$repo" ] || continue
        src="${project_root}/${repo}"
        dest="${wt}/${repo}"
        if [ -d "${src}/.git" ] || [ -f "${src}/.git" ]; then
            if [ -d "$dest" ]; then
                workvm_sandbox_olie_link_vendor "$src" "$dest"
                continue
            fi
            workvm_sandbox_log "worktree $repo → $dest"
            if [ -n "$from_commit" ]; then
                git -C "$src" worktree add --detach "$dest" "$from_commit"
            else
                git -C "$src" worktree add --detach "$dest" HEAD
            fi
            workvm_sandbox_olie_link_vendor "$src" "$dest"
            mkdir -p "${dest}/storage/logs" \
                "${dest}/storage/framework/cache" \
                "${dest}/storage/framework/sessions" \
                "${dest}/storage/framework/views" \
                "${dest}/bootstrap/cache"
            if [ "$repo" = "api-main" ]; then
                workvm_sandbox_olie_write_env "${src}/.env" "${dest}/.env"
            fi
        else
            mkdir -p "$dest"
            printf '# clone %s ausente neste host; dir vazio no sandbox\n' "$repo" >"$dest/README.sandbox.md"
        fi
    done < <(workvm_sandbox_project_repos)

    # olie-e2e vive no meta-repo (não é clone separado).
    local e2e_src="${project_root}/olie-e2e"
    if [ -d "$e2e_src" ] && [ ! -e "${wt}/e2e/package.json" ]; then
        # Cópia leve de specs — evita e2e paralelo no mesmo tree do meta-repo.
        rsync -a --delete \
            --exclude node_modules --exclude test-results --exclude playwright-report \
            "${e2e_src}/" "${wt}/e2e/" 2>/dev/null \
            || cp -a "${e2e_src}/." "${wt}/e2e/"
    fi
}

workvm_sandbox_project_remove_worktrees() {
    local id="$1"
    local wt="$2"
    local git_root project_root repo src dest
    git_root="$(workvm_sandbox_git_root)"
    project_root="${git_root}/olie"

    while IFS= read -r repo; do
        [ -n "$repo" ] || continue
        src="${project_root}/${repo}"
        dest="${wt}/${repo}"
        if [ -d "${src}/.git" ] || [ -f "${src}/.git" ]; then
            if [ -d "$dest" ]; then
                if [ -L "${dest}/node_modules" ]; then
                    rm -f "${dest}/node_modules"
                fi
                # Placeholder vendor/ dir (not a git link) — remove so worktree remove is clean.
                if [ -d "${dest}/vendor" ] && [ ! -L "${dest}/vendor" ]; then
                    rm -rf "${dest}/vendor"
                fi
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

    meta_repo="$(workvm_sandbox_meta_repo)"
    tmpl="${meta_repo}/olie/sandbox/compose.slim.yml"

    workvm_sandbox_olie_ensure_sandbox_image || return 1

    mkdir -p "$compose_dir/artifacts" "$wt/e2e" "$wt/api-main"
    cp -f "$tmpl" "$compose_dir/compose.yaml"
    cp -f "${meta_repo}/olie/sandbox/compose.gui.yml" "$compose_dir/compose.gui.yml"

    local api_port=$((port_base + 0))
    local pname
    pname="$(workvm_sandbox_container_project_name "$id")"
    local git_root api_vendor
    git_root="$(workvm_sandbox_git_root)"
    api_vendor="${git_root}/olie/api-main/vendor"
    if [ ! -f "${api_vendor}/autoload.php" ]; then
        workvm_sandbox_log "vendor ausente em ${api_vendor} (rode composer na Card VM)"
        return 1
    fi

    {
        printf 'COMPOSE_PROJECT_NAME=%s\n' "$pname"
        printf 'SB_WORKTREE=%s\n' "$wt"
        printf 'SB_API_VENDOR=%s\n' "$api_vendor"
        printf 'SB_MYSQL_INIT=%s\n' "${meta_repo}/olie/sandbox/mysql-init"
        printf 'SB_MEM=%s\n' "$mem"
        printf 'SB_CPUS=%s\n' "$cpus"
        printf 'SB_PORT_API=%s\n' "$api_port"
        printf 'SB_PORT_FRONT=%s\n' "$((port_base + 1))"
        if [ "$gui" = "1" ] || [ "$gui" = "true" ]; then
            printf 'COMPOSE_FILE=compose.yaml:compose.gui.yml\n'
        else
            printf 'COMPOSE_FILE=compose.yaml\n'
        fi
    } >"$compose_dir/.env"
}
