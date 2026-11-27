# Host-cards (contrato — aceito)

Programação é **só no jarvis** via `bin/workvm-host-card`. Não há WorkVM / Card VM / libvirt de desenvolvimento.

Detalhe operacional para o agente: `olie/prompts/workflow-policy/host.md` (e espelhos Locav/Televisão). Mapa do meta: `.cursor/rules/layout.mdc`.

## Unidade

| Produto | Id |
| --- | --- |
| Olie, Televisão, Locav | Card (ex. `DOP-1183`) |
| Opbed e similares | Projeto (`--code` = nome do projeto) |

Estado: `~/.local/share/workvm/host-cards/<project>/<id>/` (worktree, compose namespaced, `port_base`).

## CLI

```bash
~/git/bin/workvm-host-card ensure  --project <olie|locav|televisao|…> --code <CODE>
~/git/bin/workvm-host-card open    --project … --code …
~/git/bin/workvm-host-card destroy --project … --code …
```

Shell do agente: `required_permissions: ["all"]` no ensure/destroy (grava `~/.cursor/mcp.json` e estado). Se o footer continuar sandboxed → `agent-ensure` / bridge.

## Destroy

Remove compose do card, redes/volumes desse projeto, worktree/metadados e workspace gerado. **Não** derruba `hc-*-data` compartilhado nem outros cards. No finalize/`finish card`, também `docker compose down` do stack principal do `project.conf` quando aplicável (`workflow-policy/host.md`).

## Sandbox filho

Mutation / Pest exclusive / e2e que escrevem no mesmo DB → `workvm-sandbox` (container) em cima do card. Ver `*/sandbox/ORCHESTRATION.md`.

## Fora de escopo deste arquivo

- Desinstalar libvirt no OS / `virsh undefine` de domains velhas (manual no host).
- Renomear bins `workvm-*` (legado de nome; comportamento é host).
