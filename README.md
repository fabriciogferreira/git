# Meta-repo — work VMs

Provisiona VMs de desenvolvimento e amarra cada máquina a um **projeto** (clones, Docker, Cursor, browser).

Documentação para o agente Cursor:

- [`.cursor/rules/`](.cursor/rules/) — por que cada parte existe e como a VM opera

## Uso rápido (Arch + Hyprland)

```bash
~/git/vm-setup.sh   # cria vm.local.conf a partir do .example se ainda não existir
# reboot
~/git/project-setup.sh <projeto>
```

Projetos: ver `projects/*/`.

## Cursor (1 janela, multi-root)

O login abre `projects/<projeto>/workspace.code-workspace`: este meta-repo (`~/git`) e cada clone.

No setup e no `project-start.sh`, `workvm_apply_files` faz patch local nos clones (`alwaysApply`→globs, `AGENTS.md` relocado) com `skip-worktree` — não commitar isso nos repos da empresa.

## Layout

O mapa do porquê de cada pasta está em [`.cursor/rules/layout.mdc`](.cursor/rules/layout.mdc). Não há uma segunda tabela aqui.

Projeto ativo na VM:

- Agente Cursor: `.cursor/rules/workvm-project.mdc` (gerado no project-setup)
- Runtime: `~/.config/workvm/current`
