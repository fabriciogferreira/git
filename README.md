# Meta-repo — work VMs

Provisiona VMs de desenvolvimento e amarra cada máquina a um **projeto** (clones, Docker, Cursor, browser).

Documentação para o agente Cursor: [`workvm/.cursor/rules/meta-repo.mdc`](workvm/.cursor/rules/meta-repo.mdc).

## Uso rápido (Arch + Hyprland)

```bash
~/git/arch-vm-setup.sh
# reboot
~/git/arch-project-setup.sh <projeto>
```

Projetos: ver `workvm/projects/*/`.

## Cursor (1 janela, multi-root)

Abrir `workvm/projects/<projeto>/workspace.code-workspace`:

- **workvm** — scripts/docs + rules da VM (`workvm/.cursor`)
- **cada clone** — código + `.cursor` daquele repositório

Não abrir `~/git` inteiro como root (puxa rules nested de `files/` etc.).

## Layout

| Path | Papel |
| --- | --- |
| `workvm/` | Projetos, lib, systemd, scripts host/guest, docs, `.cursor` da VM |
| `files/` | Overlays aplicados nos clones (`files/<projeto>/…`) |
| `.config/` | Overlay → `~/.config` (Hyprland, etc.) |
| `code-profiles/` | Perfis Cursor (`.code-profile`) |
| `arch-vm-setup.sh` / `arch-project-setup.sh` | Bootstrap e bind do projeto (Arch) |
| `vm-setup.sh` / `project-setup.sh` | Legado Omarchy |

Projeto ativo na VM:

- Agente Cursor: `workvm/.cursor/rules/workvm-project.mdc` (gerado no project-setup)
- Runtime: `~/.config/workvm/current`
