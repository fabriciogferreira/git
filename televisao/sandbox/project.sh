# Plugin Televisão para o Sandbox Manager.
# Problema: isolamento N× no mesmo Card sem copiar a VM; e2e sem host network.

workvm_sandbox_project_max() {
    printf '%s\n' "${WORKVM_SANDBOX_MAX:-2}"
}

workvm_sandbox_project_mem_limit() {
    local profile="$1"
    case "$profile" in
        e2e) printf '1536m\n' ;;
        *) printf '1g\n' ;;
    esac
}

workvm_sandbox_project_cpus() {
    local profile="$1"
    case "$profile" in
        e2e) printf '1.5\n' ;;
        *) printf '1.0\n' ;;
    esac
}

workvm_sandbox_project_repos() {
    # Paths relative to ~/git/televisao/
    printf '%s\n' televisao-api televisao-front televisao-meet-front televisao-meet-core
}

workvm_sandbox_project_prepare_worktrees() {
    local id="$1"
    local wt="$2"
    local from_commit="${3:-}"
    local git_root project_root repo src dest
    git_root="$(workvm_sandbox_git_root)"
    project_root="${git_root}/televisao"

    mkdir -p "$wt/e2e"
    # Marker so php -S has an index and jobs can write scratch files.
    if [ ! -f "$wt/index.php" ]; then
        printf '<?php echo "sandbox %s\\n";\n' "$id" >"$wt/index.php"
    fi
    printf 'sandbox=%s\n' "$id" >"$wt/.sandbox-id"

    # Exclude sandbox worktrees from the meta-repo / clone noise.
    local exclude="${project_root}/.git/info/exclude"
    if [ -d "${project_root}/.git" ] || [ -f "${project_root}/.git" ]; then
        mkdir -p "$(dirname "$exclude")"
        touch "$exclude"
        if ! grep -qxF '/.sandboxes/' "$exclude" 2>/dev/null; then
            printf '/.sandboxes/\n' >>"$exclude"
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
            if [ -n "$from_commit" ]; then
                git -C "$src" worktree add --detach "$dest" "$from_commit"
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
    local git_root project_root repo src
    git_root="$(workvm_sandbox_git_root)"
    project_root="${git_root}/televisao"

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

    meta_repo="$(workvm_sandbox_meta_repo)"
    tmpl="${meta_repo}/televisao/sandbox/compose.slim.yml"

    mkdir -p "$compose_dir/artifacts" "$wt/e2e"
    cp -f "$tmpl" "$compose_dir/compose.yaml"
    cp -f "${meta_repo}/televisao/sandbox/compose.gui.yml" "$compose_dir/compose.gui.yml"

    local api_port=$((port_base + 0))
    local pname
    pname="$(workvm_sandbox_container_project_name "$id")"
    {
        printf 'COMPOSE_PROJECT_NAME=%s\n' "$pname"
        printf 'SB_WORKTREE=%s\n' "$wt"
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
