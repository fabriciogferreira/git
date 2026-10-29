#!/usr/bin/env bash
# Rule do projeto ativo, patch de alwaysApply nos clones, merge de JSON do Cursor
# e promoção dos MCP versionados para ~/.cursor/mcp.json.
# Problema: o patch local (skip-worktree) estava misturado com git, Docker e Wayland.
# Carregado por common.sh. Não dê source neste arquivo sozinho.

# Write ~/git/.cursor/rules/workvm-project.mdc (alwaysApply) so Cursor agents
# know which project this machine is bound to and where the clones live.
# The window root is ~/git. Product overlay rules stay in overlay/*/cursor (no dot).
# Expects CLONE_REPOS (and optionally COMPOSE_DIR, WAIT_URL, CHROMIUM_URLS)
# already sourced from project.conf. Safe to re-run.
workvm_write_cursor_project_rule() {
    local repo_root="$1"
    local project="$2"
    local git_root="${GIT_ROOT:-$HOME/git}"
    local out="$repo_root/.cursor/rules/workvm-project.mdc"
    local entry repo dest branch rest abs compose_disp
    local -a rows=()

    if [ -z "$repo_root" ] || [ -z "$project" ]; then
        echo "error: workvm_write_cursor_project_rule <repo_root> <project>" >&2
        return 1
    fi

    mkdir -p "$(dirname "$out")"

    for entry in "${CLONE_REPOS[@]+"${CLONE_REPOS[@]}"}"; do
        [ -n "$entry" ] || continue
        repo="${entry%% *}"
        rest="${entry#* }"
        if [ -z "$rest" ] || [ "$repo" = "$rest" ]; then
            echo "aviso: CLONE_REPOS entry inválida na rule Cursor: $entry" >&2
            continue
        fi
        dest="${rest%% *}"
        if [ "$dest" = "$rest" ]; then
            branch="—"
        else
            branch="${rest#* }"
            branch="${branch%% *}"
        fi
        case "$dest" in
            /*) abs="$dest" ;;
            *) abs="${git_root}/${dest}" ;;
        esac
        rows+=("| \`${repo}\` | \`${abs}\` | \`${branch}\` |")
    done

    compose_disp="${COMPOSE_DIR:-—}"
    case "$compose_disp" in
        /*) ;;
        —) ;;
        *) compose_disp="${git_root}/${compose_disp}" ;;
    esac

    local compose_file_disp="${COMPOSE_FILE:-docker-compose.yml}"
    local wait_disp="${WAIT_URL:-—}"
    local browser_disp="—"
    # project.conf de biblioteca não declara o array. set -u trata
    # ${#CHROMIUM_URLS[@]} não declarado como unbound e aborta o setup.
    if [ -n "${CHROMIUM_URLS+x}" ] && [ "${#CHROMIUM_URLS[@]}" -gt 0 ]; then
        browser_disp="${CHROMIUM_URLS[*]}"
    fi

    cat >"$out" <<EOF
---
description: Projeto workvm ativo nesta VM (${project}) — repos e caminhos
alwaysApply: true
---

# WorkVM ativo: \`${project}\`

> Gerado por \`project-setup.sh\` via \`workvm_write_cursor_project_rule\`.
> Não edite à mão — rode de novo o project-setup para atualizar.
> Runtime symlink: \`~/.config/workvm/current\` → pasta do projeto (\`${project}/\`).
> A janela abre o meta-repo \`~/git\` e os clones deste projeto.

## Repositórios

| Git URL | Caminho local | Branch |
| --- | --- | --- |
EOF

    if [ "${#rows[@]}" -gt 0 ]; then
        local row
        for row in "${rows[@]}"; do
            printf '%s\n' "$row" >>"$out"
        done
    else
        printf '%s\n' '| _(nenhum CLONE_REPOS)_ | — | — |' >>"$out"
    fi

    cat >>"$out" <<EOF

## Runtime

- **Compose dir:** \`${compose_disp}\`
- **Compose file:** \`${compose_file_disp}\`
- **Wait URL:** \`${wait_disp}\`
- **Browser URLs:** \`${browser_disp}\`
- **Workspace:** \`workspace.code-workspace\` na pasta do projeto
- **Start:** \`lib/project-start.sh\` com \`~/.config/workvm/current\` (via \`workvm.service\`)

Ao trabalhar nesta VM, trate os caminhos da tabela como o escopo do projeto ativo.
EOF

    echo "→ Cursor rule: $out"
}

# --- Local Cursor patches on clones (never commit; skip-worktree) -----------------
# Multi-root loads alwaysApply from every root. Downgrade clone alwaysApply rules
# to globs, and relocate AGENTS.md into a globs-scoped .mdc, so backend-only chats
# do not pull frontend alwaysApply noise. Remote repos stay unchanged if not committed.
# Rewrite .mdc frontmatter: alwaysApply true → false; ensure globs present.
workvm_patch_mdc_always_apply() {
    local file="$1"
    python3 - "$file" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
if not text.startswith("---"):
    sys.exit(0)
parts = text.split("---", 2)
if len(parts) < 3:
    sys.exit(0)
fm, body = parts[1], parts[2]
if not re.search(r"(?m)^alwaysApply:\s*true\s*$", fm):
    sys.exit(0)
fm = re.sub(r"(?m)^alwaysApply:\s*true\s*$", "alwaysApply: false", fm)
if not re.search(r"(?m)^globs:\s*", fm):
    fm = fm.rstrip() + '\nglobs: "**/*"\n'
else:
    fm = fm if fm.endswith("\n") else fm + "\n"
open(path, "w", encoding="utf-8").write(f"---{fm}---{body}")
print(path)
PY
}

