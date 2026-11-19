# Host card unit (no WorkVM): state, workspace, ensure/destroy.
# Problema: N cards no jarvis colidem sem id/porta/workspace próprios; a domain
# libvirt fazia isso de graça. Este helper é o contrato mínimo do
# host-cards-no-vm.md até o compose namespaced estar completo por projeto.

workvm_host_card_root() {
    printf '%s\n' "${WORKVM_HOST_CARD_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/workvm/host-cards}"
}

workvm_host_card_git_root() {
    printf '%s\n' "${GIT_ROOT:-$HOME/git}"
}

workvm_host_card_meta_repo() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    printf '%s\n' "$here"
}

workvm_host_card_log() {
    printf 'workvm-host-card: %s\n' "$*" >&2
}

# Escreve SB_MEM/SB_CPUS no .env do compose e, por padrão, tira cpus/mem_limit
# dos YAMLs do card. Problema: default 1 CPU/1G por serviço fazia Pest disputar
# mal e o MySQL bater no teto enquanto o host ainda tinha folga; host-card deve
# deixar o CFS do kernel ratear. Teto só se WORKVM_HOST_CARD_MEM e/ou
# WORKVM_HOST_CARD_CPUS estiverem setados (ex.: MEM=2g CPUS=2).
# Uso: workvm_host_card_write_resource_env >> partial; depois
# workvm_host_card_apply_compose_limits "$compose_dir".
workvm_host_card_write_resource_env() {
    if [ -n "${WORKVM_HOST_CARD_MEM:-}" ]; then
        printf 'SB_MEM=%s\n' "$WORKVM_HOST_CARD_MEM"
    else
        # placeholders inócuos se algum YAML ainda interpolar
        printf 'SB_MEM=0\n'
    fi
    if [ -n "${WORKVM_HOST_CARD_CPUS:-}" ]; then
        printf 'SB_CPUS=%s\n' "$WORKVM_HOST_CARD_CPUS"
    else
        printf 'SB_CPUS=0\n'
    fi
}

workvm_host_card_apply_compose_limits() {
    local compose_dir="$1"
    local f
    if [ -n "${WORKVM_HOST_CARD_MEM:-}" ] || [ -n "${WORKVM_HOST_CARD_CPUS:-}" ]; then
        workvm_host_card_log "teto de recurso: MEM=${WORKVM_HOST_CARD_MEM:-∅} CPUS=${WORKVM_HOST_CARD_CPUS:-∅}"
        return 0
    fi
    workvm_host_card_log "sem cpus/mem_limit — containers disputam o host"
    for f in "$compose_dir"/compose.yaml "$compose_dir"/compose.*.yml; do
        [ -f "$f" ] || continue
        # remove hard caps do slim/front (mem_limit / cpus)
        sed -i -E '/^[[:space:]]*(mem_limit|cpus):/d' "$f"
    done
}

# Isolamento Olie por card: worktree de cada CLONE_REPOS + meta-repo ~/git,
# reflink/copy de vendor e node_modules a partir da base instalada.
# Problema: só api-main isolado + clones shared no workspace era frágil (SCM
# (shared), edição no path errado). Contrato: host-cards-no-vm.md §4.
# Uso: prepare no ensure; remove no destroy (antes do rm -rf do state dir).
# Código do card (ex. DOP-1273) → checkout da branch no worktree (não na base).

workvm_host_card_api_src() {
    printf '%s/olie/api-main\n' "$(workvm_host_card_git_root)"
}

# Reflink (btrfs) ou rsync. $1=src dir $2=dst dir (árvore final).
# Skip se dst já tem conteúdo (resume barato).
workvm_host_card_copy_heavy() {
    local src="$1"
    local dst="$2"

    if [ ! -d "$src" ]; then
        return 1
    fi
    if [ -d "$dst" ] && [ -n "$(ls -A "$dst" 2>/dev/null || true)" ]; then
        workvm_host_card_log "heavy já existe: $dst"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst"
    if cp --reflink=always -a "$src" "$dst" 2>/dev/null; then
        workvm_host_card_log "reflink $src → $dst"
        return 0
    fi
    workvm_host_card_log "rsync $src → $dst"
    mkdir -p "$dst"
    rsync -a "${src}/" "${dst}/" || return 1
}

# Resolve branch cujo nome contém $code (local, senão origin). Exit 1 se não achar.
workvm_host_card_resolve_card_branch() {
    local src="$1"
    local code="$2"
    local ref short

    [ -n "$code" ] || return 1

    while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        if printf '%s' "$ref" | grep -qiF -- "$code"; then
            printf '%s\n' "$ref"
            return 0
        fi
    done < <(git -C "$src" for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads/)

    while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        case "$ref" in
            origin/HEAD) continue ;;
        esac
        short="${ref#origin/}"
        if printf '%s' "$short" | grep -qiF -- "$code"; then
            printf '%s\n' "$short"
            return 0
        fi
    done < <(git -C "$src" for-each-ref --sort=-committerdate --format='%(refname:short)' refs/remotes/origin/)

    return 1
}

# Compat: nome antigo usado em logs/chamadas.
workvm_host_card_resolve_api_card_branch() {
    workvm_host_card_resolve_card_branch "$@"
}

# Checkout da branch do card num worktree já existente (não mexe na base).
workvm_host_card_checkout_worktree_branch() {
    local wt="$1"
    local src="$2"
    local code="$3"
    local name branch cur

    [ -n "$code" ] || return 0
    if [ ! -d "$wt" ] || { [ ! -d "${wt}/.git" ] && [ ! -f "${wt}/.git" ]; }; then
        return 0
    fi
    name="$(basename "$wt")"

    git -C "$src" fetch origin --prune --quiet 2>/dev/null \
        || workvm_host_card_log "fetch origin falhou em $name (refs locais)"

    branch="$(workvm_host_card_resolve_card_branch "$src" "$code" || true)"
    if [ -z "$branch" ]; then
        workvm_host_card_log "$name: sem branch com $code — worktree em HEAD"
        return 0
    fi

    cur="$(git -C "$wt" branch --show-current 2>/dev/null || true)"
    if [ "$cur" = "$branch" ]; then
        workvm_host_card_log "$name worktree já em $branch"
        return 0
    fi

    if git -C "$src" show-ref --verify --quiet "refs/heads/${branch}"; then
        workvm_host_card_log "$name worktree → $branch"
        git -C "$wt" -c core.hooksPath=/dev/null checkout "$branch" \
            || workvm_host_card_log "checkout $branch falhou em $name (dirty? branch noutro worktree?)"
    elif git -C "$src" show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
        workvm_host_card_log "$name worktree → $branch (de origin)"
        git -C "$wt" -c core.hooksPath=/dev/null checkout -B "$branch" "origin/${branch}" \
            || workvm_host_card_log "checkout -B $branch falhou em $name"
    else
        workvm_host_card_log "$name: branch $branch sumiu após resolve"
    fi
}

workvm_host_card_checkout_api_card_branch() {
    local dir="$1"
    local code="$2"
    workvm_host_card_checkout_worktree_branch \
        "${dir}/worktree/api-main" "$(workvm_host_card_api_src)" "$code"
}

