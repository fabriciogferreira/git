#!/usr/bin/env bash
# O plano do Cursor acaba e o chat deixa de chamar modelo e MCP.
# Rode na WorkVM ou no host. Instala o OpenCode 2, espelha rules/skills/agents
# do meta-repo ($GIT_ROOT/.cursor, default ~/git) e overlay de ~/.cursor em
# ~/.config/opencode — o Cursor carrega as alwaysApply do workspace ~/git;
# só ~/.cursor deixava o OpenCode sem host-card-open e afins. Aponta o modelo
# para o Ollama em :11435 nas duas RTX 3060 (01:00.0 + 08:00.0) por default,
# traduz MCP de ~/.cursor/mcp.json e injeta o MCP GitHub remoto. O PAT vai em
# ~/.config/opencode/github-pat (chmod 600) com {file:github-pat} — {env:}
# vira Bearer vazio se o OpenCode não herdar o export (HTTP 400).
# No host sobe um ollama serve dedicado (CUDA_DEVICE_ORDER=PCI_BUS_ID,
# multi-GPU, SCHED_SPREAD) reusando OLLAMA_MODELS do sistema (/var/lib/ollama)
# quando legível — os pulls do :11434 ficam visíveis no :11435.
# Default do chat: qwen38-opencode (FROM qwen3.8:27b + RENDERER qwen3.5) —
# o renderer nativo qwen3.8 devolve 500 "no user query found in messages"
# no tool-loop do OpenCode quando o truncate/ctx corta o turn user
# (ollama#17778 / #18107). Na guest só aponta para 10.0.2.2:11435.
# Não mexe no Cursor nem no Ollama do vid2agent (:11434) além do create
# do alias (precisa escrever em /var/lib/ollama).
# Uso: bin/workvm-opencode.sh
set -euo pipefail

# RTX 3060 no PCI_E1 (PCIe 5.0 x16). Com PCI_BUS_ID, índice 0 = 01:00.0.
rtx3060_pci="${WORKVM_OPENCODE_GPU_PCI:-0000:01:00.0}"
# PCI_BUS_ID no jarvis atual: 0=3060@01:00 (PCIe 5.0), 1=3060@08:00.
# 27B Q4 (~17 GiB) divide nas duas 3060 (12+12); uma sozinha fica apertada.
# Override: WORKVM_OPENCODE_CUDA_VISIBLE_DEVICES (ex. 0,2 se a 5060 voltar).
cuda_visible="${WORKVM_OPENCODE_CUDA_VISIBLE_DEVICES:-0,1}"
ollama_port="${WORKVM_OPENCODE_OLLAMA_PORT:-11435}"
model="${WORKVM_OLLAMA_MODEL:-qwen38-opencode}"
system_ollama_port="${WORKVM_OPENCODE_SYSTEM_OLLAMA_PORT:-11434}"
system_models="${WORKVM_OPENCODE_OLLAMA_MODELS:-/var/lib/ollama}"
opencode_model_from="${WORKVM_OPENCODE_MODEL_FROM:-qwen3.8:27b}"
if [ -n "${WORKVM_OPENCODE_OLLAMA_SCHED_SPREAD:-}" ]; then
    ollama_sched_spread="$WORKVM_OPENCODE_OLLAMA_SCHED_SPREAD"
elif [[ "$cuda_visible" == *","* ]]; then
    ollama_sched_spread=true
else
    ollama_sched_spread=false
fi

git_root="${GIT_ROOT:-$HOME/git}"
cursor_dir="${HOME}/.cursor"
cursor_mcp="${cursor_dir}/mcp.json"
meta_cursor="${git_root}/.cursor"
opencode_dir="${HOME}/.config/opencode"
dest="${opencode_dir}/opencode.json"
github_pat_file="${opencode_dir}/github-pat"
cursor_mirror="${opencode_dir}/.cursor"
skills_dest="${opencode_dir}/skills"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/workvm-opencode"
pid_file="${state_dir}/ollama-rtx3060.pid"
log_file="${state_dir}/ollama-rtx3060.log"

is_qemu_guest() {
    local vendor product

    vendor=$(tr -d '\0' </sys/class/dmi/id/sys_vendor 2>/dev/null || true)
    product=$(tr -d '\0' </sys/class/dmi/id/product_name 2>/dev/null || true)
    case "${vendor,,} ${product,,}" in
        *qemu*|*kvm*|*bochs*|*virtualbox*) return 0 ;;
    esac
    [ -d /sys/firmware/qemu_fw_cfg ]
}

