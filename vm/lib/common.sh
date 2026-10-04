#!/usr/bin/env bash
# Shared helpers for workvm project startups.

workvm_clone_repo() {
    local repo="$1"
    local destination="$2"

    mkdir -p "$(dirname "$destination")"

    if [ -d "$destination/.git" ]; then
        echo "✓ Já existe: $destination"
        return 0
    fi

    echo "→ Clonando: $repo → $destination"
    git clone "$repo" "$destination"
}

# Entries: "<git-url> <path>". Relative paths are under GIT_ROOT (default $HOME/git).
workvm_clone_project_repos() {
    local git_root="${GIT_ROOT:-$HOME/git}"
    local entry repo dest

    mkdir -p "$git_root"

    for entry in "$@"; do
        repo="${entry%% *}"
        dest="${entry#* }"
        if [ -z "$dest" ] || [ "$repo" = "$dest" ]; then
            echo "error: CLONE_REPOS entry inválida: $entry" >&2
            return 1
        fi
        case "$dest" in
            /*) ;;
            *) dest="${git_root}/${dest}" ;;
        esac
        workvm_clone_repo "$repo" "$dest"
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

    if [ ! -f "$compose_dir/docker-compose.yml" ] && [ ! -f "$compose_dir/compose.yml" ]; then
        echo "workvm: no compose file in $compose_dir" >&2
        return 1
    fi

    (cd "$compose_dir" && docker compose up -d)
}