# One clone: patch alwaysApply .mdc + relocate AGENTS.md → globs-scoped rule.
workvm_patch_clone_cursor() {
    local clone="$1"
    local rules_dir agents dest_mdc f patched

    if [ ! -d "$clone/.git" ]; then
        return 0
    fi

    rules_dir="$clone/.cursor/rules"
    if [ -d "$rules_dir" ]; then
        shopt -s nullglob
        for f in "$rules_dir"/*.mdc; do
            # Skip our generated relocation target
            if [ "$(basename "$f")" = "workvm-local-agents.mdc" ]; then
                continue
            fi
            if ! grep -qE '^alwaysApply:[[:space:]]*true[[:space:]]*$' "$f"; then
                continue
            fi
            workvm_git_unskip_worktree "$clone" "$f"
            patched="$(workvm_patch_mdc_always_apply "$f" || true)"
            if [ -n "$patched" ]; then
                workvm_git_skip_worktree "$clone" "$f"
                echo "  cursor patch: ${f#"${clone}/"} (alwaysApply→false + globs)"
            fi
        done
        shopt -u nullglob
    fi

    agents="$clone/AGENTS.md"
    dest_mdc="$clone/.cursor/rules/workvm-local-agents.mdc"
    if [ -f "$agents" ]; then
        mkdir -p "$clone/.cursor/rules"
        workvm_git_exclude_add "$clone" ".cursor/rules/workvm-local-agents.mdc"
        if grep -q 'workvm-local-agents.mdc' "$agents" 2>/dev/null && [ -f "$dest_mdc" ]; then
            workvm_git_skip_worktree "$clone" "$agents"
        else
            workvm_git_unskip_worktree "$clone" "$agents"
            cat >"$dest_mdc" <<EOF
---
description: AGENTS.md relocated by workvm (local only — do not commit)
globs: "**/*"
alwaysApply: false
---

EOF
            cat "$agents" >>"$dest_mdc"
            cat >"$agents" <<'EOF'
<!-- workvm-local: full AGENTS.md moved to .cursor/rules/workvm-local-agents.mdc -->
<!-- Local patch for multi-root Cursor (skip-worktree). Do not commit. -->

# Agent guidelines

Guidelines for this repository live in `.cursor/rules/workvm-local-agents.mdc`
(scoped with globs so they apply when files here are in focus, not in every
multi-root chat).
EOF
            workvm_git_skip_worktree "$clone" "$agents"
            echo "  cursor patch: AGENTS.md → .cursor/rules/workvm-local-agents.mdc"
        fi
    fi
}

