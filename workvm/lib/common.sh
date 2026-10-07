#!/usr/bin/env bash
# Shared helpers for workvm project startups.

# Walk up from a path until ~/git-style meta root (directory that contains workvm/lib/common.sh).
workvm_discover_repo_root() {
    local dir="${1:-}"
    if [ -z "$dir" ]; then
        echo "error: workvm_discover_repo_root <start-dir>" >&2
        return 1
    fi
    dir="$(cd "$dir" && pwd)"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/workvm/lib/common.sh" ]; then
            printf '%s\n' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    echo "error: meta-repo root não encontrado a partir de: $1" >&2
    return 1
}

# Print project ids relative to workvm/projects (e.g. opbed, olie-ai/televisao).
# A project is a directory with both project.conf and start.sh.
workvm_list_project_ids() {
    local projects_dir="${1:-}"
    local conf rel dir
    if [ -z "$projects_dir" ] || [ ! -d "$projects_dir" ]; then
        echo "error: workvm_list_project_ids <projects-dir>" >&2
        return 1
    fi
    while IFS= read -r -d '' conf; do
        dir="$(dirname "$conf")"
        [ -f "$dir/start.sh" ] || continue
        rel="${dir#"${projects_dir}/"}"
        [ "$rel" != "$dir" ] || continue
        printf '%s\n' "$rel"
    done < <(find "$projects_dir" -type f -name project.conf -print0 | sort -z)
}

# Resolve a user project argument to a relative id under workvm/projects.
# Accepts full id (olie-ai/televisao) or unique basename (televisao).
# Prints the id on stdout; returns 1 if missing/ambiguous.
workvm_resolve_project_id() {
    local projects_dir="${1:-}"
    local answer="${2:-}"
    local id base
    local -a matches=()

    if [ -z "$projects_dir" ] || [ -z "$answer" ]; then
        return 1
    fi

    if [ -f "$projects_dir/$answer/project.conf" ] && [ -f "$projects_dir/$answer/start.sh" ]; then
        printf '%s\n' "$answer"
        return 0
    fi

    while IFS= read -r id; do
        [ -n "$id" ] || continue
        base="$(basename "$id")"
        if [ "$id" = "$answer" ] || [ "$base" = "$answer" ]; then
            matches+=("$id")
        fi
    done < <(workvm_list_project_ids "$projects_dir")

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
            git clone --branch "$branch" --single-branch "$repo" "$destination"
        else
            echo "→ Clonando: $repo → $destination"
            git clone "$repo" "$destination"
        fi
    else
        echo "✓ Já existe: $destination"
    fi

    workvm_pull_repo "$destination" "$branch"
}

