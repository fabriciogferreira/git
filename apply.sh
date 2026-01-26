#!/usr/bin/env bash
set -e

CONFIG_FILE="config.json"
CONFIGS_DIR="configs"

if ! command -v jq &> /dev/null; then
  echo "Erro: jq não encontrado. Instale com: sudo apt install jq -y"
  exit 1
fi

apply_config() {
  local config_name=$1
  local source_dir="$CONFIGS_DIR/$config_name"

  if [ ! -d "$source_dir" ]; then
    echo "Configuração '$config_name' não encontrada em $source_dir"
    return 1
  fi

  echo "Aplicando configuração: $config_name"

  # Lê os caminhos do array dessa config
  jq -r ".\"$config_name\"[]" "$CONFIG_FILE" | while read -r target; do
    echo " → Copiando para $target"
    mkdir -p "$target"
    rsync -a "$source_dir"/ "$target"/
  done
}

if [ $# -gt 0 ]; then
  # Aplica só as configs passadas como argumento
  for config in "$@"; do
    apply_config "$config"
  done
else
  # Aplica todas as configs do JSON
  configs=$(jq -r 'keys[]' "$CONFIG_FILE")
  for config in $configs; do
    apply_config "$config"
  done
fi
