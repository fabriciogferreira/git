#!/usr/bin/env bash
# Clone, fetch, overlay e identidade desta VM.
# Problema: isso estava no meio de common.sh e achar uma função exigia ler o arquivo inteiro.
# Carregado por common.sh. Não dê source neste arquivo sozinho.

# Walk up until the meta-repo root (lib/common.sh next to project-setup.sh).
workvm_discover_repo_root() {
    local dir="${1:-}"
    if [ -z "$dir" ]; then
        echo "error: workvm_discover_repo_root <start-dir>" >&2
        return 1
    fi
    dir="$(cd "$dir" && pwd)"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/lib/common.sh" ] && [ -f "$dir/project-setup.sh" ]; then
            printf '%s\n' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    echo "error: meta-repo root não encontrado a partir de: $1" >&2
    return 1
}

# Load USER_NAME, GIT_USER_NAME, GIT_USER_EMAIL from <repo>/vm.local.conf.
# Variables already set in the environment stay. The file is not versioned.
# If missing, copies vm.local.conf.example → vm.local.conf (then sources it).
# Returns 1 if neither file exists.
workvm_load_vm_local() {
    local repo_root="${1:-}"
    local file example saved_user saved_name saved_email
    if [ -z "$repo_root" ]; then
        echo "error: workvm_load_vm_local <repo-root>" >&2
        return 1
    fi
    file="$repo_root/vm.local.conf"
    example="$repo_root/vm.local.conf.example"
    if [ ! -f "$file" ]; then
        if [ ! -f "$example" ]; then
            echo "error: falta $file e $example" >&2
            return 1
        fi
        echo "→ criando $file a partir de vm.local.conf.example"
        cp "$example" "$file"
    fi
    saved_user="${USER_NAME-}"
    saved_name="${GIT_USER_NAME-}"
    saved_email="${GIT_USER_EMAIL-}"
    # shellcheck source=/dev/null
    source "$file"
    # Use if (not &&): with set -e, a failing `[ -n ] && …` would make this
    # function return 1 and abort vm-setup via `|| exit 1`.
    if [ -n "$saved_user" ]; then USER_NAME="$saved_user"; fi
    if [ -n "$saved_name" ]; then GIT_USER_NAME="$saved_name"; fi
    if [ -n "$saved_email" ]; then GIT_USER_EMAIL="$saved_email"; fi
    return 0
}

# Absolute path of a project dir (has project.conf).
# Prefers <git-root>/<id>/ over <git-root>/projects/<id>/ (product roots win).
workvm_project_dir() {
    local git_root="${1:-}"
    local id="${2:-}"

    if [ -z "$git_root" ] || [ -z "$id" ]; then
        return 1
    fi
    if [ -f "$git_root/$id/project.conf" ]; then
        printf '%s\n' "$git_root/$id"
        return 0
    fi
    if [ -f "$git_root/projects/$id/project.conf" ]; then
        printf '%s\n' "$git_root/projects/$id"
        return 0
    fi
    return 1
}

# Print project ids (e.g. opbed, olie, televisao).
# A project is a directory with project.conf under projects/ or at <git-root>/<id>/.
# Arg: meta-repo root (~/git), not only projects/.
workvm_list_project_ids() {
    local git_root="${1:-}"
    local conf dir id
    if [ -z "$git_root" ] || [ ! -d "$git_root" ]; then
        echo "error: workvm_list_project_ids <git-root>" >&2
        return 1
    fi
    {
        if [ -d "$git_root/projects" ]; then
            find "$git_root/projects" -mindepth 2 -maxdepth 2 -type f -name project.conf -print0
        fi
        find "$git_root" -mindepth 2 -maxdepth 2 -type f -name project.conf -print0
    } | while IFS= read -r -d '' conf; do
        dir="$(dirname "$conf")"
        id="$(basename "$dir")"
        # Skip accidental project.conf inside clone paths (depth would usually
        # exclude them; basename collision still prints once via sort -u).
        case "$dir" in
            */projects/*/*/*) continue ;;
        esac
        printf '%s\n' "$id"
    done | sort -u
}