# Cria (ou retoma) um worktree em $wt a partir da base $src.
# Com $code: tenta a branch do card; se estiver noutro worktree → --detach no tip.
workvm_host_card_add_repo_worktree() {
    local src="$1"
    local wt="$2"
    local code="${3:-}"
    local name branch
    name="$(basename "$wt")"

    if [ ! -d "${src}/.git" ] && [ ! -f "${src}/.git" ]; then
        workvm_host_card_log "base não é git, skip: $src"
        return 1
    fi

    if [ -d "$wt" ] && { [ -d "${wt}/.git" ] || [ -f "${wt}/.git" ]; }; then
        workvm_host_card_log "worktree já existe: $wt"
        if [ -n "$code" ]; then
            workvm_host_card_checkout_worktree_branch "$wt" "$src" "$code"
        fi
        return 0
    fi

    rm -rf "$wt"
    mkdir -p "$(dirname "$wt")"
    branch=""
    if [ -n "$code" ]; then
        git -C "$src" fetch origin --prune --quiet 2>/dev/null || true
        branch="$(workvm_host_card_resolve_card_branch "$src" "$code" || true)"
    fi

    # Hooks do clone podem chamar docker exec olie-api-main (ausente no host).
    if [ -n "$branch" ] && git -C "$src" show-ref --verify --quiet "refs/heads/${branch}"; then
        if git -C "$src" -c core.hooksPath=/dev/null worktree add "$wt" "$branch" 2>/dev/null; then
            workvm_host_card_log "worktree add $name → $branch"
            return 0
        fi
        workvm_host_card_log "worktree add --detach $name @ $branch (branch noutro worktree)"
        git -C "$src" -c core.hooksPath=/dev/null worktree add --detach "$wt" "$branch" || return 1
        return 0
    fi
    if [ -n "$branch" ] && git -C "$src" show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
        if git -C "$src" -c core.hooksPath=/dev/null worktree add -b "$branch" "$wt" "origin/${branch}" 2>/dev/null; then
            workvm_host_card_log "worktree add -b $name → $branch (origin)"
            return 0
        fi
        workvm_host_card_log "worktree add --detach $name @ origin/$branch"
        git -C "$src" -c core.hooksPath=/dev/null worktree add --detach "$wt" "origin/${branch}" || return 1
        return 0
    fi

    workvm_host_card_log "worktree add --detach $name (HEAD)"
    git -C "$src" -c core.hooksPath=/dev/null worktree add --detach "$wt" HEAD || return 1
}

# Alinha o meta worktree do card ao HEAD do ~/git ao vivo (detached).
# Problema: open/ensure em card já criado deixava prompts/sandbox velhos no
# worktree/git; updates no meta-repo não apareciam na janela do card.
workvm_host_card_sync_meta_worktree() {
    local dir="$1"
    local src wt live short card
    src="$(workvm_host_card_meta_repo)"
    wt="${dir}/worktree/git"

    if [ ! -d "$wt" ] || { [ ! -d "${wt}/.git" ] && [ ! -f "${wt}/.git" ]; }; then
        return 0
    fi
    if [ ! -d "${src}/.git" ] && [ ! -f "${src}/.git" ]; then
        return 0
    fi

    live="$(git -C "$src" rev-parse HEAD)" || return 1
    short="$(git -C "$src" log -1 --oneline)"
    card="$(git -C "$wt" rev-parse HEAD 2>/dev/null || true)"
    if [ "$card" = "$live" ]; then
        workvm_host_card_log "meta worktree já em $short"
        return 0
    fi
    workvm_host_card_log "meta worktree → $short (sync do meta ao vivo)"
    # reset --hard: tracked dirty no card some; untracked (rascunho e2e) fica.
    git -C "$wt" -c core.hooksPath=/dev/null reset --hard "$live" || return 1
}

# Meta-repo: sempre --detach (a branch de ~/git fica no clone “ao vivo”).
workvm_host_card_add_meta_worktree() {
    local dir="$1"
    local src wt
    src="$(workvm_host_card_meta_repo)"
    wt="${dir}/worktree/git"

    if [ ! -d "${src}/.git" ] && [ ! -f "${src}/.git" ]; then
        workvm_host_card_log "meta-repo não é git: $src"
        return 1
    fi
    if [ -d "$wt" ] && { [ -d "${wt}/.git" ] || [ -f "${wt}/.git" ]; }; then
        workvm_host_card_sync_meta_worktree "$dir" || return 1
        return 0
    fi
    rm -rf "$wt"
    mkdir -p "$(dirname "$wt")"
    workvm_host_card_log "worktree add --detach git (meta) @ HEAD"
    git -C "$src" -c core.hooksPath=/dev/null worktree add --detach "$wt" HEAD || return 1
}

# Lista "basename src_abs" dos CLONE_REPOS do project.conf Olie (+ meta).
workvm_host_card_olie_repo_bases() {
    local meta_repo git_root conf
    meta_repo="$(workvm_host_card_meta_repo)"
    git_root="$(workvm_host_card_git_root)"
    conf="${meta_repo}/olie/project.conf"
    # shellcheck source=/dev/null
    source "$conf"
    local entry url path branch name
    for entry in "${CLONE_REPOS[@]}"; do
        # shellcheck disable=SC2086
        set -- $entry
        path="${2:-}"
        [ -n "$path" ] || continue
        name="$(basename "$path")"
        printf '%s %s\n' "$name" "${git_root}/${path}"
    done
}

