#!/usr/bin/env bash
# Wayland, Docker, sshd da VM (o chat do card entra por SSH) e abertura do
# Cursor e do Brave na instalação do projeto.
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

# api.olie.ai publishes OAuth discovery, so Cursor drops the Bearer header and
# the prompt agent sees needsAuth. The proxy on 127.0.0.1:47331 answers 404
# there and adds the token. Only MCP=olie keeps the unit.
#
# Já em :47331 (processo manual / unit antiga) → sucesso sem restart.
# systemd start-limit / Address already in use não pode derrubar o ensure.
workvm_olie_mcp_proxy_listening() {
    (echo >/dev/tcp/127.0.0.1/47331) >/dev/null 2>&1
}

workvm_sync_olie_mcp_proxy() {
    local repo_root="${1:-}"
    local systemd_user="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    local unit_dst="$systemd_user/workvm-olie-mcp-proxy.service"
    local unit_src="$repo_root/systemd/workvm-olie-mcp-proxy.service"
    local attempt

    if [ -n "${WORKVM_PROJECT_STUBS:-}" ]; then
        return 0
    fi

    if [ "${MCP:-}" != "olie" ]; then
        if [ -e "$unit_dst" ]; then
            systemctl --user disable --now workvm-olie-mcp-proxy.service >/dev/null 2>&1 || true
            rm -f "$unit_dst"
            systemctl --user daemon-reload >/dev/null 2>&1 || true
        fi
        return 0
    fi

    if [ ! -f "$unit_src" ]; then
        echo "workvm: proxy Olie MCP ausente: $unit_src" >&2
        return 1
    fi

    mkdir -p "$systemd_user"
    ln -sfn "$unit_src" "$unit_dst"
    systemctl --user daemon-reload >/dev/null 2>&1 || true

    if workvm_olie_mcp_proxy_listening; then
        systemctl --user enable workvm-olie-mcp-proxy.service >/dev/null 2>&1 || true
        return 0
    fi

    systemctl --user reset-failed workvm-olie-mcp-proxy.service >/dev/null 2>&1 || true
    if ! systemctl --user enable --now workvm-olie-mcp-proxy.service >/dev/null 2>&1; then
        systemctl --user reset-failed workvm-olie-mcp-proxy.service >/dev/null 2>&1 || true
        systemctl --user start workvm-olie-mcp-proxy.service >/dev/null 2>&1 || true
    fi

    attempt=0
    while [ "$attempt" -lt 15 ]; do
        if workvm_olie_mcp_proxy_listening; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.2
    done

    # Fallback: unit preso em start-limit; sobe o script direto.
    echo "workvm: unit proxy falhou — fallback nohup workvm-olie-mcp-proxy.py" >&2
    nohup "$repo_root/bin/workvm-olie-mcp-proxy.py" \
        >/tmp/workvm-olie-mcp-proxy.log 2>&1 &
    attempt=0
    while [ "$attempt" -lt 15 ]; do
        if workvm_olie_mcp_proxy_listening; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.2
    done

    echo "workvm: proxy Olie MCP não abriu 127.0.0.1:47331" >&2
    return 1
}

# True se já existe janela Cursor para este .code-workspace (Hyprland title).
workvm_cursor_workspace_open() {
    local workspace="${1:-}"
    local needle
    [ -n "$workspace" ] || return 1
    needle="$(basename "$workspace")"
    needle="${needle%.code-workspace}"
    [ -n "$needle" ] || return 1
    command -v hyprctl >/dev/null 2>&1 || return 1
    workvm_ensure_session_env
    # Env no python (não no hyprctl): pipe não herda o prefixo do lado esquerdo.
    hyprctl clients -j 2>/dev/null | WORKVM_HC_NEEDLE="$needle" python3 -c '
import json, os, sys
needle = os.environ["WORKVM_HC_NEEDLE"]
markers = (f"{needle} (Workspace)", f"{needle}.code-workspace")
try:
    clients = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for c in clients:
    title = c.get("title") or ""
    cls = (c.get("class") or "").lower()
    if "cursor" not in cls and "cursor" not in title.lower():
        continue
    if any(m in title for m in markers):
        sys.exit(0)
sys.exit(1)
'
}

