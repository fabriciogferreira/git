# Sandboxes — fabriciogferreira

Ambientes isolados para `npm run lint` / `build` sem brigar pelo container do Card.
CLI: `~/git/bin/workvm-sandbox`.

## Uso

```bash
~/git/bin/workvm-sandbox create --name lint-a --project fabriciogferreira --profile tests --from-commit <tip>
~/git/bin/workvm-sandbox job run lint-a --service backend -- npm run lint
~/git/bin/workvm-sandbox destroy lint-a
```

Teto padrão: **2**. Service default: `backend` (Node).

## O que isola

| Recurso | Como |
| --- | --- |
| Código | worktree sob `~/git/fabriciogferreira/.sandboxes/<id>/` |
| Runtime | bridge + container Node |
| DB | **não** |

## Arquivos

- `compose.slim.yml` + `compose.gui.yml` — sandbox
- `project.sh` — hooks do Manager
- `ORCHESTRATION.md` — exclusive vs compatible
- `host-card-ensure.sh` / `host-card-destroy.sh` — Card
- `compose.host.yml` — Next namespaced no host-card