workvm_host_card_prepare_olie_isolation() {
    local dir="$1"
    local code="${2:-}"
    local wt_root wt_api vendor_dst src_api fronts_base fronts_wt line name src
    local nm_src nm_dst pkg

    wt_root="${dir}/worktree"
    wt_api="${wt_root}/api-main"
    vendor_dst="${dir}/vendor"
    src_api="$(workvm_host_card_api_src)"
    fronts_base="$(workvm_host_card_git_root)/olie/olie-fronts"
    fronts_wt="${wt_root}/olie-fronts"

    mkdir -p "$wt_root"

    workvm_host_card_add_meta_worktree "$dir" || return 1

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        name="${line%% *}"
        src="${line#* }"
        if [ ! -d "$src" ]; then
            workvm_host_card_log "clone ausente, skip worktree: $src"
            continue
        fi
        workvm_host_card_add_repo_worktree "$src" "${wt_root}/${name}" "$code" \
            || workvm_host_card_log "worktree falhou: $name"
    done < <(workvm_host_card_olie_repo_bases)

    if [ ! -d "$wt_api" ] || { [ ! -d "${wt_api}/.git" ] && [ ! -f "${wt_api}/.git" ]; }; then
        workvm_host_card_log "api-main worktree obrigatório ausente: $wt_api"
        return 1
    fi
    if [ ! -f "${src_api}/vendor/autoload.php" ]; then
        workvm_host_card_log "vendor ausente na base: ${src_api}/vendor (composer install)"
        return 1
    fi

    mkdir -p \
        "${wt_api}/storage/logs" \
        "${wt_api}/storage/framework/cache" \
        "${wt_api}/storage/framework/sessions" \
        "${wt_api}/storage/framework/views" \
        "${wt_api}/bootstrap/cache" \
        "${wt_api}/vendor"
    # Placeholder: vendor real via bind SB_API_VENDOR (cópia por card).
    if [ ! -f "${wt_api}/vendor/README.host-card.md" ]; then
        printf '# vendor montado em runtime (SB_API_VENDOR → /var/www/html/vendor)\n' \
            >"${wt_api}/vendor/README.host-card.md"
    fi

    # vendor do card (compose bind); resume não re-copia se já populado.
    if [ -f "${vendor_dst}/autoload.php" ]; then
        workvm_host_card_log "vendor do card já existe: $vendor_dst"
    else
        workvm_host_card_copy_heavy "${src_api}/vendor" "$vendor_dst" || return 1
    fi

    # .env do card (não o da base)
    if [ ! -f "${wt_api}/.env" ]; then
        if [ -f "${src_api}/.env" ]; then
            cp -f "${src_api}/.env" "${wt_api}/.env"
        elif [ -f "${src_api}/.env.example" ]; then
            cp -f "${src_api}/.env.example" "${wt_api}/.env"
        else
            printf 'APP_KEY=base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\n' >"${wt_api}/.env"
        fi
    fi

    # node_modules da base → worktree olie-fronts (compose monta o worktree).
    if [ -d "$fronts_wt" ] && [ -d "${fronts_base}/node_modules" ]; then
        workvm_host_card_copy_heavy "${fronts_base}/node_modules" "${fronts_wt}/node_modules" \
            || workvm_host_card_log "copy node_modules root falhou"
        for pkg in "${fronts_base}/packages"/*/node_modules; do
            [ -d "$pkg" ] || continue
            nm_src="$pkg"
            nm_dst="${fronts_wt}/packages/$(basename "$(dirname "$pkg")")/node_modules"
            mkdir -p "$(dirname "$nm_dst")"
            workvm_host_card_copy_heavy "$nm_src" "$nm_dst" \
                || workvm_host_card_log "copy $nm_dst falhou"
        done
    fi
}

# Compat nome antigo (destroy hook / ensure).
workvm_host_card_prepare_api_isolation() {
    workvm_host_card_prepare_olie_isolation "$@"
}

workvm_host_card_remove_olie_isolation() {
    local dir="$1"
    local wt_root meta_src line name src wt

    wt_root="${dir}/worktree"
    meta_src="$(workvm_host_card_meta_repo)"

    if [ -d "${wt_root}/git" ]; then
        workvm_host_card_log "git worktree remove meta ${wt_root}/git"
        git -C "$meta_src" worktree remove --force "${wt_root}/git" 2>/dev/null \
            || rm -rf "${wt_root}/git"
    fi

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        name="${line%% *}"
        src="${line#* }"
        wt="${wt_root}/${name}"
        [ -d "$wt" ] || continue
        workvm_host_card_log "git worktree remove $name"
        if [ -d "$src" ]; then
            git -C "$src" worktree remove --force "$wt" 2>/dev/null || rm -rf "$wt"
        else
            rm -rf "$wt"
        fi
    done < <(workvm_host_card_olie_repo_bases)

    rm -rf "${dir}/worktree" "${dir}/vendor"
}

workvm_host_card_remove_api_isolation() {
    workvm_host_card_remove_olie_isolation "$@"
}

workvm_host_card_normalize_code() {
    # DOP-1165 → dop-1165
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed -E 's/-+/-/g; s/^-//; s/-$//'
}

workvm_host_card_id() {
    local project="$1"
    local code="$2"
    local norm
    norm="$(workvm_host_card_normalize_code "$code")"
    printf '%s-%s\n' "$project" "$norm"
}

workvm_host_card_dir() {
    local project="$1"
    local id="$2"
    printf '%s/%s/%s\n' "$(workvm_host_card_root)" "$project" "$id"
}

workvm_host_card_meta_path() {
    printf '%s/meta.json\n' "$(workvm_host_card_dir "$1" "$2")"
}

workvm_host_card_port_base() {
    # Same formula as workvm_sandbox_port_base (stable 20000–29900).
    local id="$1"
    local hash
    hash=$(printf '%s' "$id" | cksum | awk '{ print $1 }')
    printf '%s\n' $((20000 + hash % 100 * 100))
}

workvm_host_card_project_ok() {
    case "$1" in
        olie|locav|televisao|opbed) return 0 ;;
        *) return 1 ;;
    esac
}

workvm_host_card_workspace_src() {
    local project="$1"
    printf '%s/%s/workspace.code-workspace\n' "$(workvm_host_card_meta_repo)" "$project"
}

workvm_host_card_write_workspace() {
    local project="$1"
    local id="$2"
    local code="${3:-$id}"
    local src project_dir dest
    src="$(workvm_host_card_workspace_src "$project")"
    if [ ! -f "$src" ]; then
        workvm_host_card_log "workspace fonte ausente: $src"
        return 1
    fi
    project_dir="$(dirname "$src")"
    dest="${project_dir}/${id}.code-workspace"

    # Olie: stub só se o arquivo ainda não existe. Nunca zerar folders num
    # resume — o Cursor hot-reloada o stub vazio com a janela aberta e o
    # bind_workspace_worktree (depois do hook) preenche o disco sem a UI
    # recarregar → Explorer/SCM vazios. Bind é a única escrita de folders.
    if [ "$project" = "olie" ]; then
        WORKVM_HC_DEST="$dest" python3 <<'PY'
import json, os
from pathlib import Path
dest = Path(os.environ["WORKVM_HC_DEST"])
if not dest.is_file():
    raw = {
        "folders": [],
        "settings": {
            "git.detectWorktrees": False,
            "git.autoRepositoryDetection": False,
        },
    }
    dest.write_text(json.dumps(raw, indent=2) + "\n", encoding="utf-8")
PY
        printf '%s\n' "$dest"
        return 0
    fi

    # Outros projetos: paths relative; sem meta-repo `..` (foco / SCM).
    WORKVM_HC_SRC="$src" WORKVM_HC_DEST="$dest" \
        WORKVM_HC_PROJECT_DIR="$project_dir" WORKVM_HC_CODE="$code" \
        WORKVM_HC_PROJECT="$project" python3 <<'PY'
import json, os
from pathlib import Path
src = Path(os.environ["WORKVM_HC_SRC"])
dest = Path(os.environ["WORKVM_HC_DEST"])
project_dir = Path(os.environ["WORKVM_HC_PROJECT_DIR"])
raw = json.loads(src.read_text(encoding="utf-8"))
clones = []
for ent in raw.get("folders", []):
    rel = ent.get("path") or ""
    name = ent.get("name") or rel
    if not rel or rel == ".":
        continue
    if rel in ("..", "../"):
        continue
    target = (project_dir / rel).resolve()
    if not target.exists():
        continue
    clones.append({"name": name, "path": rel})
prompts = project_dir / "prompts"
if prompts.is_dir():
    clones.append({"name": "prompts", "path": "prompts"})
raw["folders"] = clones
raw.setdefault("settings", {})
text = json.dumps(raw, indent=2) + "\n"
if dest.is_file() and dest.read_text(encoding="utf-8") == text:
    pass
else:
    dest.write_text(text, encoding="utf-8")
PY
    printf '%s\n' "$dest"
}

# Rule alwaysApply no meta/e2e do card: specs vão no worktree, não em ~/git/olie/olie-e2e
# (fora do workspace → pedido de permissão). Arquivo local + exclude; sem commit.
workvm_host_card_write_olie_e2e_path_rule() {
    local dir="$1"
    local meta_wt e2e_wt rule_rel rule_body dest parent exclude

    meta_wt="${dir}/worktree/git"
    e2e_wt="${meta_wt}/olie/olie-e2e"
    rule_rel=".cursor/rules/host-card-e2e-path.mdc"
    rule_body="$(cat <<'EOF'
---
description: Host-card — write private Playwright under workspace olie-e2e, not ~/git/olie/olie-e2e
alwaysApply: true
---

# Host-card: olie-e2e path

This window is a **host-card** workspace. The private Playwright suite is the
workspace folder named **`olie-e2e`** (this card’s meta worktree), not
`~/git/olie/olie-e2e`.

- Create/update specs only under that `olie-e2e` folder (e.g. `tests/features/…`).
- Do **not** write to `~/git/olie/olie-e2e` or `/home/**/git/olie/olie-e2e` —
  those paths are outside this workspace and trigger permission prompts.
- When a prompt says `~/git/olie/olie-e2e`, resolve it to this workspace
  `olie-e2e` folder instead (**Private E2E suites** / path resolution in
  `workflow-policy.md`).
EOF
)"

    for parent in "$e2e_wt" "$meta_wt"; do
        [ -d "$parent" ] || continue
        dest="${parent}/${rule_rel}"
        mkdir -p "$(dirname "$dest")"
        if [ ! -f "$dest" ] || [ "$(cat "$dest")" != "$rule_body" ]; then
            printf '%s\n' "$rule_body" >"$dest"
        fi
        exclude="${parent}/.git/info/exclude"
        if [ -f "${parent}/.git" ]; then
            # worktree: .git is a file → info/exclude lives in the main repo; use
            # the worktree's git dir from `git rev-parse --git-dir`.
            exclude="$(git -C "$parent" rev-parse --git-dir 2>/dev/null)/info/exclude"
        fi
        if [ -n "$exclude" ] && [ -d "$(dirname "$exclude")" ]; then
            mkdir -p "$(dirname "$exclude")"
            if [ ! -f "$exclude" ] || ! grep -qxF "$rule_rel" "$exclude" 2>/dev/null; then
                printf '%s\n' "$rule_rel" >>"$exclude"
            fi
        fi
    done
    workvm_host_card_log "rule host-card-e2e-path → worktree olie-e2e/meta"
}

# Olie: .code-workspace = só worktrees do card (CLONE_REPOS + meta + e2e).
# Sem clones shared e sem pasta api-main (shared).
workvm_host_card_bind_workspace_worktree() {
    local project="$1"
    local workspace="$2"
    local dir="$3"
    local wt_root

    [ "$project" = "olie" ] || return 0
    [ -f "$workspace" ] || return 0
    wt_root="${dir}/worktree"
    [ -d "$wt_root" ] || return 0

    WORKVM_HC_WS="$workspace" WORKVM_HC_WT_ROOT="$wt_root" python3 <<'PY'
import json, os
from pathlib import Path
ws = Path(os.environ["WORKVM_HC_WS"])
root = Path(os.environ["WORKVM_HC_WT_ROOT"]).resolve()
# Ordem estável: produto primeiro; meta-repo por último (não roubar o foco).
order = [
    "api-main",
    "olie-fronts",
    "backoffice",
    "landing",
    "docker-workspace",
    "websocket",
    "docs",
]
folders = []
seen = set()
for name in order:
    p = root / name
    if p.is_dir() and ((p / ".git").exists()):
        folders.append({"name": name, "path": str(p)})
        seen.add(name)
e2e = root / "git" / "olie" / "olie-e2e"
if e2e.is_dir():
    folders.append({"name": "olie-e2e", "path": str(e2e)})
meta = root / "git"
if meta.is_dir() and ((meta / ".git").exists()):
    folders.append({"name": "git", "path": str(meta)})
# Qualquer outro worktree sob root/ (futuro).
for p in sorted(root.iterdir()):
    if not p.is_dir() or p.name in seen or p.name == "git":
        continue
    if (p / ".git").exists():
        folders.append({"name": p.name, "path": str(p)})
raw = {}
if ws.is_file():
    try:
        raw = json.loads(ws.read_text(encoding="utf-8"))
    except Exception:
        raw = {}
raw["folders"] = folders
settings = raw.setdefault("settings", {})
settings["git.detectWorktrees"] = False
settings["git.autoRepositoryDetection"] = False
settings["git.ignoredRepositories"] = []
settings.pop("git.repositoryScanIgnoredFolders", None)
text = json.dumps(raw, indent=2) + "\n"
old = ws.read_text(encoding="utf-8") if ws.is_file() else None
if old == text:
    print(f"workvm-host-card: workspace já é só worktrees em {root}", file=__import__("sys").stderr, flush=True)
else:
    ws.write_text(text, encoding="utf-8")
    print(f"workvm-host-card: workspace → {len(folders)} worktrees em {root}", file=__import__("sys").stderr, flush=True)
PY
}

# Garante que o worktree api-main aparece no Source Control.
# Problema: ao trocar a pasta do clone compartilhado pelo worktree, o Cursor
# mantinha scm:view:visibleRepositories sem o índice 0 (worktree) — Explorer
# listava a pasta, SCM não. Chamar com a janela do card fechada (senão o WAL
# do state.vscdb pode ignorar o write).
workvm_host_card_ensure_scm_repos_visible() {
    local workspace="${1:-}"
    local wt_api="${2:-}"
    local storage

    [ -n "$workspace" ] || return 0
    storage="${XDG_CONFIG_HOME:-$HOME/.config}/Cursor/User/workspaceStorage"
    [ -d "$storage" ] || return 0
    workspace="$(realpath -m "$workspace" 2>/dev/null || echo "$workspace")"
    [ -n "$wt_api" ] && wt_api="$(realpath -m "$wt_api" 2>/dev/null || echo "$wt_api")"

    WORKVM_HC_WS="$workspace" WORKVM_HC_WT_API="${wt_api:-}" python3 - "$storage" <<'PY'
import json, os, sqlite3, sys
from pathlib import Path

root = Path(sys.argv[1])
ws = Path(os.environ["WORKVM_HC_WS"]).resolve()
wt = (os.environ.get("WORKVM_HC_WT_API") or "").strip()
ws_uri = "file://" + str(ws)
wt_uri = ("file://" + wt) if wt else ""
want_key = f"git:Git:{wt_uri}" if wt_uri else ""

def find_storage():
    for d in root.iterdir():
        if not d.is_dir():
            continue
        for name in ("meta.json", "workspace.json"):
            p = d / name
            if not p.is_file():
                continue
            try:
                data = json.loads(p.read_text(encoding="utf-8"))
            except Exception:
                continue
            conf = data.get("configuration") or data.get("workspace") or ""
            if conf.rstrip("/") == ws_uri.rstrip("/"):
                return d
    return None

d = find_storage()
if d is None:
    sys.exit(0)
db = d / "state.vscdb"
if not db.is_file():
    sys.exit(0)

con = sqlite3.connect(str(db), timeout=5)
cur = con.cursor()
# Sem isto o WAL da sessão anterior (isHidden=true) sobrescreve o write no reopen.
try:
    cur.execute("PRAGMA wal_checkpoint(TRUNCATE)")
except Exception:
    pass
changed = False
row = cur.execute(
    "SELECT value FROM ItemTable WHERE key = ?",
    ("scm:view:visibleRepositories",),
).fetchone()
if row:
    try:
        data = json.loads(row[0])
    except Exception:
        data = None
    if isinstance(data, dict):
        all_repos = list(data.get("all") or [])
        # Tirar o clone compartilhado ~/git/olie/api-main (segundo "api-main").
        shared_suffix = "/olie/api-main"
        all_repos = [
            r
            for r in all_repos
            if not (
                r.endswith(shared_suffix)
                or r.endswith(shared_suffix + "/")
            )
            or (want_key and r == want_key)
        ]
        if want_key and want_key not in all_repos:
            all_repos.insert(0, want_key)
        # Mostrar todos os restantes — o bug era o worktree fora de visible.
        visible = list(range(len(all_repos)))
        new = {
            "all": all_repos,
            "sortKey": data.get("sortKey") or "discoveryTime",
            "visible": visible,
        }
        if new != data:
            cur.execute(
                "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)",
                ("scm:view:visibleRepositories", json.dumps(new, separators=(",", ":"))),
            )
            changed = True
else:
    if want_key:
        new = {
            "all": [want_key],
            "sortKey": "discoveryTime",
            "visible": [0],
        }
        cur.execute(
            "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)",
            ("scm:view:visibleRepositories", json.dumps(new, separators=(",", ":"))),
        )
        changed = True

# Painel SCM vazio: após close/reopen o Cursor grava workbench.scm* com
# isHidden=true. Apagar o state faz o default (views visíveis); só setar
# isHidden=false era revertido no startup.
cur.execute(
    "DELETE FROM ItemTable WHERE key IN (?, ?, ?, ?)",
    (
        "workbench.scm.views.state",
        "workbench.view.scm.numberOfVisibleViews",
        "scm.viewState2",
        "workbench.panel.hidden",
    ),
)
cur.execute(
    "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)",
    ("workbench.sidebar.activeviewletid", "workbench.view.scm"),
)
cur.execute(
    "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)",
    ("workbench.sideBar.hidden", "false"),
)
changed = True

if changed:
    con.commit()
    try:
        cur.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    except Exception:
        pass
    print(
        f"workvm-host-card: SCM visible + views unhide → worktree api-main ({d.name})",
        file=sys.stderr,
        flush=True,
    )
con.close()
PY
}

workvm_host_card_meta_write() {
    local project="$1"
    local code="$2"
    local id="$3"
    local dir="$4"
    local port_base="$5"
    local workspace="$6"
    local compose_project="$7"
    local now
    now="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    mkdir -p "$dir"
    WORKVM_HC_PROJECT="$project" WORKVM_HC_CODE="$code" WORKVM_HC_ID="$id" \
        WORKVM_HC_PORT_BASE="$port_base" WORKVM_HC_WORKSPACE="$workspace" \
        WORKVM_HC_COMPOSE="$compose_project" WORKVM_HC_NOW="$now" \
        python3 - "$dir/meta.json" <<'PY'
import json, os, sys
path = sys.argv[1]
meta = {
    "project": os.environ["WORKVM_HC_PROJECT"],
    "code": os.environ["WORKVM_HC_CODE"],
    "id": os.environ["WORKVM_HC_ID"],
    "port_base": int(os.environ["WORKVM_HC_PORT_BASE"]),
    "workspace": os.environ["WORKVM_HC_WORKSPACE"],
    "compose_project": os.environ["WORKVM_HC_COMPOSE"],
    "created_at": os.environ["WORKVM_HC_NOW"],
    "updated_at": os.environ["WORKVM_HC_NOW"],
}
if os.path.isfile(path):
    with open(path, encoding="utf-8") as f:
        old = json.load(f)
    meta["created_at"] = old.get("created_at", meta["created_at"])
with open(path, "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
PY
}

workvm_host_card_run_hook() {
    local project="$1"
    local phase="$2" # ensure|destroy
    local id="$3"
    local dir="$4"
    local hook
    hook="$(workvm_host_card_meta_repo)/${project}/sandbox/host-card-${phase}.sh"
    if [ -f "$hook" ]; then
        # shellcheck source=/dev/null
        source "$hook"
        "workvm_host_card_${phase}_hook" "$id" "$dir" || return $?
    fi
    return 0
}

# Aponta Boost MCP para o app do card (mcp.json user-level é compartilhado).
workvm_host_card_set_boost_container() {
    local id="$1"
    local pointer="${XDG_CONFIG_HOME:-$HOME/.config}/workvm/host-card-boost-container"
    mkdir -p "$(dirname "$pointer")"
    printf 'hc-%s-app-1\n' "$id" >"$pointer"
}

# Aponta Playwright MCP para o olie-e2e do card (mesmo mcp.json compartilhado).
workvm_host_card_set_e2e_container() {
    local id="$1"
    local pointer="${XDG_CONFIG_HOME:-$HOME/.config}/workvm/host-card-e2e-container"
    mkdir -p "$(dirname "$pointer")"
    printf 'hc-%s-olie-e2e-1\n' "$id" >"$pointer"
}

# MCP no jarvis (igual ao login da WorkVM): olie-flow-ai + Boost + playwright.
# Problema: host-card não roda project-start — sem overlay/`mcp.json` + proxy
# o colleague review para e o Laravel Boost não aparece.
workvm_host_card_ensure_olie_mcp() {
    local project="$1"
    local id="${2:-}"
    local meta_repo conf project_dir dest
    meta_repo="$(workvm_host_card_meta_repo)"
    conf="${meta_repo}/${project}/project.conf"
    project_dir="${meta_repo}/${project}"
    dest="${HOME}/.cursor/mcp.json"

    case "$project" in
        olie|locav|televisao) ;;
        *) return 0 ;;
    esac
    if [ ! -f "$conf" ]; then
        return 0
    fi

    # shellcheck source=/dev/null
    source "${meta_repo}/lib/common.sh"
    # shellcheck source=/dev/null
    source "$conf"
    if [ "${MCP:-}" != "olie" ]; then
        return 0
    fi

    export GIT_ROOT="$(workvm_host_card_git_root)"
    # Overlay traz api-main/.cursor/mcp.json (laravel-boost → olie-api-main).
    workvm_host_card_log "overlay → clones (MCP Boost/Playwright)"
    workvm_apply_files "$project_dir" "$project" || true

    workvm_host_card_log "MCP → ~/.cursor/mcp.json + proxy :47331"
    workvm_apply_cursor_permissions "$meta_repo" || true
    # Resume + agent sandbox: MCP merge may fail writing ~/.cursor while olie-flow-ai
    # already works in the chat. Soft-fail when dest already has servers.
    if ! workvm_apply_mcp "$meta_repo" "olie" "$project_dir"; then
        if [ -f "$dest" ] && python3 - "$dest" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    raise SystemExit(1)
servers = data.get("mcpServers") or {}
raise SystemExit(0 if servers else 1)
PY
        then
            workvm_host_card_log "aviso: MCP merge falhou (sandbox?); mantendo $dest existente"
        else
            return 1
        fi
    fi
    if ! workvm_sync_olie_mcp_proxy "$meta_repo"; then
        if ss -ltn 2>/dev/null | grep -q ':47331'; then
            workvm_host_card_log "aviso: proxy MCP sync falhou; :47331 já escuta — seguindo"
        else
            return 1
        fi
    fi

    # WorkVM: Boost→olie-api-main, Playwright→olie-e2e. Host-card: wrappers.
    if [ "$project" = "olie" ] && [ -f "$dest" ]; then
        WORKVM_HC_MCP_DEST="$dest" \
            WORKVM_HC_BOOST_WRAPPER="${meta_repo}/bin/workvm-host-card-boost-mcp.sh" \
            WORKVM_HC_PW_WRAPPER="${meta_repo}/bin/workvm-host-card-playwright-mcp.sh" \
            python3 <<'PY'
import json, os
from pathlib import Path
dest = Path(os.environ["WORKVM_HC_MCP_DEST"])
boost_w = os.environ["WORKVM_HC_BOOST_WRAPPER"]
pw_w = os.environ["WORKVM_HC_PW_WRAPPER"]
data = json.loads(dest.read_text(encoding="utf-8"))
servers = data.setdefault("mcpServers", {})
boost = servers.get("laravel-boost")
if isinstance(boost, dict):
    boost["command"] = boost_w
    boost["args"] = []
    servers["laravel-boost"] = boost
pw = servers.get("playwright")
if isinstance(pw, dict):
    # Container olie-e2e do card (pointer); wrapper = workvm-playwright-mcp
    pw["command"] = pw_w
    pw["args"] = []
    servers["playwright"] = pw
dest.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
        if [ -n "$id" ]; then
            workvm_host_card_set_boost_container "$id"
            workvm_host_card_set_e2e_container "$id"
            workvm_host_card_log "laravel-boost → hc-${id}-app-1"
            workvm_host_card_log "playwright → hc-${id}-olie-e2e-1"
        fi
    fi
}

# Clone/pull CLONE_REPOS do project.conf (mesmo conjunto da WorkVM).
workvm_host_card_ensure_clones() {
    local project="$1"
    local meta_repo conf
    meta_repo="$(workvm_host_card_meta_repo)"
    conf="${meta_repo}/${project}/project.conf"
    if [ ! -f "$conf" ]; then
        workvm_host_card_log "project.conf ausente: $conf (pula clones)"
        return 0
    fi
    # shellcheck source=/dev/null
    source "${meta_repo}/lib/common.sh"
    # shellcheck source=/dev/null
    source "$conf"
    if ! declare -p CLONE_REPOS >/dev/null 2>&1 || [ "${#CLONE_REPOS[@]}" -eq 0 ]; then
        return 0
    fi
    export GIT_ROOT="$(workvm_host_card_git_root)"
    workvm_host_card_log "CLONE_REPOS ($project) — clone/pull como na WorkVM"
    workvm_clone_project_repos "${CLONE_REPOS[@]}"
}

# open PROJECT CODE: ensure + foca/abre o .code-workspace do card (não o clone ~/git/olie/api-main).
workvm_host_card_open() {
    local project="" code=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --project) project="$2"; shift 2 ;;
            --code) code="$2"; shift 2 ;;
            *)
                workvm_host_card_log "uso: open --project <…> --code <CODE>"
                return 2
                ;;
        esac
    done
    [ -n "$project" ] && [ -n "$code" ] || {
        workvm_host_card_log "uso: open --project <…> --code <CODE>"
        return 2
    }
    # ensure sem Cursor: fecha → conserta SCM visible → abre uma vez (evita 2× --new-window).
    WORKVM_HOST_CARD_OPEN_CURSOR=0 workvm_host_card_ensure --project "$project" --code "$code" || return $?
    local id workspace wt_api dir
    id="$(workvm_host_card_id "$project" "$code")"
    dir="$(workvm_host_card_dir "$project" "$id")"
    # Belt: ensure/olie já synca via add_meta; open em qualquer projeto com worktree/git.
    workvm_host_card_sync_meta_worktree "$dir" || true
    workspace="$(python3 -c "import json;print(json.load(open('$(workvm_host_card_meta_path "$project" "$id")')).get('workspace') or '')" 2>/dev/null || true)"
    wt_api="$(python3 -c "import json;print(json.load(open('$(workvm_host_card_meta_path "$project" "$id")')).get('api_worktree') or '')" 2>/dev/null || true)"
    if [ -n "$workspace" ] && [ -f "$workspace" ]; then
        # shellcheck source=session.sh
        source "$(workvm_host_card_meta_repo)/lib/session.sh"
        workvm_close_cursor_workspace "$workspace" || true
        # Espera a janela sumir — senão o WAL do Cursor vivo anula o unhide do SCM.
        local _i
        for _i in 1 2 3 4 5 6 7 8 9 10; do
            if ! workvm_cursor_workspace_open "$workspace"; then
                break
            fi
            workvm_close_cursor_workspace "$workspace" || true
            sleep 0.3
        done
        workvm_host_card_ensure_scm_repos_visible "$workspace" "${wt_api:+$wt_api/api-main}"
        if [ "$project" = "olie" ]; then
            workvm_host_card_set_boost_container "$id"
            workvm_host_card_set_e2e_container "$id" 2>/dev/null || true
        fi
        workvm_open_cursor "$workspace" --new-window || true
        printf 'workspace=%s\n' "$workspace"
        printf 'api_worktree=%s\n' "${wt_api}"
    fi
}

workvm_host_card_ensure() {
    local project="" code=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --project) project="$2"; shift 2 ;;
            --code) code="$2"; shift 2 ;;
            *)
                workvm_host_card_log "flag desconhecida: $1"
                return 2
                ;;
        esac
    done
    if [ -z "$project" ] || [ -z "$code" ]; then
        workvm_host_card_log "uso: ensure --project <olie|locav|televisao|opbed> --code <CODE>"
        return 2
    fi
    if ! workvm_host_card_project_ok "$project"; then
        workvm_host_card_log "projeto inválido: $project"
        return 2
    fi

    local id dir port_base workspace compose_project resumed=0
    id="$(workvm_host_card_id "$project" "$code")"
    dir="$(workvm_host_card_dir "$project" "$id")"
    compose_project="hc-${id}"
    mkdir -p "$(workvm_host_card_root)/${project}"

    if [ -f "$(workvm_host_card_meta_path "$project" "$id")" ]; then
        resumed=1
        port_base="$(python3 -c "import json;print(json.load(open('$(workvm_host_card_meta_path "$project" "$id")'))['port_base'])")"
        workvm_host_card_log "resume $id (port_base=$port_base)"
    else
        port_base="$(workvm_host_card_port_base "$id")"
        workvm_host_card_log "create $id (port_base=$port_base)"
    fi

    # Same clones as WorkVM project-setup (olie-fronts, backoffice, …).
    # Clone/pull warnings are non-fatal for resume (agent sandbox often cannot FETCH_HEAD).
    if ! workvm_host_card_ensure_clones "$project"; then
        if [ "$resumed" = "1" ]; then
            workvm_host_card_log "aviso: CLONE_REPOS falhou no resume — seguindo com worktree do card"
        else
            return 1
        fi
    fi
    # Antes do Cursor: MCP + proxy (VM fazia isso no project-start/login).
    if ! workvm_host_card_ensure_olie_mcp "$project" "$id"; then
        if [ "$resumed" = "1" ]; then
            workvm_host_card_log "aviso: MCP/proxy falhou no resume — seguindo (chat pode já ter olie-flow-ai)"
        else
            return 1
        fi
    fi
    workspace="$(workvm_host_card_write_workspace "$project" "$id" "$code")" || return 1

    workvm_host_card_meta_write "$project" "$code" "$id" "$dir" "$port_base" "$workspace" "$compose_project" || return 1
    # Compose/hook needs docker.sock. Agent sandbox hides it → clear signal for bridge.
    if ! workvm_host_card_run_hook "$project" ensure "$id" "$dir"; then
        if [ ! -S /var/run/docker.sock ] && pgrep -x dockerd >/dev/null 2>&1; then
            workvm_host_card_log "WORKVM_AGENT_SANDBOX=1 docker.sock oculto (dockerd vivo) — use required_permissions all ou workvm-host-card-agent-ensure"
            return 75
        fi
        return 1
    fi

    # Re-read compose_project after hook (olie/televisao may rewrite it).
    if [ -f "$(workvm_host_card_meta_path "$project" "$id")" ]; then
        compose_project="$(python3 -c "import json;print(json.load(open('$(workvm_host_card_meta_path "$project" "$id")')).get('compose_project','$compose_project'))")"
    fi

    # Depois do worktree: api-main no .code-workspace = path do card (não o clone).
    if [ "$project" = "olie" ]; then
        workvm_host_card_write_olie_e2e_path_rule "$dir" || true
    fi
    if ! workvm_host_card_bind_workspace_worktree "$project" "$workspace" "$dir"; then
        workvm_host_card_log "bind_workspace_worktree falhou (workspace pode ficar sem folders)"
    fi

    if [ "${WORKVM_HOST_CARD_OPEN_CURSOR:-1}" != "0" ] && [ -f "$workspace" ]; then
        # shellcheck source=session.sh
        source "$(workvm_host_card_meta_repo)/lib/session.sh"
        # Boost user-level: aponta para o card desta janela antes de abrir.
        if [ "$project" = "olie" ]; then
            workvm_host_card_set_boost_container "$id"
            workvm_host_card_set_e2e_container "$id" 2>/dev/null || true
        fi
        # Janela já aberta (colleague review / resume no próprio card): só foca.
        # Fechar+reabrir aqui derrubava o chat no meio do ensure (hack SCM).
        # O close+SCM fica no `workvm-host-card open`, quando o usuário pede.
        # Exceção: folders[] no disco (bug antigo / bind atrasado) — reabre senão
        # Explorer/SCM ficam vazios até o próximo `open`.
        local _folders_n=0
        _folders_n="$(python3 -c "import json;print(len(json.load(open('$workspace')).get('folders') or []))" 2>/dev/null || echo 0)"
        if workvm_cursor_workspace_open "$workspace" && [ "${_folders_n:-0}" -gt 0 ]; then
            workvm_focus_cursor_workspace "$workspace" || true
            workvm_host_card_log "Cursor já aberto para $(basename "$workspace") — focus (sem close)"
        else
            workvm_close_cursor_workspace "$workspace" || true
            workvm_host_card_ensure_scm_repos_visible "$workspace" "${dir}/worktree/api-main"
            # --new-window: two cards share front clones; without -n Cursor reuses one window.
            workvm_open_cursor "$workspace" --new-window \
                || workvm_host_card_log "Cursor não abriu (sem sessão gráfica?); workspace=$workspace"
        fi
    fi

    local dns_slug api_dns front_dns
    dns_slug="$(python3 -c "import json;print(json.load(open('$(workvm_host_card_meta_path "$project" "$id")')).get('dns_slug') or '')" 2>/dev/null || true)"
    if [ -z "$dns_slug" ]; then
        # shellcheck source=host-card-proxy.sh
        source "$(workvm_host_card_meta_repo)/lib/host-card-proxy.sh"
        dns_slug="$(workvm_host_card_dns_slug "$code")"
    fi
    api_dns="http://api.${dns_slug}.olie.localhost"
    front_dns="http://devframe.${dns_slug}.olie.localhost"

    printf 'id=%s\n' "$id"
    printf 'project=%s\n' "$project"
    printf 'code=%s\n' "$code"
    printf 'resumed=%s\n' "$resumed"
    printf 'port_base=%s\n' "$port_base"
    printf 'dns_slug=%s\n' "$dns_slug"
    printf 'api_url=http://127.0.0.1:%s\n' "$port_base"
    printf 'front_url=http://127.0.0.1:%s\n' "$((port_base + 1))"
    printf 'api_dns=%s\n' "$api_dns"
    printf 'front_dns=%s\n' "$front_dns"
    printf 'workspace=%s\n' "$workspace"
    printf 'compose_project=%s\n' "$compose_project"
    printf 'state_dir=%s\n' "$dir"
}

workvm_host_card_status() {
    local project="" code=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --project) project="$2"; shift 2 ;;
            --code) code="$2"; shift 2 ;;
            *)
                workvm_host_card_log "flag desconhecida: $1"
                return 2
                ;;
        esac
    done
    if [ -z "$project" ] || [ -z "$code" ]; then
        workvm_host_card_log "uso: status --project <…> --code <CODE>"
        return 2
    fi
    local id meta
    id="$(workvm_host_card_id "$project" "$code")"
    meta="$(workvm_host_card_meta_path "$project" "$id")"
    if [ ! -f "$meta" ]; then
        workvm_host_card_log "ausente: $id"
        return 1
    fi
    cat "$meta"
}

workvm_host_card_destroy() {
    local project="" code=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --project) project="$2"; shift 2 ;;
            --code) code="$2"; shift 2 ;;
            *)
                workvm_host_card_log "flag desconhecida: $1"
                return 2
                ;;
        esac
    done
    if [ -z "$project" ] || [ -z "$code" ]; then
        workvm_host_card_log "uso: destroy --project <…> --code <CODE>"
        return 2
    fi
    local id dir meta workspace compose_project
    id="$(workvm_host_card_id "$project" "$code")"
    dir="$(workvm_host_card_dir "$project" "$id")"
    meta="$(workvm_host_card_meta_path "$project" "$id")"
    if [ ! -f "$meta" ]; then
        workvm_host_card_log "já ausente: $id"
        return 0
    fi
    workspace="$(python3 -c "import json;print(json.load(open('$meta')).get('workspace',''))")"
    compose_project="$(python3 -c "import json;print(json.load(open('$meta')).get('compose_project',''))")"

    workvm_host_card_run_hook "$project" destroy "$id" "$dir" || true

    if [ -n "$compose_project" ] && command -v docker >/dev/null 2>&1; then
        # Best-effort: no Docker socket / empty project must not fail destroy.
        docker ps -aq --filter "label=com.docker.compose.project=${compose_project}" 2>/dev/null \
            | xargs -r docker rm -f >/dev/null 2>&1 || true
        docker network ls --format '{{.Name}}' 2>/dev/null \
            | grep -E "^${compose_project}" \
            | while read -r net; do docker network rm "$net" >/dev/null 2>&1 || true; done || true
    fi

    if [ -n "$workspace" ] && [ -f "$workspace" ]; then
        rm -f "$workspace"
    fi
    rm -rf "$dir"
    # Se o worktree remove falhou no meio, sobra entrada em .git/worktrees.
    if [ "$project" = "olie" ] && [ -d "$(workvm_host_card_git_root)/olie/api-main/.git" ]; then
        git -C "$(workvm_host_card_git_root)/olie/api-main" worktree prune 2>/dev/null || true
    fi
    workvm_host_card_log "destroyed $id"

    # Pointers MCP não podem apontar para container já apagado.
    workvm_host_card_clear_mcp_pointers "$id"

    # Open Recent do Cursor ainda listava o .code-workspace apagado.
    if [ -n "$workspace" ]; then
        workvm_host_card_forget_cursor_workspace "$workspace"
    fi

    # Drop DNS routes for this card (meta already gone).
    # shellcheck source=host-card-proxy.sh
    source "$(workvm_host_card_meta_repo)/lib/host-card-proxy.sh"
    workvm_host_card_proxy_reload || true

    # Colleague review deixa api-main/olie-fronts na branch do card; volta à base.
    workvm_host_card_restore_clone_bases "$project" "$id" || true

    # Não fecha a janela Cursor: finish/finalize roda dentro dela — close no
    # meio do prompt dispara o diálogo “prompts running”. O humano fecha à mão.
    workvm_host_card_log "teardown ok ($id) — pode fechar manualmente a janela Cursor deste card"
    printf 'close_cursor=manual\n'
    printf 'hint=Pode fechar a janela Cursor deste card agora (não fechamos automaticamente).\n'
}

# Volta clones compartilhados à branch do project.conf (ex. develop).
# Problema: finish card limpava o host-card, mas api-main/olie-fronts ficavam
# na feature do review e o próximo card herdava o checkout errado.
workvm_host_card_restore_clone_bases() {
    local project="$1"
    local id="${2:-}"
    local meta_repo conf git_root line url rel branch path cur
    meta_repo="$(workvm_host_card_meta_repo)"
    conf="${meta_repo}/${project}/project.conf"
    git_root="$(workvm_host_card_git_root)"
    [ -f "$conf" ] || return 0

    # shellcheck source=/dev/null
    source "$conf"
    if ! declare -p CLONE_REPOS >/dev/null 2>&1 || [ "${#CLONE_REPOS[@]}" -eq 0 ]; then
        return 0
    fi

    for line in "${CLONE_REPOS[@]}"; do
        # "<url> <relative-path> <branch>"
        url=""
        rel=""
        branch=""
        # shellcheck disable=SC2086
        set -- $line
        url="${1:-}"
        rel="${2:-}"
        branch="${3:-}"
        [ -n "$rel" ] && [ -n "$branch" ] || continue
        # olie-docs-hands-off: nunca checkout no clone docs.
        case "$rel" in
            */docs|olie/docs) continue ;;
        esac
        path="${git_root}/${rel}"
        if [ ! -d "${path}/.git" ] && [ ! -f "${path}/.git" ]; then
            continue
        fi
        cur="$(git -C "$path" branch --show-current 2>/dev/null || true)"
        if [ "$cur" = "$branch" ]; then
            workvm_host_card_log "clone já em $branch: $rel"
            continue
        fi
        if ! git -C "$path" diff --quiet 2>/dev/null \
            || ! git -C "$path" diff --cached --quiet 2>/dev/null \
            || [ -n "$(git -C "$path" status --porcelain -uall 2>/dev/null | head -1)" ]; then
            workvm_host_card_log "stash local em $rel (antes de $branch) [$id]"
            git -C "$path" stash push -u -m "workvm-host-card destroy ${id:-?} → ${branch}" >/dev/null 2>&1 \
                || workvm_host_card_log "stash falhou em $rel — tentando checkout mesmo assim"
        fi
        workvm_host_card_log "checkout $branch ← $rel (era ${cur:-detached})"
        if git -C "$path" show-ref --verify --quiet "refs/heads/${branch}"; then
            git -C "$path" -c core.hooksPath=/dev/null checkout "$branch" >/dev/null 2>&1 \
                || workvm_host_card_log "checkout $branch falhou: $rel"
        elif git -C "$path" show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
            git -C "$path" -c core.hooksPath=/dev/null checkout -B "$branch" "origin/${branch}" >/dev/null 2>&1 \
                || workvm_host_card_log "checkout origin/$branch falhou: $rel"
        else
            workvm_host_card_log "branch $branch ausente em $rel"
        fi
    done
}

# Limpa pointers Boost/Playwright se ainda apontam para este card.
workvm_host_card_clear_mcp_pointers() {
    local id="$1"
    local cfg boost e2e
    cfg="${XDG_CONFIG_HOME:-$HOME/.config}/workvm"
    boost="${cfg}/host-card-boost-container"
    e2e="${cfg}/host-card-e2e-container"
    if [ -f "$boost" ] && grep -q "hc-${id}-app-1" "$boost" 2>/dev/null; then
        rm -f "$boost"
        workvm_host_card_log "pointer boost limpo ($id)"
    fi
    if [ -f "$e2e" ] && grep -q "hc-${id}-olie-e2e-1" "$e2e" 2>/dev/null; then
        rm -f "$e2e"
        workvm_host_card_log "pointer e2e limpo ($id)"
    fi
}

# Remove workspaceStorage do Cursor que ainda referencia o .code-workspace.
# Problema: destroy apagava o arquivo, mas Open Recent / storage mantinha o path.
workvm_host_card_forget_cursor_workspace() {
    local workspace="$1"
    local storage uri
    storage="${XDG_CONFIG_HOME:-$HOME/.config}/Cursor/User/workspaceStorage"
    [ -d "$storage" ] || return 0
    workspace="$(realpath -m "$workspace" 2>/dev/null || echo "$workspace")"
    uri="file://${workspace}"
    WORKVM_HC_WS_URI="$uri" python3 - "$storage" <<'PY'
import json, os, shutil, sys
from pathlib import Path
root = Path(sys.argv[1])
uri = os.environ["WORKVM_HC_WS_URI"]
# also accept trailing variants
want = {uri, uri.rstrip("/")}
for d in root.iterdir():
    if not d.is_dir():
        continue
    meta = d / "workspace.json"
    if not meta.is_file():
        continue
    try:
        data = json.loads(meta.read_text(encoding="utf-8"))
    except Exception:
        continue
    w = data.get("workspace") or data.get("folder") or ""
    if w in want or w.rstrip("/") in want:
        shutil.rmtree(d, ignore_errors=True)
        print(f"workvm-host-card: Cursor workspaceStorage removido ({d.name})", file=sys.stderr)
PY
}

workvm_host_card_list() {
    local root
    root="$(workvm_host_card_root)"
    if [ ! -d "$root" ]; then
        return 0
    fi
    find "$root" -mindepth 3 -maxdepth 3 -name meta.json -print 2>/dev/null \
        | while read -r m; do
            python3 -c "import json;d=json.load(open('$m'));print(d.get('id','?'), d.get('project','?'), d.get('code','?'), d.get('port_base','?'))"
        done
}