workvm_open_cursor() {
    local workspace="$1"
    shift || true
    local extra_args=("$@")
    local pid
    local new_window=0
    local arg

    for arg in "${extra_args[@]+"${extra_args[@]}"}"; do
        case "$arg" in
            -n|--new-window) new_window=1 ;;
        esac
    done

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

    # Já aberto: não reabra (ensure do pest-parallel etc. resetava a janela).
    # Ainda assim **foca** a janela — open/ensure no chat do meta-repo deixava
    # o usuário olhando `~/git` enquanto o card já existia em background.
    if workvm_cursor_workspace_open "$workspace"; then
        workvm_focus_cursor_workspace "$workspace" || true
        echo "workvm: Cursor já aberto para $(basename "$workspace") — focus" >&2
        return 0
    fi
    if [ "$new_window" -eq 0 ] && pgrep -f "cursor\\.mjs ${workspace}" >/dev/null 2>&1; then
        workvm_focus_cursor_workspace "$workspace" || true
        echo "workvm: Cursor already open for $workspace — focus" >&2
        return 0
    fi

    workvm_ensure_session_env
    workvm_load_environment_d

    # systemd has no graphical env; force Wayland so Electron ignores a wrong DISPLAY.
    export ELECTRON_OZONE_PLATFORM_HINT="${ELECTRON_OZONE_PLATFORM_HINT:-wayland}"

    setsid cursor "${extra_args[@]+"${extra_args[@]}"}" "$workspace" </dev/null >/tmp/workvm-cursor.log 2>&1 &
    pid=$!
    echo "$pid" >/tmp/workvm-cursor.pid
    echo "workvm: Cursor pid $pid → $workspace ${extra_args[*]+(${extra_args[*]})} (log /tmp/workvm-cursor.log)" >&2
}

# Traz a janela Cursor deste .code-workspace para frente (Hyprland).
# Problema: ensure/open “já aberto — skip” deixava o usuário no chat do meta-repo.
workvm_focus_cursor_workspace() {
    local workspace="${1:-}"
    local needle addr selector

    [ -n "$workspace" ] || return 1
    needle="$(basename "$workspace")"
    needle="${needle%.code-workspace}"
    [ -n "$needle" ] || return 1
    command -v hyprctl >/dev/null 2>&1 || return 1

    workvm_ensure_session_env
    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "${XDG_RUNTIME_DIR:-}/hypr" ]; then
        HYPRLAND_INSTANCE_SIGNATURE="$(find "${XDG_RUNTIME_DIR}/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | head -n1 || true)"
        export HYPRLAND_INSTANCE_SIGNATURE
    fi

    addr="$(
        hyprctl clients -j 2>/dev/null | WORKVM_HC_NEEDLE="$needle" python3 -c '
import json, os, sys
needle = os.environ["WORKVM_HC_NEEDLE"]
markers = (f"{needle} (Workspace)", f"{needle}.code-workspace")
try:
    clients = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for c in clients:
    title = c.get("title") or ""
    cls = (c.get("class") or "").lower()
    if "cursor" not in cls and "cursor" not in title.lower():
        continue
    if not any(m in title for m in markers):
        continue
    addr = c.get("address") or ""
    if addr:
        print(addr)
        break
'
    )"
    [ -n "$addr" ] || return 1
    case "$addr" in
        address:*) selector="$addr" ;;
        *) selector="address:$addr" ;;
    esac
    # Hyprland 0.56 (Lua): `dispatch focuswindow address:…` quebra como o closewindow;
    # usar hl.dsp.focus({ window = "address:…" }).
    if ! hyprctl dispatch "hl.dsp.focus({ window = \"${selector}\" })" >/dev/null 2>&1; then
        return 1
    fi
    echo "workvm: foquei Cursor ($needle) ${selector}" >&2
}

