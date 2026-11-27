# Meta-repo — host jarvis + host-cards

Amarra o **host** a um projeto (clones, Docker, MCP) e sobe **cards** isolados no jarvis (`bin/workvm-host-card`) — sem WorkVM/libvirt para programar.

Documentação para o agente Cursor:

- [`.cursor/rules/`](.cursor/rules/) — por que cada parte existe e como o host opera
- [`host-cards-no-vm.md`](host-cards-no-vm.md) — contrato host-card (já no host)

## Uso rápido

```bash
~/git/project-setup.sh <projeto>   # cria vm.local.conf se faltar; liga workvm.service
```

Projetos: pastas na raiz (`olie/`, `opbed/`, `televisao/`, …).

Cards (Olie/Locav/Televisão):

```bash
~/git/bin/workvm-host-card ensure --project olie --code DOP-….
~/git/bin/workvm-host-card open   --project olie --code DOP-….
```

## Cursor

`project-setup` / `project-start` aplicam patch local nos clones (`alwaysApply`→globs, `AGENTS.md` relocado) com `skip-worktree` — não commitar isso nos repos da empresa. Host-cards abrem um `.code-workspace` por unidade (worktrees sob `~/.local/share/workvm/host-cards/…`).

## Layout

O mapa do porquê de cada pasta está em [`.cursor/rules/layout.mdc`](.cursor/rules/layout.mdc).

Projeto ativo no host:

- Agente Cursor: `.cursor/rules/workvm-project.mdc` (gerado no project-setup)
- Runtime: `~/.config/workvm/current`
