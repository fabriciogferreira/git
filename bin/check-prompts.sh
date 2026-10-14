#!/usr/bin/env bash
# Valida contratos mecânicos dos prompts versionados.
# Evita placeholder vazio, caminho aposentado ou referência de ciclo de vida
# divergente; não consulta MCP nem altera card, repositório ou ambiente.
set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$BIN_DIR/.." && pwd)"
# Project prompts live next to the product tree (olie/, vid2agent-code/, …).
OLIE_DIR="$REPO_ROOT/olie/prompts"
VID2_DIR="$REPO_ROOT/vid2agent-code/prompts"

required_card_prompts=(
    implementation.md
    correction.md
    recommendation.md
    pre-qa.md
    colleague-review.md
    production-review.md
)

for prompt in "${required_card_prompts[@]}"; do
    if ! rg -F '{{ code }}' "$OLIE_DIR/$prompt" >/dev/null; then
        echo "error: $prompt não tem o placeholder {{ code }}" >&2
        exit 1
    fi
done

if rg -n -P '\{\{(?! code \}\})' "$OLIE_DIR" >/dev/null; then
    echo "error: placeholder Olie fora do formato {{ code }}" >&2
    exit 1
fi

for dir in "$OLIE_DIR" "$VID2_DIR"; do
    if [ -d "$dir" ] && rg -n 'files/|funnel_step_id|/docs' "$dir" >/dev/null; then
        echo "error: prompt em $dir contém caminho ou ID de ciclo de vida aposentado" >&2
        exit 1
    fi
done

for prompt in workflow.md correction.md; do
    if ! rg -F 'workflow-policy.md' "$OLIE_DIR/$prompt" >/dev/null; then
        echo "error: $prompt deve usar workflow-policy.md" >&2
        exit 1
    fi

    if ! rg -F 'changes-requested' "$OLIE_DIR/$prompt" >/dev/null ||
        ! rg -F 'in-progress' "$OLIE_DIR/$prompt" >/dev/null; then
        echo "error: $prompt deve usar os estágios lógicos compartilhados" >&2
        exit 1
    fi
done

echo "prompt check ok (${#required_card_prompts[@]} card prompts)"