if [ -n "${WORKVM_OLLAMA_BASE_URL:-}" ]; then
    base_url="$WORKVM_OLLAMA_BASE_URL"
elif is_qemu_guest; then
    base_url="http://10.0.2.2:${ollama_port}/v1"
else
    base_url="http://127.0.0.1:${ollama_port}/v1"
fi

opencode_bin() {
    if [ -x "${HOME}/.opencode/bin/opencode" ]; then
        printf '%s\n' "${HOME}/.opencode/bin/opencode"
        return 0
    fi

    command -v opencode 2>/dev/null || true
}

install_opencode() {
    local bin ver

    bin="$(opencode_bin)"
    if [ -n "$bin" ]; then
        ver="$("$bin" --version 2>/dev/null || true)"
        major=""
        if [[ "$ver" =~ ([0-9]+)\.[0-9]+ ]]; then
            major="${BASH_REMATCH[1]}"
        fi
        if [ "$major" = "2" ]; then
            printf '→ OpenCode já instalado (%s)\n' "$ver"
            return 0
        fi
        if [ "$major" = "1" ]; then
            printf '→ OpenCode 1 em %s; instalando o 2\n' "$bin"
        else
            printf '→ OpenCode em %s (versão %s); config no formato 2\n' "$bin" "${ver:-desconhecida}"
            return 0
        fi
    fi

    curl -fsSL https://opencode.ai/v2/install | bash
}

# Copia árvore src/ → dest/. delete=1 limpa dest antes (rsync --delete / rm).
_workvm_opencode_sync_tree() {
    local src=$1 dest=$2 delete=${3:-0}

    mkdir -p "$dest"
    if command -v rsync >/dev/null 2>&1; then
        if [ "$delete" = 1 ]; then
            rsync -a --delete "${src}/" "${dest}/"
        else
            rsync -a "${src}/" "${dest}/"
        fi
    else
        if [ "$delete" = 1 ]; then
            rm -rf "${dest}"
            mkdir -p "$dest"
        fi
        cp -a "${src}/." "${dest}/"
    fi
}

# Espelha o que o OpenCode consome: rules → instructions, skills → skills/,
# agents → agents/. Meta-repo primeiro ($GIT_ROOT/.cursor), depois overlay
# ~/.cursor. Não copia projects, mcp.json, caches nem permissions.
sync_cursor_into_opencode() {
    local name src synced delete

    if [ ! -d "$meta_cursor" ] && [ ! -d "$cursor_dir" ]; then
        printf '→ .cursor ausente (%s e %s); espelho pulado\n' "$meta_cursor" "$cursor_dir" >&2
        return 0
    fi

    mkdir -p "$cursor_mirror" "$opencode_dir/agents" "$skills_dest"

    for name in rules agents; do
        synced=0
        # Meta com --delete (fonte de verdade do workspace); user só overlay.
        for src in "${meta_cursor}/${name}" "${cursor_dir}/${name}"; do
            if [ ! -d "$src" ]; then
                continue
            fi
            if [ "$synced" -eq 0 ]; then
                delete=1
            else
                delete=0
            fi
            _workvm_opencode_sync_tree "$src" "${cursor_mirror}/${name}" "$delete"
            printf '→ espelho: %s → %s/%s\n' "$src" "$cursor_mirror" "$name"
            synced=1
        done
        if [ "$synced" -eq 0 ]; then
            printf '→ espelho: %s ausente em %s e %s\n' "$name" "$meta_cursor" "$cursor_dir" >&2
        fi
    done

    if [ -d "${cursor_mirror}/agents" ]; then
        _workvm_opencode_sync_tree "${cursor_mirror}/agents" "${opencode_dir}/agents" 0
    fi

    # Meta skills + user skills; Cursor user skills também em skills-cursor/.
    for src in "${meta_cursor}/skills" "${cursor_dir}/skills" "${cursor_dir}/skills-cursor"; do
        if [ -d "$src" ]; then
            _workvm_opencode_sync_tree "$src" "$skills_dest" 0
            printf '→ skills: %s → %s\n' "$src" "$skills_dest"
        fi
    done
}

