#!/usr/bin/env bash
# Apply versioned files from configs/<name>/ into project paths listed in config.json.
# Expects REPO_ROOT to be set (or defaults to parent of this file's ../../).
#
# .json files are merged top-level key by key into the destination:
# existing keys are overwritten, missing keys are added; other dest keys stay.
# Non-JSON files are copied as usual.

# Merge top-level keys from $2 (source) into $1 (dest). Creates dest if missing.
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

# chave existe → sobrescreve; senão → adiciona (demais chaves do destino permanecem)
merged = {**dest, **source}
dest_path.write_text(
    json.dumps(merged, indent="\t", ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY
}

# Copy one file from configs/<name>/ into a project tree, merging JSON when needed.
workvm_apply_file() {
    local source_file="$1"
    local dest_file="$2"

    mkdir -p "$(dirname "$dest_file")"

    case "$source_file" in
        *.json)
            echo "    merge JSON: $dest_file"
            workvm_merge_json_file "$dest_file" "$source_file"
            ;;
        *)
            echo "    copy: $dest_file"
            cp -a "$source_file" "$dest_file"
            ;;
    esac
}

workvm_apply_config() {
    local config_name="$1"
    local repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    local config_file="${repo_root}/config.json"
    local configs_dir="${repo_root}/configs"
    local source_dir="${configs_dir}/${config_name}"
    local target source_file rel dest_file

    if ! command -v jq >/dev/null 2>&1; then
        echo "error: jq não encontrado. Instale com: sudo pacman -S jq" >&2
        return 1
    fi

    if [ ! -f "$config_file" ]; then
        echo "error: config.json não encontrado em $config_file" >&2
        return 1
    fi

    if [ ! -d "$source_dir" ]; then
        echo "error: configuração '$config_name' não encontrada em $source_dir" >&2
        return 1
    fi

    if ! jq -e --arg k "$config_name" 'has($k)' "$config_file" >/dev/null; then
        echo "error: chave '$config_name' ausente em config.json" >&2
        return 1
    fi

    echo "Aplicando configuração: $config_name"

    while IFS= read -r target; do
        [ -n "$target" ] || continue
        # Paths in config.json are relative to GIT_ROOT (~/git = REPO_ROOT)
        local dest="${repo_root}/${target}"
        echo " → $dest"
        mkdir -p "$dest"

        while IFS= read -r -d '' source_file; do
            rel="${source_file#"${source_dir}/"}"
            dest_file="${dest}/${rel}"
            workvm_apply_file "$source_file" "$dest_file"
        done < <(find "$source_dir" -type f -print0)
    done < <(jq -r --arg k "$config_name" '.[$k][]' "$config_file")
}

# Apply a list of config names (arguments).
workvm_apply_configs() {
    local name
    for name in "$@"; do
        workvm_apply_config "$name"
    done
}

# Apply named configs, or every key in config.json when none are given.
workvm_apply_configs_cli() {
    local repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    local configs=()

    if [ "$#" -gt 0 ]; then
        workvm_apply_configs "$@"
        return
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo "error: jq não encontrado. Instale com: sudo pacman -S jq" >&2
        return 1
    fi

    mapfile -t configs < <(jq -r 'keys[]' "${repo_root}/config.json")
    workvm_apply_configs "${configs[@]}"
}
