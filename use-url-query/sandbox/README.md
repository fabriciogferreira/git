# Sandboxes — use-url-query

Ambientes isolados para `bun run test` (Vitest) / coverage sem brigar pelo container do Card.
CLI: `~/git/bin/workvm-sandbox`.

## Uso

```bash
~/git/bin/workvm-sandbox create --name cov-a --project use-url-query --profile tests --from-commit <tip>
~/git/bin/workvm-sandbox job run cov-a --service backend -- bun run test
~/git/bin/workvm-sandbox destroy cov-a
```

Teto padrão: **2**. Override: `WORKVM_SANDBOX_MAX=N`.

Service default do job: `backend` → tag `use-url-query-sandbox-backend:tests`
(Bun + **Node real**; `project.sh` faz o build no `create`). Override:
`HC_BUN_IMAGE=…` (default `use-url-query-sandbox-backend:tests`). Card e
slim compartilham essa imagem Bun+Node (`compose.host.yml` serviço `lib`).

Antes do primeiro sandbox: `bun install` no clone (ou host-card `compose up`).

## O que isola

| Recurso | Como |
| --- | --- |
| Código | worktree sob `~/git/use-url-query/.sandboxes/<id>/` |
| Runtime | bridge `sb-<id>_sb_net` + container bun |
| DB / Redis | **não** — biblioteca pura |

**Proibido** para coverage drain paralelo: `docker exec` no Card — use o sandbox.

## Arquivos

- `compose.slim.yml` + `compose.gui.yml` — sandbox
- `project.sh` — hooks do Manager
- `ORCHESTRATION.md` — exclusive vs compatible + warm pool
- `host-card-ensure.sh` / `host-card-destroy.sh` — Card
- `compose.host.yml` — bun namespaced no host-card