# OpenCode substitui {env:VAR} ausente por "" → Authorization: "Bearer "
# e o GitHub responde 400. {file:} ao lado do opencode.json é estável.
write_github_pat() {
    local token=""

    if [ -n "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
        token=$(printf '%s' "$GITHUB_PERSONAL_ACCESS_TOKEN" | tr -d '\r\n')
    elif command -v gh >/dev/null 2>&1; then
        token=$(gh auth token 2>/dev/null | tr -d '\r\n' || true)
    fi

    if [ -z "$token" ]; then
        return 1
    fi

    mkdir -p "$(dirname "$github_pat_file")"
    umask 077
    printf '%s' "$token" >"$github_pat_file"
    chmod 600 "$github_pat_file"
}

gpu_model_at_pci() {
    local pci=$1
    local info model bus

    for info in /proc/driver/nvidia/gpus/*/information; do
        [ -f "$info" ] || continue
        # Campos separados por espaços/tabs (não CSV).
        bus=$(sed -n 's/^Bus Location:[[:space:]]*//p' "$info" | tr -d '[:space:]')
        model=$(sed -n 's/^Model:[[:space:]]*//p' "$info" | sed 's/[[:space:]]*$//')
        if [ "$bus" = "$pci" ]; then
            printf '%s\n' "$model"
            return 0
        fi
    done
    return 1
}

ollama_listening_on() {
    local port=$1
    local listeners

    listeners=$(ss -ltnH 2>/dev/null || true)
    [[ "$listeners" == *":${port}"* ]] || [[ "$listeners" == *"127.0.0.1:${port}"* ]]
}

ollama_bin() {
    local candidate

    for candidate in /usr/local/bin/ollama /usr/bin/ollama; do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    command -v ollama 2>/dev/null || true
}

# Host only: Ollama dedicado na 3060 do slot PCIe 5.0, porta 11435.
ensure_host_ollama_rtx3060() {
    local bin gpu pid

    if is_qemu_guest; then
        return 0
    fi

    bin="$(ollama_bin)"
    if [ -z "$bin" ]; then
        printf '→ Ollama ausente no host; instale e rode de novo (porta %s)\n' "$ollama_port" >&2
        return 1
    fi

    gpu=$(gpu_model_at_pci "$rtx3060_pci" || true)
    if [ -z "$gpu" ]; then
        printf '→ aviso: GPU em %s não aparece no driver NVIDIA\n' "$rtx3060_pci" >&2
    else
        printf '→ GPU %s @ %s → CUDA_VISIBLE_DEVICES=%s (PCI_BUS_ID)\n' "$gpu" "$rtx3060_pci" "$cuda_visible"
        case "$gpu" in
            *3060*) ;;
            *)
                printf '→ aviso: esperava RTX 3060 no slot PCIe 5.0; achei: %s\n' "$gpu" >&2
                ;;
        esac
    fi

    if ollama_listening_on "$ollama_port"; then
        printf '→ Ollama já escuta em :%s\n' "$ollama_port"
        return 0
    fi

    if [ -f "$pid_file" ]; then
        pid=$(tr -d ' \n' <"$pid_file" || true)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            printf '→ Ollama pid %s ainda sobe; aguardando :%s\n' "$pid" "$ollama_port"
        else
            rm -f "$pid_file"
        fi
    fi

    mkdir -p "$state_dir"
    printf '→ subindo Ollama em 127.0.0.1:%s (CUDA_VISIBLE_DEVICES=%s SCHED_SPREAD=%s)\n' \
        "$ollama_port" "$cuda_visible" "$ollama_sched_spread"
    (
        export CUDA_DEVICE_ORDER=PCI_BUS_ID
        export CUDA_VISIBLE_DEVICES="$cuda_visible"
        export OLLAMA_HOST="127.0.0.1:${ollama_port}"
        export OLLAMA_NUM_PARALLEL="${OLLAMA_NUM_PARALLEL:-1}"
        export OLLAMA_SCHED_SPREAD="$ollama_sched_spread"
        # Mesma biblioteca do serviço systemd (:11434), se legível.
        if [ -d "$system_models/manifests" ] && [ -r "$system_models/manifests" ]; then
            export OLLAMA_MODELS="$system_models"
            printf '→ OLLAMA_MODELS=%s\n' "$system_models"
        fi
        nohup "$bin" serve >>"$log_file" 2>&1 &
        echo $! >"$pid_file"
    )

    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        if ollama_listening_on "$ollama_port"; then
            printf '→ Ollama pronto em :%s (log %s)\n' "$ollama_port" "$log_file"
            return 0
        fi
        sleep 0.5
    done

    printf '→ Ollama não abriu :%s a tempo; veja %s\n' "$ollama_port" "$log_file" >&2
    return 1
}

