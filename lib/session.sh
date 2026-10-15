#!/usr/bin/env bash
# Wayland, Docker, browser e abertura do Cursor no login gráfico.
# Problema: a espera da sessão estava no mesmo arquivo que clone e patch.
# Carregado por common.sh. Não dê source neste arquivo sozinho.

workvm_ensure_session_env() {
    if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
        local runtime_uid
        runtime_uid="$(id -u)"
        export XDG_RUNTIME_DIR="/run/user/${runtime_uid}"
    fi

    if [ -z "${WAYLAND_DISPLAY:-}" ]; then
        if [ -S "${XDG_RUNTIME_DIR}/wayland-1" ]; then
            export WAYLAND_DISPLAY=wayland-1
        elif [ -S "${XDG_RUNTIME_DIR}/wayland-0" ]; then
            export WAYLAND_DISPLAY=wayland-0
        fi
    fi

    # systemd user units often lack DISPLAY. Hardcoding :0 is wrong on this
    # stack (Hyprland/Xwayland is usually :1; :0 may be SDDM). Prefer an
    # existing X11 socket; leave unset if none — Electron goes Wayland-only.
    if [ -z "${DISPLAY:-}" ]; then
        if [ -S /tmp/.X11-unix/X1 ]; then
            export DISPLAY=:1
        elif [ -S /tmp/.X11-unix/X0 ]; then
            export DISPLAY=:0
        fi
    fi

    if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "${XDG_RUNTIME_DIR}/bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
    fi
}

# Wait until Wayland is usable for GUI apps. Timeout in seconds (default 90).
# Socket alone is not enough: default.target can see the socket before Hyprland
# accepts clients; Cursor/Brave then exit with an empty log.
workvm_wait_for_wayland() {
    local timeout="${1:-90}"
    local elapsed=0
    local have_hyprctl=0

    command -v hyprctl >/dev/null 2>&1 && have_hyprctl=1

    workvm_ensure_session_env

    while [ "$elapsed" -lt "$timeout" ]; do
        workvm_ensure_session_env

        if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]; then
            if [ "$have_hyprctl" -eq 1 ]; then
                if hyprctl monitors -j >/dev/null 2>&1; then
                    return 0
                fi
            else
                return 0
            fi
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

# Ensure ~/.config/environment.d is a directory of *.conf files.
# A common footgun is writing KEY=VAL directly to that path as a file; migrate
# those contents to local.conf so Hyprland/Cursor loaders keep working.
workvm_ensure_environment_d() {
    local dir="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d"
    local parent tmp dest

    parent="$(dirname "$dir")"
    mkdir -p "$parent"

    if [ -L "$dir" ]; then
        if [ -d "$dir" ]; then
            return 0
        fi
        echo "workvm: $dir is a symlink to a non-directory; fix manually" >&2
        return 1
    fi

    if [ -f "$dir" ]; then
        tmp="$(mktemp "${TMPDIR:-/tmp}/workvm-environment.d.XXXXXX")"
        cp -a "$dir" "$tmp"
        rm -f "$dir"
        mkdir -p "$dir"
        dest="$dir/local.conf"
        if [ -e "$dest" ]; then
            dest="$dir/migrated-$(date +%Y%m%d%H%M%S).conf"
        fi
        mv "$tmp" "$dest"
        chmod 600 "$dest" 2>/dev/null || true
        echo "workvm: migrated file $dir → $dest" >&2
        return 0
    fi

    mkdir -p "$dir"
}

# Load ~/.config/environment.d/*.conf into the current shell.
# Hyprland/Electron do not inherit systemd user manager env from environment.d;
# Cursor needs those vars for ${env:NAME} interpolation in mcp.json headers.
workvm_load_environment_d() {
    local dir="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d"
    local f line key val

    workvm_ensure_environment_d || return 0
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
    local pid

    if [ ! -f "$workspace" ]; then
        echo "workvm: workspace not found: $workspace" >&2
        return 1
    fi

    # Paths relativos do .code-workspace são resolvidos a partir do diretório
    # do arquivo como o Cursor o recebeu. Se passar o symlink
    # ~/.config/workvm/current/..., ../../olie vira ~/.config/olie.
    workspace="$(realpath "$workspace")"

    if ! command -v cursor >/dev/null 2>&1; then
        echo "workvm: cursor not found in PATH" >&2
        return 1
    fi

    # Hyprland restarts workvm after compositor is up; skip duplicate window.
    if pgrep -f "cursor\\.mjs ${workspace}" >/dev/null 2>&1; then
        echo "workvm: Cursor already open for $workspace" >&2
        return 0
    fi

    workvm_ensure_session_env
    workvm_load_environment_d

    # systemd has no graphical env; force Wayland so Electron ignores a wrong DISPLAY.
    export ELECTRON_OZONE_PLATFORM_HINT="${ELECTRON_OZONE_PLATFORM_HINT:-wayland}"

    setsid cursor "$workspace" </dev/null >/tmp/workvm-cursor.log 2>&1 &
    pid=$!
    echo "$pid" >/tmp/workvm-cursor.pid
    echo "workvm: Cursor pid $pid → $workspace (log /tmp/workvm-cursor.log)" >&2
}

workvm_open_chromium() {
    if [ "$#" -eq 0 ]; then
        return 0
    fi

    local browser="" pid
    local pidfile=/tmp/workvm-browser.pid
    if command -v brave >/dev/null 2>&1; then
        browser=brave
    elif command -v brave-browser >/dev/null 2>&1; then
        browser=brave-browser
    else
        echo "workvm: brave not found in PATH (installe via vm-setup / brave-bin)" >&2
        return 1
    fi

    # Same restart path as Cursor — one window is enough.
    if [ -f "$pidfile" ]; then
        pid="$(cat "$pidfile" 2>/dev/null || true)"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "workvm: browser already open (pid $pid); skipping" >&2
            return 0
        fi
    fi

    workvm_ensure_session_env

    setsid "$browser" --new-window "$@" </dev/null >/tmp/workvm-browser.log 2>&1 &
    pid=$!
    echo "$pid" >"$pidfile"
    echo "workvm: browser pid $pid (log /tmp/workvm-browser.log)" >&2
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
