#!/usr/bin/env bash
# O plano do Cursor acaba e o chat deixa de chamar modelo e MCP.
# Rode dentro da WorkVM. Instala o OpenCode 2, aponta o modelo para o
# Ollama da RTX no host e copia os MCP de ~/.cursor/mcp.json.
# O GitHub do Cursor é plugin (fora do mcp.json); injeta o MCP remoto
# oficial. O PAT vai em ~/.config/opencode/github-pat (chmod 600) e o
# JSON usa {file:github-pat} — {env:} vira Bearer vazio se o OpenCode
# não herdar o export (HTTP 400 "badly formatted").
# Não sobe o Ollama e não mexe no Cursor.
# Uso: bin/workvm-opencode.sh
set -euo pipefail

base_url="${WORKVM_OLLAMA_BASE_URL:-http://10.0.2.2:11435/v1}"
model="${WORKVM_OLLAMA_MODEL:-qwen3.8-4b}"
cursor_mcp="${HOME}/.cursor/mcp.json"
dest="${HOME}/.config/opencode/opencode.json"
github_pat_file="${HOME}/.config/opencode/github-pat"

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

write_config() {
    local github_ok=0

    mkdir -p "$(dirname "$dest")"
    if write_github_pat; then
        github_ok=1
        printf '→ github PAT: %s (chmod 600)\n' "$github_pat_file"
    else
        printf '→ github PAT ausente; MCP github não será configurado\n' >&2
        printf '  ex.: export GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token)"\n' >&2
        printf '  ou: gh auth login\n' >&2
    fi

    python3 - "$dest" "$cursor_mcp" "$base_url" "$model" "$github_ok" <<'PY'
import json, re, sys
from pathlib import Path

dest = Path(sys.argv[1])
cursor_mcp = Path(sys.argv[2])
base_url = sys.argv[3]
model = sys.argv[4]
github_ok = sys.argv[5] == "1"

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
write_config

tags_url="${base_url%/v1}/api/tags"
if ! curl -fsS --max-time 3 "$tags_url" >/dev/null 2>&1; then
    printf '→ host sem resposta em %s (o Ollama da RTX precisa estar no ar)\n' "$tags_url" >&2
fi

if [ -x "${HOME}/.opencode/bin/opencode" ]; then
    case ":${PATH}:" in
        *":${HOME}/.opencode/bin:"*) ;;
        *)
            printf '→ no próximo terminal: export PATH="%s/.opencode/bin:$PATH"\n' "$HOME"
            ;;
    esac
fi