# Resolve a user project argument to a project id (basename).
# Accepts the directory id (televisao) or a unique basename.
# Prints the id on stdout; returns 1 if missing/ambiguous.
workvm_resolve_project_id() {
    local git_root="${1:-}"
    local answer="${2:-}"
    local id base
    local -a matches=()

    if [ -z "$git_root" ] || [ -z "$answer" ]; then
        return 1
    fi

    if workvm_project_dir "$git_root" "$answer" >/dev/null; then
        printf '%s\n' "$answer"
        return 0
    fi

    while IFS= read -r id; do
        [ -n "$id" ] || continue
        base="$(basename "$id")"
        if [ "$id" = "$answer" ] || [ "$base" = "$answer" ]; then
            matches+=("$id")
        fi
    done < <(workvm_list_project_ids "$git_root")

    if [ "${#matches[@]}" -eq 1 ]; then
        printf '%s\n' "${matches[0]}"
        return 0
    fi
    if [ "${#matches[@]}" -gt 1 ]; then
        echo "error: projeto ambíguo '$answer' — use o id completo:" >&2
        local m
        for m in "${matches[@]}"; do
            echo "  $m" >&2
        done
        return 1
    fi
    return 1
}

# True if this VM already has a project bound by project-setup.sh
# (~/.config/workvm/current → dir with project.conf).
workvm_project_is_setup() {
    local current="${XDG_CONFIG_HOME:-$HOME/.config}/workvm/current"
    local resolved

    resolved="$(readlink -f "$current" 2>/dev/null)" || return 1
    [ -f "$resolved/project.conf" ]
}

# git fetch --prune when HEAD already matches the expected branch (no checkout/merge).
# Never fails the caller: missing repo / wrong branch / network only warn.
workvm_fetch_repo() {
    local destination="$1"
    local branch="${2:-}"
    local current

    if [ ! -d "$destination/.git" ]; then
        echo "→ Fetch pulado: $destination (não é um repositório git)"
        return 0
    fi

    current="$(git -C "$destination" branch --show-current 2>/dev/null || true)"

    if [ -n "$branch" ] && [ "$current" != "$branch" ]; then
        echo "→ Fetch pulado: $destination (branch atual: ${current:-detached}; esperado: $branch)"
        return 0
    fi

    echo "→ Fetch: $destination${branch:+ ($branch)}"
    if ! git -C "$destination" fetch --prune origin; then
        echo "aviso: fetch falhou: $destination (rede?)" >&2
        return 0
    fi
}

