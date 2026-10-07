---
name: sync-git-dotconfig
description: >-
  Keeps the meta-repo overlay ~/git/.config in sync when editing matching
  files under ~/.config (Hyprland, etc.). Use when changing ~/.config/hypr,
  hyprland.lua, hyprpaper, or any path that corresponds to ~/git/.config;
  when applying VM desktop/session config; or when the user mentions
  .config overlay, git.config, or syncing Hyprland config to the repo.
---

# Sync `~/.config` ↔ `~/git/.config`

## Rule

Quando você mexer em alguma config que está / bate com o que está no `~/git/.config`, deve ser atualizado em `~/git/.config`.

## Mapping

| Live (VM) | Fonte versionada (meta-repo) |
| --- | --- |
| `~/.config/<path>` | `~/git/.config/<path>` |

O overlay é aplicado por `vm-setup.sh` (`$GIT_ROOT/.config` → `~/.config`). Editar só o live deixa o repo desatualizado no próximo setup/VM.

## Workflow

1. Antes de editar sob `~/.config/`, checar se existe o mesmo caminho relativo em `~/git/.config/`.
2. Se existir (ou for o caso claro de overlay, ex. `hypr/`), **aplicar a mesma mudança nos dois lados** (preferir editar a fonte em `~/git/.config/` e copiar/sync para `~/.config/`, ou espelhar o diff).
3. Se o arquivo live **não** tiver correspondente em `~/git/.config/` (ex. secrets locais como `environment.d/*.conf` com tokens), **não** versionar o secret — só o live.
4. Não commitar até o usuário pedir.

## Exemplos

- Editar `~/.config/hypr/hyprland.lua` → atualizar também `~/git/.config/hypr/hyprland.lua`.
- Novo arquivo de overlay Hyprland → criar em `~/git/.config/hypr/` e espelhar em `~/.config/hypr/`.
- `~/.config/environment.d/olie-mcp.conf` com token → **não** copiar para o git.
