#!/usr/bin/env bash
# Shared helpers for workvm project startups.

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

    setsid cursor "$workspace" </dev/null >/tmp/workvm-cursor.log 2>&1 &
}

workvm_open_chromium() {
    if [ "$#" -eq 0 ]; then
        return 0
    fi

    if ! command -v chromium >/dev/null 2>&1; then
        echo "workvm: chromium not found in PATH" >&2
        return 1
    fi

    setsid chromium --new-window "$@" </dev/null >/tmp/workvm-chromium.log 2>&1 &
}

workvm_docker_compose_up() {
    local compose_dir="$1"

    if [ ! -d "$compose_dir" ]; then
        echo "workvm: compose dir not found: $compose_dir" >&2
        return 1
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
