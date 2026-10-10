#!/usr/bin/env bash
# Rule do projeto ativo, patch de alwaysApply nos clones e merge de JSON do Cursor.
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
    if [ "${#CHROMIUM_URLS[@]}" -gt 0 ]; then
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
> Runtime symlink: \`~/.config/workvm/current\` → \`projects/${project}\`.
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
- **Workspace:** \`projects/${project}/workspace.code-workspace\`
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
    elif [ -n "$project" ] && [ -f "$git_root/projects/$project/project.conf" ]; then
        # shellcheck disable=SC1090
        source "$git_root/projects/$project/project.conf"
        git_root="${GIT_ROOT:-$git_root}"
        entries=("${CLONE_REPOS[@]+"${CLONE_REPOS[@]}"}")
    else
        return 0
    fi

    if [ "${#entries[@]}" -eq 0 ]; then
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

# Patch clones for every projects/**/project.conf (or a single project id).
workvm_patch_all_projects_clone_cursor() {
    local only="${1:-}"
    local git_root="${GIT_ROOT:-$HOME/git}"
    local projects_dir="$git_root/projects"
    local proj resolved

    if [ -n "$only" ]; then
        if ! resolved="$(workvm_resolve_project_id "$projects_dir" "$only")"; then
            echo "error: projeto desconhecido: $only" >&2
            return 1
        fi
        unset CLONE_REPOS 2>/dev/null || true
        CLONE_REPOS=()
        # shellcheck disable=SC1090
        source "$projects_dir/$resolved/project.conf"
        workvm_patch_project_clone_cursor "$resolved"
        return 0
    fi

    while IFS= read -r proj; do
        [ -n "$proj" ] || continue
        unset CLONE_REPOS 2>/dev/null || true
        CLONE_REPOS=()
        # shellcheck disable=SC1090
        source "$projects_dir/$proj/project.conf"
        workvm_patch_project_clone_cursor "$proj"
    done < <(workvm_list_project_ids "$projects_dir")
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

# Copia mcps/<nome>.json para ~/git/.cursor/mcp.json.
# Problema: o MCP compartilhado morava numa pasta-grupo só para o Cursor achar.
# Nome vazio apaga a cópia, para o projeto anterior não ficar no próximo.
workvm_apply_mcp() {
    local repo_root="${1:-}"
    local name="${2:-}"
    local dest src

    if [ -z "$repo_root" ]; then
        echo "error: workvm_apply_mcp <repo-root> [nome]" >&2
        return 1
    fi

    dest="$repo_root/.cursor/mcp.json"
    if [ -z "$name" ]; then
        if [ -f "$dest" ]; then
            rm -f "$dest"
            echo "→ MCP: removido (projeto sem MCP)"
        fi
        return 0
    fi

    src="$repo_root/mcps/$name.json"
    if [ ! -f "$src" ]; then
        echo "error: MCP '$name' não está em mcps/$name.json" >&2
        return 1
    fi
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
    echo "→ MCP: $name → .cursor/mcp.json"
}
