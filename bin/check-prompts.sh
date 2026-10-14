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
    if [ -d "$dir" ] && rg -n 'files/|/docs' "$dir" >/dev/null; then
        echo "error: prompt em $dir contém caminho aposentado (files/ ou /docs)" >&2
        rg -n 'files/|/docs' "$dir" >&2 || true
        exit 1
    fi
    # API field name funnel_step_id is fine with a variable; hard-coded numeric ids are not.
    if [ -d "$dir" ] && rg -n 'funnel_step_id["[:space:]]*[:=]["[:space:]]*[0-9]' "$dir" >/dev/null; then
        echo "error: prompt em $dir hard-coda funnel_step_id numérico — use o id vivo do MCP" >&2
        rg -n 'funnel_step_id["[:space:]]*[:=]["[:space:]]*[0-9]' "$dir" >&2 || true
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

# Prompt health: paste-ready prompts are copied alone — the stop-on-stall line
# must live in each file, not only in workflow-policy.md.
if ! rg -F 'Tooling failures and stalls' "$OLIE_DIR/workflow-policy.md" >/dev/null; then
    echo "error: workflow-policy.md precisa da seção Tooling failures and stalls" >&2
    exit 1
fi
paste_ready=(
    "${required_card_prompts[@]}"
    validation.md
    implementation-validation.md
    workflow.md
    project.md
)
if [ ! -f "$OLIE_DIR/implementation-validation.md" ]; then
    echo "error: falta implementation-validation.md (validação só de código antes do pre-qa)" >&2
    exit 1
fi
if ! rg -F 'implementation-validation.md' "$OLIE_DIR/pre-qa.md" >/dev/null ||
    ! rg -F 'implementation-validation.md' "$OLIE_DIR/workflow.md" >/dev/null; then
    echo "error: pre-qa.md e workflow.md devem referenciar implementation-validation.md" >&2
    exit 1
fi
for prompt in "${paste_ready[@]}"; do
    if ! rg -F 'this prompt needs updating' "$OLIE_DIR/$prompt" >/dev/null; then
        echo "error: $prompt (colar sozinho) precisa da linha 'this prompt needs updating'" >&2
        exit 1
    fi
done
# Cross-refs to other prompts are allowed when resolvable (absolute under ~/git/…).
# Bare `foo.md` after paste is ambiguous — require ~/git/… path.
if rg -n '`[a-z0-9-]+\.md`' "$OLIE_DIR" --glob '!README.md' --glob '!workflow-policy.md' |
    rg -v '`~/git/' |
    rg -v '^\S+:[0-9]+:.*(pt-br|en)\.json' >/dev/null; then
    echo "error: prompt Olie referencia *.md sem path absoluto sob ~/git/:" >&2
    rg -n '`[a-z0-9-]+\.md`' "$OLIE_DIR" --glob '!README.md' --glob '!workflow-policy.md' |
        rg -v '`~/git/' >&2 || true
    exit 1
fi
# Maintainer-only notes (how to edit the prompt set), not agent instructions.
if rg -n 'Do not repeat `' "$OLIE_DIR" --glob '!README.md' >/dev/null; then
    echo "error: nota de manutenção 'Do not repeat' em prompt paste-ready" >&2
    rg -n 'Do not repeat `' "$OLIE_DIR" --glob '!README.md' >&2 || true
    exit 1
fi
for f in "$VID2_DIR"/guest-api-ready-for-olie.md "$VID2_DIR"/host-ollama-ready.md; do
    if [ -f "$f" ] && ! rg -i 'prompt.*(atualizado|melhorar)|prompt needs' "$f" >/dev/null; then
        echo "error: $(basename "$f") deve avisar para parar e melhorar o prompt se tooling falhar" >&2
        exit 1
    fi
done

echo "prompt check ok (${#required_card_prompts[@]} card prompts)"