# Fecha só a janela Cursor do host-card (Hyprland), não o processo nem outras apps.
# Problema: finish/destroy limpava o stack e a janela do card ficava aberta.
# Hyprland 0.56 (Lua): `dispatch closewindow address:…` quebra; sem `window=`
# o `hl.dsp.window.close()` fecha a janela ativa (ou pior). Sempre passar address.
# Título típico: "… - olie-dop-1285 (Workspace) - … Cursor"
workvm_close_cursor_workspace() {
    local workspace="${1:-}"
    local needle closed addr selector

    if [ -z "$workspace" ]; then
        return 0
    fi
    needle="$(basename "$workspace")"
    needle="${needle%.code-workspace}"
    if [ -z "$needle" ]; then
        return 0
    fi

    if ! command -v hyprctl >/dev/null 2>&1; then
        echo "workvm: hyprctl ausente — não fechei a janela Cursor ($needle)" >&2
        return 0
    fi

    workvm_ensure_session_env
    # hyprctl precisa da instance da sessão gráfica (agent/SSH costuma não ter).
    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "${XDG_RUNTIME_DIR:-}/hypr" ]; then
        HYPRLAND_INSTANCE_SIGNATURE="$(find "${XDG_RUNTIME_DIR}/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | head -n1 || true)"
        export HYPRLAND_INSTANCE_SIGNATURE
    fi

    closed="$(
        hyprctl clients -j 2>/dev/null | WORKVM_HC_NEEDLE="$needle" python3 -c '
import json, os, sys
needle = os.environ["WORKVM_HC_NEEDLE"]
# Prefer "id (Workspace)" so we do not close a random title that mentions the id.
markers = (f"{needle} (Workspace)", f"{needle}.code-workspace")
try:
    clients = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for c in clients:
    title = c.get("title") or ""
    cls = (c.get("class") or "").lower()
    if "cursor" not in cls and "cursor" not in title.lower():
        continue
    if not any(m in title for m in markers):
        continue
    addr = c.get("address") or ""
    if addr:
        print(addr)
'
    )"

    if [ -z "$closed" ]; then
        echo "workvm: nenhuma janela Cursor para $needle" >&2
        return 0
    fi

    while IFS= read -r addr; do
        [ -n "$addr" ] || continue
        # Nunca chamar hl.dsp.window.close() sem window — fecha a ativa.
        case "$addr" in
            address:*) selector="$addr" ;;
            *) selector="address:$addr" ;;
        esac
        if hyprctl dispatch "hl.dsp.window.close({ window = \"${selector}\" })" >/dev/null 2>&1; then
            echo "workvm: fechei Cursor ($needle) ${selector}" >&2
        else
            echo "workvm: falha ao fechar Cursor ${selector}" >&2
        fi
    done <<<"$closed"
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

# Arch installs openssh with sshd disabled. The card chat SSHs to the guest;
# with the unit down, port 22 answers connection refused.
workvm_enable_sshd() {
    if [ ! -f /usr/lib/systemd/system/sshd.service ]; then
        return 0
    fi

    sudo systemctl enable --now sshd.service || return 0
}

# The site holds the private key. Guests only need this public key.
workvm_authorize_workvm_ssh() {
    local pub="$1"
    local keys line

    if [ ! -f "$pub" ]; then
        return 0
    fi

    keys="${HOME}/.ssh/authorized_keys"
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
    touch "$keys"
    chmod 600 "$keys"
    line=$(tr -d '\n' < "$pub")

    if [ -z "$line" ]; then
        return 0
    fi

    if ! grep -qxF "$line" "$keys"; then
        printf '%s\n' "$line" >> "$keys"
    fi
}