# Entries: "<git-url> <path> [branch]". Relative paths are under GIT_ROOT (default $HOME/git).
workvm_clone_project_repos() {
    local git_root="${GIT_ROOT:-$HOME/git}"
    local entry repo dest branch rest

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

# Write workvm/.cursor/rules/workvm-project.mdc (alwaysApply) so Cursor agents
# know which workvm project this machine is bound to and where the clones live.
# Lives under workvm/ so multi-root workspaces can use root "workvm" without
# opening all of ~/git (avoids nested files/*/ .cursor noise).
# Expects CLONE_REPOS (and optionally COMPOSE_DIR, WAIT_URL, CHROMIUM_URLS)
# already sourced from project.conf. Safe to re-run.
workvm_write_cursor_project_rule() {
    local repo_root="$1"
    local project="$2"
    local git_root="${GIT_ROOT:-$HOME/git}"
    local out="$repo_root/workvm/.cursor/rules/workvm-project.mdc"
    local entry repo dest branch rest abs compose_disp
    local -a rows=()

    if [ -z "$repo_root" ] || [ -z "$project" ]; then
        echo "error: workvm_write_cursor_project_rule <repo_root> <project>" >&2
        return 1
    fi

    mkdir -p "$(dirname "$out")"

    for entry in "${CLONE_REPOS[@]+"${CLONE_REPOS[@]}"}"; do
        [ -n "$entry" ] || continue
        repo="${entry%% *}"
        rest="${entry#* }"
        if [ -z "$rest" ] || [ "$repo" = "$rest" ]; then
            echo "aviso: CLONE_REPOS entry inválida na rule Cursor: $entry" >&2
            continue
        fi
        dest="${rest%% *}"
        if [ "$dest" = "$rest" ]; then
            branch="—"
        else
            branch="${rest#* }"
            branch="${branch%% *}"
        fi
        case "$dest" in
            /*) abs="$dest" ;;
            *) abs="${git_root}/${dest}" ;;
        esac
        rows+=("| \`${repo}\` | \`${abs}\` | \`${branch}\` |")
    done

    compose_disp="${COMPOSE_DIR:-—}"
    case "$compose_disp" in
        /*) ;;
        —) ;;
        *) compose_disp="${git_root}/${compose_disp}" ;;
    esac

    local compose_file_disp="${COMPOSE_FILE:-docker-compose.yml}"
    local wait_disp="${WAIT_URL:-—}"
    local browser_disp="—"
    if [ "${#CHROMIUM_URLS[@]}" -gt 0 ]; then
        browser_disp="${CHROMIUM_URLS[*]}"
    fi

    cat >"$out" <<EOF
---
description: Projeto workvm ativo nesta VM (${project}) — repos e caminhos
alwaysApply: true
---

# WorkVM ativo: \`${project}\`

> Gerado por \`project-setup.sh\` via \`workvm_write_cursor_project_rule\`.
> Não edite à mão — rode de novo o project-setup para atualizar.
> Runtime symlink: \`~/.config/workvm/current\` → \`workvm/projects/${project}\`.
> Cursor workspace root for meta: \`workvm/\` (not all of ~/git).

## Repositórios

| Git URL | Caminho local | Branch |
| --- | --- | --- |
EOF

    if [ "${#rows[@]}" -gt 0 ]; then
        local row
        for row in "${rows[@]}"; do
            printf '%s\n' "$row" >>"$out"
        done
    else
        printf '%s\n' '| _(nenhum CLONE_REPOS)_ | — | — |' >>"$out"
    fi

    cat >>"$out" <<EOF

## Runtime

- **Compose dir:** \`${compose_disp}\`
- **Compose file:** \`${compose_file_disp}\`
- **Wait URL:** \`${wait_disp}\`
- **Browser URLs:** \`${browser_disp}\`
- **Workspace:** \`workvm/projects/${project}/workspace.code-workspace\`
- **Start:** \`workvm/projects/${project}/start.sh\` (também via \`workvm.service\`)

Ao trabalhar nesta VM, trate os caminhos da tabela como o escopo do projeto ativo.
EOF

    echo "→ Cursor rule: $out"
}

# --- Local Cursor patches on clones (never commit; skip-worktree) -----------------
# Multi-root loads alwaysApply from every root. Downgrade clone alwaysApply rules
# to globs, and relocate AGENTS.md into a globs-scoped .mdc, so backend-only chats
# do not pull frontend alwaysApply noise. Remote repos stay unchanged if not committed.

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

# Rewrite .mdc frontmatter: alwaysApply true → false; ensure globs present.
workvm_patch_mdc_always_apply() {
    local file="$1"
    python3 - "$file" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
if not text.startswith("---"):
    sys.exit(0)
parts = text.split("---", 2)
if len(parts) < 3:
    sys.exit(0)
fm, body = parts[1], parts[2]
if not re.search(r"(?m)^alwaysApply:\s*true\s*$", fm):
    sys.exit(0)
fm = re.sub(r"(?m)^alwaysApply:\s*true\s*$", "alwaysApply: false", fm)
if not re.search(r"(?m)^globs:\s*", fm):
    fm = fm.rstrip() + '\nglobs: "**/*"\n'
else:
    fm = fm if fm.endswith("\n") else fm + "\n"
open(path, "w", encoding="utf-8").write(f"---{fm}---{body}")
print(path)
PY
}

# One clone: patch alwaysApply .mdc + relocate AGENTS.md → globs-scoped rule.
workvm_patch_clone_cursor() {
    local clone="$1"
    local rules_dir agents dest_mdc f patched

    if [ ! -d "$clone/.git" ]; then
        return 0
    fi

    rules_dir="$clone/.cursor/rules"
    if [ -d "$rules_dir" ]; then
        shopt -s nullglob
        for f in "$rules_dir"/*.mdc; do
            # Skip our generated relocation target
            if [ "$(basename "$f")" = "workvm-local-agents.mdc" ]; then
                continue
            fi
            if ! grep -qE '^alwaysApply:[[:space:]]*true[[:space:]]*$' "$f"; then
                continue
            fi
            workvm_git_unskip_worktree "$clone" "$f"
            patched="$(workvm_patch_mdc_always_apply "$f" || true)"
            if [ -n "$patched" ]; then
                workvm_git_skip_worktree "$clone" "$f"
                echo "  cursor patch: ${f#"${clone}/"} (alwaysApply→false + globs)"
            fi
        done
        shopt -u nullglob
    fi

    agents="$clone/AGENTS.md"
    dest_mdc="$clone/.cursor/rules/workvm-local-agents.mdc"
    if [ -f "$agents" ]; then
        mkdir -p "$clone/.cursor/rules"
        workvm_git_exclude_add "$clone" ".cursor/rules/workvm-local-agents.mdc"
        if grep -q 'workvm-local-agents.mdc' "$agents" 2>/dev/null && [ -f "$dest_mdc" ]; then
            workvm_git_skip_worktree "$clone" "$agents"
        else
            workvm_git_unskip_worktree "$clone" "$agents"
            cat >"$dest_mdc" <<EOF
---
description: AGENTS.md relocated by workvm (local only — do not commit)
globs: "**/*"
alwaysApply: false
---

EOF
            cat "$agents" >>"$dest_mdc"
            cat >"$agents" <<'EOF'
<!-- workvm-local: full AGENTS.md moved to .cursor/rules/workvm-local-agents.mdc -->
<!-- Local patch for multi-root Cursor (skip-worktree). Do not commit. -->

# Agent guidelines

Guidelines for this repository live in `.cursor/rules/workvm-local-agents.mdc`
(scoped with globs so they apply when files here are in focus, not in every
multi-root chat).
EOF
            workvm_git_skip_worktree "$clone" "$agents"
            echo "  cursor patch: AGENTS.md → .cursor/rules/workvm-local-agents.mdc"
        fi
    fi
}

# Patch all CLONE_REPOS for a project (uses sourced CLONE_REPOS or project.conf).
workvm_patch_project_clone_cursor() {
    local project="${1:-}"
    local git_root="${GIT_ROOT:-$HOME/git}"
    local entry repo dest rest abs
    local -a entries=()

    if [ -n "${CLONE_REPOS+x}" ] && [ "${#CLONE_REPOS[@]}" -gt 0 ]; then
        entries=("${CLONE_REPOS[@]}")
    elif [ -n "$project" ] && [ -f "$git_root/workvm/projects/$project/project.conf" ]; then
        # shellcheck disable=SC1090
        source "$git_root/workvm/projects/$project/project.conf"
        git_root="${GIT_ROOT:-$git_root}"
        entries=("${CLONE_REPOS[@]+"${CLONE_REPOS[@]}"}")
    else
        return 0
    fi

    if [ "${#entries[@]}" -eq 0 ]; then
        return 0
    fi

    local -a found=()
    for entry in "${entries[@]}"; do
        [ -n "$entry" ] || continue
        repo="${entry%% *}"
        rest="${entry#* }"
        if [ -z "$rest" ] || [ "$repo" = "$rest" ]; then
            continue
        fi
        dest="${rest%% *}"
        case "$dest" in
            /*) abs="$dest" ;;
            *) abs="${git_root}/${dest}" ;;
        esac
        if [ -d "$abs/.git" ]; then
            found+=("$abs")
        fi
    done

    if [ "${#found[@]}" -eq 0 ]; then
        return 0
    fi

    echo "→ Patch local Cursor rules nos clones (alwaysApply→globs; não commitar)"
    for abs in "${found[@]}"; do
        echo "  clone: $abs"
        workvm_patch_clone_cursor "$abs"
    done
}

# Patch clones for every workvm/projects/**/project.conf (or a single project id).
workvm_patch_all_projects_clone_cursor() {
    local only="${1:-}"
    local git_root="${GIT_ROOT:-$HOME/git}"
    local projects_dir="$git_root/workvm/projects"
    local proj resolved

    if [ -n "$only" ]; then
        if ! resolved="$(workvm_resolve_project_id "$projects_dir" "$only")"; then
            echo "error: projeto desconhecido: $only" >&2
            return 1
        fi
        unset CLONE_REPOS 2>/dev/null || true
        CLONE_REPOS=()
        # shellcheck disable=SC1090
        source "$projects_dir/$resolved/project.conf"
        workvm_patch_project_clone_cursor "$resolved"
        return 0
    fi

    while IFS= read -r proj; do
        [ -n "$proj" ] || continue
        unset CLONE_REPOS 2>/dev/null || true
        CLONE_REPOS=()
        # shellcheck disable=SC1090
        source "$projects_dir/$proj/project.conf"
        workvm_patch_project_clone_cursor "$proj"
    done < <(workvm_list_project_ids "$projects_dir")
}

# Mirror versioned overlays from files/<project>/ into GIT_ROOT/<project>/.
# Convention: files/olie/olie-fronts/.cursor → $GIT_ROOT/olie/olie-fronts/.cursor
# Skips first-level entries whose clone destination does not exist yet.
# Safe to run on every boot (rsync -a updates without --delete).
workvm_apply_files() {
    local files_root="$1"
    local project="$2"
    local git_root="${GIT_ROOT:-$HOME/git}"
    local src child base dest

    if [ -z "$files_root" ] || [ -z "$project" ]; then
        echo "error: workvm_apply_files <files_root> <project>" >&2
        return 1
    fi

    src="${files_root}/${project}"
    if [ ! -d "$src" ]; then
        echo "→ files: nada em files/${project}/"
        workvm_patch_project_clone_cursor "$project"
        return 0
    fi

    echo "→ Aplicando files/${project}/ → ${git_root}/${project}/"
    shopt -s nullglob dotglob
    for child in "$src"/*; do
        base="$(basename "$child")"
        # Skip scaffolding noise if present
        if [ "$base" = ".gitkeep" ]; then
            continue
        fi
        dest="${git_root}/${project}/${base}"
        if [ ! -e "$dest" ]; then
            echo "  pulado (destino ausente): ${project}/${base}"
            continue
        fi
        if [ -d "$child" ]; then
            echo "  sync dir: ${project}/${base}/"
            if command -v rsync >/dev/null 2>&1; then
                rsync -a "$child/" "$dest/"
            else
                cp -a "$child"/. "$dest"/
            fi
        elif [ -f "$child" ]; then
            echo "  sync file: ${project}/${base}"
            cp -a "$child" "$dest"
        fi
    done
    shopt -u nullglob dotglob

    workvm_patch_project_clone_cursor "$project"
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

workvm_ensure_session_env() {
    if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    fi

    if [ -z "${WAYLAND_DISPLAY:-}" ]; then
        if [ -S "${XDG_RUNTIME_DIR}/wayland-1" ]; then
            export WAYLAND_DISPLAY=wayland-1
        elif [ -S "${XDG_RUNTIME_DIR}/wayland-0" ]; then
            export WAYLAND_DISPLAY=wayland-0
        fi
    fi

    if [ -z "${DISPLAY:-}" ] && [ -n "${WAYLAND_DISPLAY:-}" ]; then
        export DISPLAY=:0
    fi
}

# Wait until a Wayland socket is available. Timeout in seconds (default 90).
# hyprctl is optional confirmation — socket presence is enough to proceed.
workvm_wait_for_wayland() {
    local timeout="${1:-90}"
    local elapsed=0

    workvm_ensure_session_env

    while [ "$elapsed" -lt "$timeout" ]; do
        workvm_ensure_session_env

        if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]; then
            if command -v hyprctl >/dev/null 2>&1; then
                hyprctl monitors -j >/dev/null 2>&1 || true
            fi
            return 0
        fi

        sleep 1
        elapsed=$((elapsed + 1))
    done

    echo "workvm: timed out waiting for Wayland (${timeout}s)" >&2
    return 1
}

# Wait until an HTTP URL responds (any status < 500, or connection accepted).
workvm_wait_for_http() {
    local url="$1"
    local timeout="${2:-120}"
    local elapsed=0
    local code

    while [ "$elapsed" -lt "$timeout" ]; do
        code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 "$url" 2>/dev/null || true)
        if [ -n "$code" ] && [ "$code" != "000" ]; then
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    echo "workvm: timed out waiting for $url (${timeout}s)" >&2
    return 1
}

# Load ~/.config/environment.d/*.conf into the current shell.
# Hyprland/Electron do not inherit systemd user manager env from environment.d;
# Cursor needs those vars for ${env:NAME} interpolation in mcp.json headers.
workvm_load_environment_d() {
    local dir="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d"
    local f line key val

    [ -d "$dir" ] || return 0

    for f in "$dir"/*.conf; do
        [ -f "$f" ] || continue
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                ''|\#*) continue ;;
            esac
            [[ "$line" == *=* ]] || continue
            key="${line%%=*}"
            val="${line#*=}"
            [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
            if [[ "$val" == \"*\" ]]; then
                val="${val:1:-1}"
            elif [[ "$val" == \'*\' ]]; then
                val="${val:1:-1}"
            fi
            export "${key}=${val}"
        done < "$f"
    done
}

workvm_open_cursor() {
    local workspace="$1"

    if [ ! -f "$workspace" ]; then
        echo "workvm: workspace not found: $workspace" >&2
        return 1
    fi

    if ! command -v cursor >/dev/null 2>&1; then
        echo "workvm: cursor not found in PATH" >&2
        return 1
    fi

    workvm_load_environment_d

    setsid cursor "$workspace" </dev/null >/tmp/workvm-cursor.log 2>&1 &
}

workvm_open_chromium() {
    if [ "$#" -eq 0 ]; then
        return 0
    fi

    local browser=""
    if command -v google-chrome-stable >/dev/null 2>&1; then
        browser=google-chrome-stable
    elif command -v google-chrome >/dev/null 2>&1; then
        browser=google-chrome
    elif command -v chromium >/dev/null 2>&1; then
        browser=chromium
    else
        echo "workvm: google-chrome/chromium not found in PATH" >&2
        return 1
    fi

    setsid "$browser" --new-window "$@" </dev/null >/tmp/workvm-browser.log 2>&1 &
}

workvm_docker_compose_up() {
    local compose_dir="$1"
    local compose_file="${2:-${COMPOSE_FILE:-}}"

    if [ ! -d "$compose_dir" ]; then
        echo "workvm: compose dir not found: $compose_dir" >&2
        return 1
    fi

    if [ -n "$compose_file" ]; then
        if [ ! -f "$compose_dir/$compose_file" ]; then
            echo "workvm: compose file not found: $compose_dir/$compose_file" >&2
            return 1
        fi
        (cd "$compose_dir" && docker compose -f "$compose_file" up -d)
        return
    fi

    if [ ! -f "$compose_dir/docker-compose.yml" ] \
        && [ ! -f "$compose_dir/docker-compose.yaml" ] \
        && [ ! -f "$compose_dir/compose.yml" ] \
        && [ ! -f "$compose_dir/compose.yaml" ]; then
        echo "workvm: no compose file in $compose_dir" >&2
        return 1
    fi

    (cd "$compose_dir" && docker compose up -d)
}

# Merge top-level keys from $2 (source) into $1 (dest). Creates dest if missing.
# Existing keys are overwritten, missing keys are added; other dest keys stay.
# Tolerates JSONC (trailing commas / // /* */ comments) common in VS Code settings.
workvm_merge_json_file() {
    local dest="$1"
    local source="$2"

    if ! command -v python3 >/dev/null 2>&1; then
        echo "error: python3 não encontrado (necessário para merge de JSON)" >&2
        return 1
    fi

    mkdir -p "$(dirname "$dest")"
    python3 - "$dest" "$source" <<'PY'
import json, re, sys
from pathlib import Path

dest_path = Path(sys.argv[1])
source_path = Path(sys.argv[2])

def load_jsonc(path: Path):
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//.*?$", "", text, flags=re.M)
    text = re.sub(r",\s*([}\]])", r"\1", text)
    return json.loads(text)

source = load_jsonc(source_path)
if not isinstance(source, dict):
    raise SystemExit(f"error: JSON de origem não é um objeto: {source_path}")

if dest_path.is_file():
    dest = load_jsonc(dest_path)
    if not isinstance(dest, dict):
        raise SystemExit(f"error: JSON de destino não é um objeto: {dest_path}")
else:
    dest = {}

merged = {**dest, **source}
dest_path.write_text(
    json.dumps(merged, indent="\t", ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY
}