# Patch all CLONE_REPOS for a project (uses sourced CLONE_REPOS or project.conf).
workvm_patch_project_clone_cursor() {
    local project="${1:-}"
    local git_root="${GIT_ROOT:-$HOME/git}"
    local entry repo dest rest abs
    local -a entries=()

    if [ -n "${CLONE_REPOS+x}" ] && [ "${#CLONE_REPOS[@]}" -gt 0 ]; then
        entries=("${CLONE_REPOS[@]}")
    elif [ -n "$project" ]; then
        local pdir
        pdir="$(workvm_project_dir "$git_root" "$project" 2>/dev/null || true)"
        if [ -n "$pdir" ] && [ -f "$pdir/project.conf" ]; then
            # shellcheck disable=SC1090
            source "$pdir/project.conf"
            git_root="${GIT_ROOT:-$git_root}"
            entries=("${CLONE_REPOS[@]+"${CLONE_REPOS[@]}"}")
        else
            return 0
        fi
    else
        return 0
    fi

    if [ "${#entries[@]}" -eq 0 ]; then
        return 0
    fi

    # boilerplate-next versiona .cursor. O skip-worktree esconderia o próximo arquivo.
    if [ "${CURSOR_CLONE_PATCH:-1}" = "0" ]; then
        echo "→ Patch Cursor do clone pulado: .cursor entra no git deste projeto"
        return 0
    fi

    local -a found=()
    for entry in "${entries[@]}"; do
        [ -n "$entry" ] || continue
        repo="${entry%% *}"
        rest="${entry#* }"
        if [ -z "$rest" ] || [ "$repo" = "$rest" ]; then
            continue
        fi
        dest="${rest%% *}"
        case "$dest" in
            /*) abs="$dest" ;;
            *) abs="${git_root}/${dest}" ;;
        esac
        if [ -d "$abs/.git" ]; then
            found+=("$abs")
        fi
    done

    if [ "${#found[@]}" -eq 0 ]; then
        return 0
    fi

    echo "→ Patch local Cursor rules nos clones (alwaysApply→globs; não commitar)"
    for abs in "${found[@]}"; do
        echo "  clone: $abs"
        workvm_patch_clone_cursor "$abs"
    done
}

# Patch clones for every project.conf (or a single project id).
workvm_patch_all_projects_clone_cursor() {
    local only="${1:-}"
    local git_root="${GIT_ROOT:-$HOME/git}"
    local proj resolved pdir

    if [ -n "$only" ]; then
        if ! resolved="$(workvm_resolve_project_id "$git_root" "$only")"; then
            echo "error: projeto desconhecido: $only" >&2
            return 1
        fi
        pdir="$(workvm_project_dir "$git_root" "$resolved")" || return 1
        unset CLONE_REPOS 2>/dev/null || true
        unset CURSOR_CLONE_PATCH
        CLONE_REPOS=()
        # shellcheck disable=SC1090
        source "$pdir/project.conf"
        workvm_patch_project_clone_cursor "$resolved"
        return 0
    fi

    while IFS= read -r proj; do
        [ -n "$proj" ] || continue
        pdir="$(workvm_project_dir "$git_root" "$proj")" || continue
        unset CLONE_REPOS 2>/dev/null || true
        unset CURSOR_CLONE_PATCH
        CLONE_REPOS=()
        # shellcheck disable=SC1090
        source "$pdir/project.conf"
        workvm_patch_project_clone_cursor "$proj"
    done < <(workvm_list_project_ids "$git_root")
}

# Merge top-level keys from $2 (source) into $1 (dest). Creates dest if missing.
# Existing keys are overwritten, missing keys are added; other dest keys stay.
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

merged = {**dest, **source}
dest_path.write_text(
    json.dumps(merged, indent="\t", ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY
}

# Marker ao lado do .cursor/mcp.json de projeto: conteúdo foi para ~/.cursor/mcp.json.
# JSON puro não tem comentário; o marker diz que o arquivo local é stub.
WORKVM_MCP_USER_MARKER="mcp.workvm-user"

# Repo git que cobre um arquivo (clone ou meta-repo), ou vazio.
workvm_mcp_git_repo() {
    local file="$1"
    local dir
    dir="$(dirname "$file")"
    git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true
}

# Se o mcp.json local é stub, restaura o versionado (fetch/overlay já rodaram).
workvm_mcp_restore_project_file() {
    local file="$1"
    local marker="$2"
    local repo rel

    [ -f "$marker" ] || return 0
    repo="$(workvm_mcp_git_repo "$file")"
    [ -n "$repo" ] || return 0
    rel="$(workvm_git_relpath "$repo" "$file")"
    if ! git -C "$repo" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
        return 0
    fi
    workvm_git_unskip_worktree "$repo" "$file"
    git -C "$repo" checkout HEAD -- "$rel" 2>/dev/null || true
}

# Stub local: Cursor não registra MCP de projeto (exige opt-in e sobrescreve
# o user-level com o mesmo nome). skip-worktree — não commitar.
workvm_mcp_stub_project_file() {
    local file="$1"
    local marker="$2"
    local repo rel

    mkdir -p "$(dirname "$file")"
    cat >"$file" <<'EOF' || return 1
{
  "mcpServers": {}
}
EOF
    cat >"$marker" <<'EOF' || return 1
workvm-local: MCP servers promoted to ~/.cursor/mcp.json
Do not commit this stub. Source of truth stays versioned; login re-merges.
EOF
    repo="$(workvm_mcp_git_repo "$file")"
    [ -n "$repo" ] || return 0
    # Path relativo ao repo: e2e em projects/ não é `.cursor/` na raiz.
    workvm_git_exclude_add "$repo" "$(workvm_git_relpath "$repo" "$marker")"
    rel="$(workvm_git_relpath "$repo" "$file")"
    if git -C "$repo" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
        workvm_git_skip_worktree "$repo" "$file"
    fi
}

# Junta o mcps/<MCP>.json do projeto ativo (só se MCP= estiver setado),
# .cursor/mcp.json dos CLONE_REPOS, E2E_COMPOSE_DIRS e suítes sob
# <projeto>/*/ em ~/.cursor/mcp.json (user-level).
# Problema: MCP só em .cursor/mcp.json do root exige opt-in manual a cada
# workspace; user-level não. Relê no login porque os fontes são versionados.
# Stub local nos de projeto para o nome igual não ganhar do global desligado.
# Não mescla todos os mcps/*.json: opbed/etc. não devem ganhar olie-flow-ai.
# Espera MCP/CLONE_REPOS/E2E já sourced. Uso: workvm_apply_mcp <repo-root> [nome] [project-dir]
workvm_apply_mcp() {
    local repo_root="${1:-}"
    local name="${2:-}"
    local project_dir="${3:-}"
    local git_root="${GIT_ROOT:-$HOME/git}"
    local dest="${HOME}/.cursor/mcp.json"
    local legacy_dest="$repo_root/.cursor/mcp.json"
    local legacy_marker="$repo_root/.cursor/${WORKVM_MCP_USER_MARKER}"
    local src entry repo rest abs path marker child project_id
    local -a sources=()
    local -a stub_targets=()

    if [ -z "$repo_root" ]; then
        echo "error: workvm_apply_mcp <repo-root> [nome] [project-dir]" >&2
        return 1
    fi

    # Compat: project-setup ainda passa o nome; preferir o da linha, senão $MCP.
    if [ -n "$name" ]; then
        MCP="$name"
    fi
    name="${MCP:-}"
    project_id=""
    if [ -n "$project_dir" ]; then
        project_id="$(basename "$project_dir")"
    fi

    # MCP nomeado pelo projeto: só o arquivo pedido, e olie só em projetos do board.
    if [ -n "$name" ]; then
        src="$repo_root/mcps/$name.json"
        if [ ! -f "$src" ]; then
            echo "error: MCP '$name' não está em mcps/$name.json" >&2
            return 1
        fi
        if [ "$name" = "olie" ]; then
            case "$project_id" in
                olie|locav|televisao) ;;
                *)
                    echo "error: MCP=olie só para olie, locav e televisao (projeto=${project_id:-?})" >&2
                    return 1
                    ;;
            esac
        fi
        sources+=("$src")
    fi

    for entry in "${CLONE_REPOS[@]+"${CLONE_REPOS[@]}"}"; do
        [ -n "$entry" ] || continue
        repo="${entry%% *}"
        rest="${entry#* }"
        if [ -z "$rest" ] || [ "$repo" = "$rest" ]; then
            continue
        fi
        abs="${rest%% *}"
        case "$abs" in
            /*) ;;
            *) abs="${git_root}/${abs}" ;;
        esac
        path="$abs/.cursor/mcp.json"
        marker="$abs/.cursor/${WORKVM_MCP_USER_MARKER}"
        workvm_mcp_restore_project_file "$path" "$marker"
        if [ -f "$path" ]; then
            sources+=("$path")
            stub_targets+=("$path")
        fi
    done

    for abs in "${E2E_COMPOSE_DIRS[@]+"${E2E_COMPOSE_DIRS[@]}"}"; do
        [ -n "$abs" ] || continue
        path="$abs/.cursor/mcp.json"
        marker="$abs/.cursor/${WORKVM_MCP_USER_MARKER}"
        workvm_mcp_restore_project_file "$path" "$marker"
        if [ -f "$path" ]; then
            sources+=("$path")
            stub_targets+=("$path")
        fi
    done

    # e2e versionado em projects/<id>/<suite>/.cursor/mcp.json (olie-e2e, etc.).
    if [ -n "$project_dir" ] && [ -d "$project_dir" ]; then
        shopt -s nullglob
        for child in "$project_dir"/*/; do
            path="${child}.cursor/mcp.json"
            marker="${child}.cursor/${WORKVM_MCP_USER_MARKER}"
            # Já coberto por E2E_COMPOSE_DIRS.
            case " ${E2E_COMPOSE_DIRS[*]+"${E2E_COMPOSE_DIRS[*]}"} " in
                *" ${child%/} "*) continue ;;
            esac
            workvm_mcp_restore_project_file "$path" "$marker"
            if [ -f "$path" ]; then
                sources+=("$path")
                stub_targets+=("$path")
            fi
        done
        shopt -u nullglob
    fi

    mkdir -p "$(dirname "$dest")" "$repo_root/.cursor"

    if [ "${#sources[@]}" -eq 0 ]; then
        cat >"$dest" <<'EOF'
{
  "mcpServers": {}
}
EOF
        rm -f "$legacy_dest" "$legacy_marker"
        echo "→ MCP user: ~/.cursor/mcp.json vazio (projeto sem fontes)"
        return 0
    fi

    local used_file path
    used_file="$(mktemp)"
    local docker_mcp_wrapper="$repo_root/bin/workvm-docker-mcp.sh"
    if ! python3 - "$dest" "$used_file" "$docker_mcp_wrapper" "${sources[@]}" <<'PY'
