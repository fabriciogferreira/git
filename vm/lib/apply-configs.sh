#!/usr/bin/env bash
# Apply versioned files from configs/<name>/ into project paths listed in config.json.
# Expects REPO_ROOT to be set (or defaults to parent of this file's ../../).

workvm_apply_config() {
    local config_name="$1"
    local repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    local config_file="${repo_root}/config.json"
    local configs_dir="${repo_root}/configs"
    local source_dir="${configs_dir}/${config_name}"
    local target

    if ! command -v jq >/dev/null 2>&1; then
        echo "error: jq não encontrado. Instale com: sudo pacman -S jq" >&2
        return 1
    fi

    if ! command -v rsync >/dev/null 2>&1; then
        echo "error: rsync não encontrado. Instale com: sudo pacman -S rsync" >&2
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
        # Paths in config.json are relative to GIT_ROOT (~/git)
        local dest="${repo_root}/${target}"
        echo " → $dest"
        mkdir -p "$dest"
        rsync -a "${source_dir}/" "${dest}/"
    done < <(jq -r --arg k "$config_name" '.[$k][]' "$config_file")
}

# Apply a list of config names (arguments).
workvm_apply_configs() {
    local name
    for name in "$@"; do
        workvm_apply_config "$name"
    done
}
