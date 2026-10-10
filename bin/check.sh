#!/usr/bin/env bash
# Checagem dos scripts versionados.
# Problema: ninguém rodava shellcheck. set -u estoura num array que o
# project.conf não declara, e o log do compose omitia COMPOSE_FILE
# mesmo quando o conf definia.
# Não sobe Docker, Cursor nem browser: o trecho de project-start usa stubs.
set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$BIN_DIR/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "error: shellcheck ausente. sudo pacman -S shellcheck" >&2
    exit 1
fi

mapfile -t scripts < <(
    {
        git ls-files '*.sh'
        git ls-files --others --exclude-standard '*.sh'
    } | sort -u
)

# Pelo caminho de um symlink o shellcheck procura o source ao lado do link.
# O alvo real já entra na lista.
checked=()
for script in "${scripts[@]}"; do
    [ -L "$script" ] && continue
    [ -f "$script" ] || continue
    checked+=("$script")
done

if [ "${#checked[@]}" -eq 0 ]; then
    echo "error: nenhum script para checar" >&2
    exit 1
fi

shellcheck "${checked[@]}"

# $1 e $2 são do bash de dentro. Aspas simples para o de fora não expandir.
# shellcheck disable=SC2016
run_project_start() {
    local dir="$1"
    local stubs="$2"
    WORKVM_PROJECT_STUBS="$stubs" bash -euo pipefail -c \
        'source "$1"; workvm_project_start "$2"' \
        bash "$REPO_ROOT/lib/project-start.sh" "$dir"
}

# project.conf mínimo, sem os arrays e sem COMPOSE_FILE.
# workvm_project_start precisa inicializar os arrays antes do source.
check_unset_arrays() {
    local tmp="$1"
    local dir="$tmp/bare"

    mkdir -p "$dir"
    cat >"$dir/project.conf" <<'EOF'
PROJECT_NAME=check
EOF

    run_project_start "$dir" "$tmp/stubs.sh" >/dev/null
}

# O log tem de mostrar o -f que o project.conf definiu.
check_compose_file_log() {
    local tmp="$1"
    local dir="$tmp/with-file"
    local log

    mkdir -p "$dir"
    cat >"$dir/project.conf" <<EOF
PROJECT_NAME=check
COMPOSE_DIR="$dir"
COMPOSE_FILE=compose.dev.yaml
EOF

    log="$(run_project_start "$dir" "$tmp/stubs.sh")"

    case "$log" in
        *"-f compose.dev.yaml"*) ;;
        *)
            echo "error: log do compose não citou COMPOSE_FILE" >&2
            printf '%s\n' "$log" >&2
            exit 1
            ;;
    esac
}

# O compose de e2e não pode herdar o COMPOSE_FILE do app.
check_e2e_drops_compose_file() {
    local tmp="$1"
    local dir="$tmp/e2e-app"
    local e2e="$tmp/e2e"
    local log

    mkdir -p "$dir" "$e2e"
    cat >"$dir/project.conf" <<EOF
PROJECT_NAME=check
COMPOSE_FILE=compose.dev.yaml
E2E_COMPOSE_DIRS=("$e2e")
EOF

    log="$(run_project_start "$dir" "$tmp/stubs.sh")"

    case "$log" in
        *compose-file-unset*) ;;
        *)
            echo "error: e2e herdou COMPOSE_FILE do app" >&2
            printf '%s\n' "$log" >&2
            exit 1
            ;;
    esac
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/stubs.sh" <<'EOF'
workvm_fetch_project_repos() { :; }
workvm_apply_files() { :; }
# Não escrever ~/.cursor/mcp.json durante o teste.
workvm_apply_mcp() { :; }
workvm_wait_for_wayland() { return 0; }
workvm_docker_compose_up() {
    if [ -n "${COMPOSE_FILE+x}" ]; then
        printf 'compose-file=%s\n' "$COMPOSE_FILE"
    else
        printf 'compose-file-unset\n'
    fi
}
workvm_open_cursor() { :; }
workvm_open_chromium() { :; }
workvm_wait_for_http() { return 0; }
EOF

check_unset_arrays "$tmp"
check_compose_file_log "$tmp"
check_e2e_drops_compose_file "$tmp"
"$BIN_DIR/check-prompts.sh"

echo "check ok (${#checked[@]} scripts)"