import json, re, sys
from pathlib import Path

def load_jsonc(path: Path):
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    # Só comentário de linha inteira — não cortar https://
    text = re.sub(r"(?m)^\s*//.*?$", "", text)
    text = re.sub(r",\s*([}\]])", r"\1", text)
    return json.loads(text)

# Cursor connects MCP before compose finishes. Plain `docker exec` fails once
# and stays failed. Route those servers through bin/workvm-docker-mcp.sh.
def wrap_docker_exec(cfg: dict, wrapper: str) -> dict:
    if not isinstance(cfg, dict):
        return cfg
    cmd = cfg.get("command")
    args = cfg.get("args")
    if not isinstance(args, list) or not args:
        return cfg
    if isinstance(cmd, str) and cmd.endswith("workvm-docker-mcp.sh"):
        out = dict(cfg)
        out["command"] = wrapper
        return out
    if cmd != "docker":
        return cfg
    a = list(args)
    i = 0
    if a[0] == "container":
        i = 1
    if i >= len(a) or a[i] != "exec":
        return cfg
    i += 1
    while i < len(a) and a[i].startswith("-"):
        flag = a[i]
        if flag in ("-i", "-t", "-it", "-ti", "-d", "-tty", "--tty", "--interactive", "--detach"):
            i += 1
            continue
        if flag in ("-u", "--user", "-w", "--workdir", "-e", "--env") and i + 1 < len(a):
            i += 2
            continue
        if flag.startswith("--") and "=" in flag:
            i += 1
            continue
        break
    if i >= len(a):
        return cfg
    container = a[i]
    rest = a[i + 1 :]
    if not rest:
        return cfg
    out = dict(cfg)
    out["command"] = wrapper
    out["args"] = [container, *rest]
    return out