# Alias qwen38-opencode: mesmos pesos, RENDERER qwen3.5 (tool-loop do agent).
# Create no :11434 (escreve /var/lib/ollama); o :11435 do OpenCode só lê.
ensure_qwen38_opencode_model() {
    local bin tags tmp want from

    want="${model%%:*}"
    case "$want" in
        qwen38-opencode) ;;
        *) return 0 ;;
    esac

    bin="$(ollama_bin)"
    if [ -z "$bin" ]; then
        return 1
    fi

    tags=$(curl -fsS --max-time 5 "http://127.0.0.1:${ollama_port}/api/tags" 2>/dev/null || true)
    if [[ "$tags" == *"\"qwen38-opencode"* ]]; then
        printf '→ modelo qwen38-opencode já em :%s\n' "$ollama_port"
        return 0
    fi

    from="$opencode_model_from"
    tmp=$(mktemp)
    cat >"$tmp" <<EOF
# Problema: qwen3.8 RENDERER + OpenCode tool-loop → 500 "no user query found".
# RENDERER qwen3.5 com os mesmos pesos; num_ctx maior atrasa o truncate.
FROM ${from}
RENDERER qwen3.5
PARAMETER num_ctx 8192
EOF
    printf '→ criando qwen38-opencode (FROM %s, RENDERER qwen3.5) via :%s\n' "$from" "$system_ollama_port"
    if ! OLLAMA_HOST="127.0.0.1:${system_ollama_port}" "$bin" create qwen38-opencode -f "$tmp"; then
        rm -f "$tmp"
        printf '→ falha ao criar qwen38-opencode em :%s (precisa escrever em %s)\n' \
            "$system_ollama_port" "$system_models" >&2
        return 1
    fi
    rm -f "$tmp"
    printf '→ qwen38-opencode pronto\n'
}

write_config() {
    local github_ok=0
    local instructions_glob skills_flag

    mkdir -p "$(dirname "$dest")"
    if write_github_pat; then
        github_ok=1
        printf '→ github PAT: %s (chmod 600)\n' "$github_pat_file"
    else
        printf '→ github PAT ausente; MCP github não será configurado\n' >&2
        printf '  ex.: export GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token)"\n' >&2
        printf '  ou: gh auth login\n' >&2
    fi

    instructions_glob="${cursor_mirror}/rules/**/*.mdc"
    skills_flag=0
    if [ -d "$skills_dest" ] && [ -n "$(find "$skills_dest" -mindepth 1 -maxdepth 1 2>/dev/null | head -1)" ]; then
        skills_flag=1
    fi

    python3 - "$dest" "$cursor_mcp" "$base_url" "$model" "$github_ok" "$instructions_glob" "$skills_dest" "$skills_flag" <<'PY'
import json, re, sys
from pathlib import Path

dest = Path(sys.argv[1])
cursor_mcp = Path(sys.argv[2])
base_url = sys.argv[3]
model = sys.argv[4]
github_ok = sys.argv[5] == "1"
instructions_glob = sys.argv[6]
skills_dest = Path(sys.argv[7])
wire_skills = sys.argv[8] == "1"

def load_jsonc(path: Path):
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"(?m)^\s*//.*?$", "", text)
    text = re.sub(r",\s*([}\]])", r"\1", text)
    return json.loads(text)

def conv(value):
    if not isinstance(value, str):
        return value
    return re.sub(r"\$\{env:([A-Za-z_][A-Za-z0-9_]*)\}", r"{env:\1}", value)

def translate(name, spec):
    if not isinstance(spec, dict):
        raise SystemExit(f"error: MCP {name} não é um objeto")
    url = spec.get("url")
    typ = spec.get("type") or ""
    if url or typ in ("http", "sse", "remote"):
        if not isinstance(url, str) or not url:
            raise SystemExit(f"error: MCP {name} sem url")
        out = {"type": "remote", "url": conv(url)}
        headers = spec.get("headers")
        if isinstance(headers, dict) and headers:
            out["headers"] = {key: conv(val) for key, val in headers.items()}
        if spec.get("disabled") is True:
            out["disabled"] = True
        return out
    command = spec.get("command")
    if not command:
        raise SystemExit(f"error: MCP {name} sem url nem command")
    if isinstance(command, str):
        args = spec.get("args") or []
        if not isinstance(args, list):
            raise SystemExit(f"error: MCP {name} args não é lista")
        cmd = [command, *args]
    elif isinstance(command, list):
        cmd = command
    else:
        raise SystemExit(f"error: MCP {name} command inválido")
    out = {"type": "local", "command": [conv(part) for part in cmd]}
    env = spec.get("env")
    if env is None:
        env = spec.get("environment")
    if isinstance(env, dict) and env:
        out["environment"] = {key: conv(val) for key, val in env.items()}
    if spec.get("disabled") is True:
        out["disabled"] = True
    return out