# Entries: "<git-url> <path> [branch]" (same format as CLONE_REPOS).
workvm_fetch_project_repos() {
    local git_root="${GIT_ROOT:-$HOME/git}"
    local entry dest branch rest

    for entry in "$@"; do
        rest="${entry#* }"
        if [ -z "$rest" ] || [ "$entry" = "$rest" ]; then
            echo "aviso: CLONE_REPOS entry inválida no fetch: $entry" >&2
            continue
        fi
        dest="${rest%% *}"
        if [ "$dest" = "$rest" ]; then
            branch=""
        else
            branch="${rest#* }"
            branch="${branch%% *}"
        fi
        case "$dest" in
            /*) ;;
            *) dest="${git_root}/${dest}" ;;
        esac
        # Sem branch de origem no clone: não há como validar; pula.
        if [ -z "$branch" ]; then
            echo "→ Fetch pulado: $dest (sem branch de origem no CLONE_REPOS)"
            continue
        fi
        workvm_fetch_repo "$dest" "$branch"
    done
}

# Fast-forward only when HEAD already matches the CLONE_REPOS branch (no checkout).
workvm_pull_repo() {
    local destination="$1"
    local branch="${2:-}"
    local current origin_ref

    current="$(git -C "$destination" branch --show-current 2>/dev/null || true)"

    if [ -n "$branch" ] && [ "$current" != "$branch" ]; then
        echo "→ Pull pulado: $destination (branch atual: ${current:-detached}; esperado: $branch)"
        return 0
    fi

    echo "→ Pull: $destination${branch:+ ($branch)}"
    git -C "$destination" fetch --prune origin

    if [ -n "$branch" ]; then
        origin_ref="origin/${branch}"
        if ! git -C "$destination" rev-parse --verify "$origin_ref" >/dev/null 2>&1; then
            echo "error: $destination não tem $origin_ref após fetch" >&2
            return 1
        fi
        git -C "$destination" merge --ff-only "$origin_ref"
    else
        git -C "$destination" pull --ff-only
    fi
}

workvm_clone_repo() {
    local repo="$1"
    local destination="$2"
    local branch="${3:-}"

    mkdir -p "$(dirname "$destination")"

    if [ ! -d "$destination/.git" ]; then
        if [ -n "$branch" ]; then
            echo "→ Clonando: $repo ($branch) → $destination"
            # Keep --branch for initial checkout, but fetch all remote heads
            # (not --single-branch) so teammates' feature branches are visible.
            git clone --branch "$branch" "$repo" "$destination"
        else
            echo "→ Clonando: $repo → $destination"
            git clone "$repo" "$destination"
        fi
    else
        echo "✓ Já existe: $destination"
    fi

    workvm_pull_repo "$destination" "$branch"
}

# Espera github.com resolver.
# Problema: o autologin abre o menu do project-setup antes do DHCP. O git
# clone morre com "Temporary failure in name resolution"; a frase de access
# rights do git é genérica e parece permissão de SSH.
# Se já resolve, retorna na hora. Não espera no fetch do login (esse só avisa).
workvm_wait_for_github_dns() {
    local host="github.com"
    local timeout="${1:-60}"
    local elapsed=0

    if getent hosts "$host" >/dev/null 2>&1; then
        return 0
    fi

    echo "==> Rede ainda sem DNS ($host); esperando até ${timeout}s"
    while [ "$elapsed" -lt "$timeout" ]; do
        sleep 1
        elapsed=$((elapsed + 1))
        if getent hosts "$host" >/dev/null 2>&1; then
            echo "✓ DNS ok: $host"
            return 0
        fi
    done

    echo "error: DNS não resolveu $host em ${timeout}s (DHCP desta VM ainda não subiu?)" >&2
    return 1
}

# Entries: "<git-url> <path> [branch]". Relative paths are under GIT_ROOT (default $HOME/git).
workvm_clone_project_repos() {
    local git_root="${GIT_ROOT:-$HOME/git}"
    local entry repo dest branch rest

    workvm_wait_for_github_dns

    mkdir -p "$git_root"

    for entry in "$@"; do
        repo="${entry%% *}"
        rest="${entry#* }"
        if [ -z "$rest" ] || [ "$repo" = "$rest" ]; then
            echo "error: CLONE_REPOS entry inválida: $entry" >&2
            return 1
        fi
        dest="${rest%% *}"
        if [ "$dest" = "$rest" ]; then
            branch=""
        else
            branch="${rest#* }"
            branch="${branch%% *}"
        fi
        case "$dest" in
            /*) ;;
            *) dest="${git_root}/${dest}" ;;
        esac
        workvm_clone_repo "$repo" "$dest" "$branch"
    done
}

workvm_git_relpath() {
    local repo="$1"
    local file="$2"
    local rel
    rel="${file#"${repo}/"}"
    if [ "$rel" = "$file" ]; then
        rel="$(basename "$file")"
    fi
    printf '%s\n' "$rel"
}

workvm_git_skip_worktree() {
    local repo="$1"
    local file="$2"
    local rel
    rel="$(workvm_git_relpath "$repo" "$file")"
    git -C "$repo" update-index --skip-worktree -- "$rel" 2>/dev/null || true
}

workvm_git_unskip_worktree() {
    local repo="$1"
    local file="$2"
    local rel
    rel="$(workvm_git_relpath "$repo" "$file")"
    git -C "$repo" update-index --no-skip-worktree -- "$rel" 2>/dev/null || true
}

workvm_git_exclude_add() {
    local repo="$1"
    local pattern="$2"
    local exclude="$repo/.git/info/exclude"
    [ -d "$repo/.git" ] || return 0
    mkdir -p "$(dirname "$exclude")"
    touch "$exclude"
    if ! grep -qxF "$pattern" "$exclude" 2>/dev/null; then
        printf '%s\n' "$pattern" >>"$exclude"
    fi
}

# Copy one overlay repo dir onto a clone.
# A directory named cursor/ becomes .cursor/ on the clone. The source has no
# dot so the workvm workspace does not load these product rules.
workvm_sync_overlay_repo() {
    local src="$1"
    local dest="$2"
    local item name target

    shopt -s nullglob dotglob
    for item in "$src"/*; do
        name="$(basename "$item")"
        if [ "$name" = ".gitkeep" ]; then
            continue
        fi
        if [ "$name" = "cursor" ] && [ -d "$item" ]; then
            target="$dest/.cursor"
        else
            target="$dest/$name"
        fi
        if [ -d "$item" ]; then
            mkdir -p "$target"
            if command -v rsync >/dev/null 2>&1; then
                rsync -a "$item/" "$target/"
            else
                cp -a "$item"/. "$target"/
            fi
        elif [ -f "$item" ]; then
            cp -a "$item" "$target"
        fi
    done
    shopt -u nullglob dotglob
}

# Mirror <project_dir>/overlay/<repo>/ onto GIT_ROOT/<clone_prefix>/<repo>/.
# Example: overlay/olie-fronts/cursor → ~/git/olie/olie-fronts/.cursor
# Skips a repo whose clone does not exist yet.
# Safe to run on every boot (rsync -a, no --delete).
workvm_apply_files() {
    local project_dir="$1"
    local clone_prefix="$2"
    local git_root="${GIT_ROOT:-$HOME/git}"
    local src child base dest

    if [ -z "$project_dir" ] || [ -z "$clone_prefix" ]; then
        echo "error: workvm_apply_files <project_dir> <clone_prefix>" >&2
        return 1
    fi

    src="${project_dir}/overlay"
    if [ ! -d "$src" ]; then
        echo "→ overlay: nada em ${project_dir}/overlay"
        workvm_patch_project_clone_cursor "$clone_prefix"
        return 0
    fi

    echo "→ Aplicando overlay/ → ${git_root}/${clone_prefix}/"
    shopt -s nullglob dotglob
    for child in "$src"/*; do
        base="$(basename "$child")"
        if [ "$base" = ".gitkeep" ] || [ "$base" = "README.md" ]; then
            continue
        fi
        dest="${git_root}/${clone_prefix}/${base}"
        if [ ! -e "$dest" ]; then
            echo "  pulado (destino ausente): ${clone_prefix}/${base}"
            continue
        fi
        echo "  sync: ${clone_prefix}/${base}/"
        workvm_sync_overlay_repo "$child" "$dest"
    done
    shopt -u nullglob dotglob

    workvm_patch_project_clone_cursor "$clone_prefix"
}

# Entries: "<path> <command...>". Relative paths are under GIT_ROOT (default $HOME/git).
workvm_run_post_clone() {
    local git_root="${GIT_ROOT:-$HOME/git}"
    local entry dest cmd

    for entry in "$@"; do
        dest="${entry%% *}"
        cmd="${entry#* }"
        if [ -z "$dest" ] || [ -z "$cmd" ] || [ "$dest" = "$cmd" ]; then
            echo "error: POST_CLONE entry inválida: $entry" >&2
            return 1
        fi
        case "$dest" in
            /*) ;;
            *) dest="${git_root}/${dest}" ;;
        esac
        if [ ! -d "$dest" ]; then
            echo "aviso: POST_CLONE pulado (dir ausente): $dest" >&2
            continue
        fi
        echo "→ Pós-clone ($dest): $cmd"
        (cd "$dest" && eval "$cmd")
    done
}