dest = Path(sys.argv[1])
used_file = Path(sys.argv[2])
wrapper = sys.argv[3]
merged = {}
used = []
for raw in sys.argv[4:]:
    path = Path(raw)
    if not path.is_file():
        continue
    data = load_jsonc(path)
    if not isinstance(data, dict):
        raise SystemExit(f"error: JSON de origem não é um objeto: {path}")
    servers = data.get("mcpServers")
    if not isinstance(servers, dict) or not servers:
        continue
    merged.update(servers)
    used.append(str(path))

# api.olie.ai answers OAuth discovery, and Cursor then ignores the Bearer
# header. The agent reports needsAuth. Point the merged server at the local
# proxy (bin/workvm-olie-mcp-proxy.py, port 47331) and drop the header.
olie = merged.get("olie-flow-ai")
if isinstance(olie, dict):
    olie = dict(olie)
    olie["url"] = "http://127.0.0.1:47331/mcp/management"
    olie.pop("headers", None)
    merged["olie-flow-ai"] = olie

for name, cfg in list(merged.items()):
    if isinstance(cfg, dict):
        merged[name] = wrap_docker_exec(cfg, wrapper)

dest.write_text(
    json.dumps({"mcpServers": merged}, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
used_file.write_text("\n".join(used) + ("\n" if used else ""), encoding="utf-8")
print(f"→ MCP user: {len(merged)} server(s) → {dest}")
PY
    then
        rm -f "$used_file"
        echo "error: falha ao juntar MCP em ~/.cursor/mcp.json" >&2
        return 1
    fi

    # Stub só nos de projeto que entraram no merge (não em mcps/*.json).
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        case "$path" in
            "$repo_root"/mcps/*.json) continue ;;
        esac
        case " ${stub_targets[*]+"${stub_targets[*]}"} " in
            *" $path "*) ;;
            *) continue ;;
        esac
        marker="$(dirname "$path")/${WORKVM_MCP_USER_MARKER}"
        workvm_mcp_stub_project_file "$path" "$marker"
        echo "  stub: $path"
    done <"$used_file"
    rm -f "$used_file"

    # Cópia antiga em ~/git/.cursor/mcp.json não pode competir com o user-level.
    if [ -f "$legacy_dest" ] || [ -f "$legacy_marker" ]; then
        workvm_mcp_stub_project_file "$legacy_dest" "$legacy_marker"
        echo "  stub: $legacy_dest"
    fi
}