servers = {}
if cursor_mcp.is_file():
    data = load_jsonc(cursor_mcp)
    raw = data.get("mcpServers") if isinstance(data, dict) else None
    if not isinstance(raw, dict):
        raise SystemExit(f"error: {cursor_mcp} sem mcpServers")
    for name, spec in raw.items():
        servers[name] = translate(name, spec)
    print(f"→ MCP: {len(servers)} server(s) de {cursor_mcp}")
else:
    print(f"→ MCP: nenhum ({cursor_mcp} ausente)")

# Cursor expõe GitHub como plugin; não aparece em mcp.json.
# Remote oficial: https://github.com/github/github-mcp-server (install-opencode.md)
# {file:github-pat} relativo ao diretório do opencode.json (mesmo dir).
if github_ok:
    servers["github"] = {
        "type": "remote",
        "url": "https://api.githubcopilot.com/mcp/",
        "enabled": True,
        "oauth": False,
        "headers": {
            "Authorization": "Bearer {file:github-pat}",
        },
    }
    print("→ MCP: github (remote; Authorization via {file:github-pat})")
else:
    servers.pop("github", None)

cfg = {}
if dest.is_file():
    cfg = load_jsonc(dest)
    if not isinstance(cfg, dict):
        raise SystemExit(f"error: {dest} não é um objeto")

cfg.setdefault("$schema", "https://opencode.ai/config.json")
cfg["model"] = f"ollama/{model}"
providers = cfg.setdefault("providers", {})
if not isinstance(providers, dict):
    raise SystemExit(f"error: {dest} providers não é um objeto")
ollama = providers.setdefault("ollama", {})
if not isinstance(ollama, dict):
    raise SystemExit(f"error: {dest} providers.ollama não é um objeto")
settings = ollama.setdefault("settings", {})
if not isinstance(settings, dict):
    raise SystemExit(f"error: {dest} providers.ollama.settings não é um objeto")
settings["baseURL"] = base_url
mcp = cfg.setdefault("mcp", {})
if not isinstance(mcp, dict):
    mcp = {}
    cfg["mcp"] = mcp
mcp["servers"] = servers

# Rules espelhadas (meta ~/git/.cursor + overlay ~/.cursor); OpenCode não lê
# frontmatter alwaysApply/globs — o glob inteiro vira instruction.
instr = cfg.get("instructions")
if not isinstance(instr, list):
    instr = []
# Tira globs velhos/quebrados do mirror (ex.: .../rules*.mdc sem /**/).
mirror_rules_marker = "/.config/opencode/.cursor/rules"
instr = [
    x
    for x in instr
    if not (isinstance(x, str) and mirror_rules_marker in x.replace("\\", "/"))
]
rules_dir = Path(instructions_glob.replace("/**/*.mdc", ""))
if rules_dir.is_dir() and any(rules_dir.glob("**/*.mdc")):
    instr.append(instructions_glob)
    print(f"→ instructions: {instructions_glob} ({sum(1 for _ in rules_dir.glob('**/*.mdc'))} .mdc)")
cfg["instructions"] = instr

# ~/.config/opencode/skills já é discovery global; reforça no array se existir.
if wire_skills and skills_dest.is_dir():
    skills = cfg.get("skills")
    if not isinstance(skills, list):
        skills = []
    skill_path = str(skills_dest)
    if skill_path not in skills and "~/.config/opencode/skills" not in skills:
        skills.append(skill_path)
    cfg["skills"] = skills
    print(f"→ skills: {skills_dest}")

tmp = dest.with_suffix(".json.tmp")
tmp.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
tmp.replace(dest)
print(f"→ config: {dest}")
print(f"→ modelo: ollama/{model} em {base_url}")
PY
}

install_opencode
if ! command -v python3 >/dev/null 2>&1; then
    echo "error: python3 ausente" >&2
    exit 1
fi
sync_cursor_into_opencode
ensure_host_ollama_rtx3060 || true
ensure_qwen38_opencode_model || true
write_config

tags_url="${base_url%/v1}/api/tags"
if ! curl -fsS --max-time 3 "$tags_url" >/dev/null 2>&1; then
    printf '→ host sem resposta em %s (Ollama da RTX 3060 precisa estar no ar em :%s)\n' "$tags_url" "$ollama_port" >&2
fi

if [ -x "${HOME}/.opencode/bin/opencode" ]; then
    case ":${PATH}:" in
        *":${HOME}/.opencode/bin:"*) ;;
        *)
            printf '→ no próximo terminal: export PATH="%s/.opencode/bin:$PATH"\n' "$HOME"
            ;;
    esac
fi
