# Sandboxes — Olie

Ambientes isolados **dentro** da WorkVM do Card (`olie-{code}`), sem clonar
VM por tarefa. Mesma CLI da Televisão: `~/git/bin/workvm-sandbox`.

Orquestração (colleague review, exclusive vs compatible, shard de
mutation): **[ORCHESTRATION.md](./ORCHESTRATION.md)**.

## Uso

```bash
# Na guest do Card (project-setup olie já rodou; imagem olie/api-main existe)
~/git/bin/workvm-sandbox create --name mut-envelope --project olie --profile mutation
~/git/bin/workvm-sandbox create --name tests-a --project olie --profile tests
~/git/bin/workvm-sandbox create --name e2e-c --project olie --profile e2e

# Pest / mutation — NÃO usar docker exec olie-api-main (DB da Card VM)
~/git/bin/workvm-sandbox job run mut-envelope -- \
  php artisan test --compact tests/Feature/AI/AiAgentContextResponseEnvelopeTest.php

~/git/bin/workvm-sandbox destroy mut-envelope
```

CLI default: **sem teto** (`WORKVM_SANDBOX_MAX=0`). No dreno de mutation/coverage
o prompt manda **warm pool** `N = min(arquivos, 4)` (ou `2` se RAM apertada) e
reuso de slot — ver ORCHESTRATION. Cap explícito: `WORKVM_SANDBOX_MAX=N`.

Primeiro `create` faz build de `olie/api-main-sandbox:latest` (PCOV) a partir de
`olie/api-main:latest` se a tag ainda não existir.

## Concorrência (resumo)

| Tipo | Onde | Exemplo |
| --- | --- | --- |
| **Compatible** | Card VM ou mesmo sandbox | gap analysis (só leitura) + miolo colleague-review-core |
| **Exclusive** | Sandbox dedicado (ou fila) | mutation × `php artisan test`; 1 arquivo mutate por sandbox |

## O que isola

| Recurso | Como |
| --- | --- |
| Código | worktree sob `~/git/olie/.sandboxes/<id>/` (`api-main`, `olie-fronts`); `vendor` bind-mount da Card VM (`SB_API_VENDOR`) |
| DB / Redis / Mongo | stack compartilhado `hc-olie-data` (mesmo dos host-cards); por sandbox: `api_sb_<id>` / `testing_sb_<id>`(+`_test_*`) + `REDIS_PREFIX`; `phpunit.xml` do worktree aponta para o testing próprio. Opt-out: `WORKVM_SANDBOX_SHARED_DATA=0` (volta instância slim por sandbox) |
| Rede | bridge `sb-<id>_sb_net` + externa `hc-olie-data` (e2e **sem** `network_mode: host`) |
| Portas host | só após `gui attach` (`compose.gui.yml`) |

## Arquivos

- `ORCHESTRATION.md` — fan-out do colleague review
- `compose.slim.yml` — stack slim (mysql + redis + mongo + app + http + e2e)
- `compose.gui.yml` — publish da porta API
- `Dockerfile.app` — `olie/api-main` + PCOV
- `mysql-init/` — cria `testing` + `api_main`
- `project.sh` — hooks do Manager
- `compose.e2e-host.yml` — `olie-e2e` no ensure do jarvis (`network_mode: host`, DNS do card)
- `host-card-ensure.sh` / `host-card-destroy.sh` — stack slim + front + e2e do **card no host** (`workvm-host-card`; clones em `~/git/olie`, sem worktree detach)
  - Suite: `docker exec -u pwuser hc-olie-<id>-olie-e2e-1 npx playwright test --project=chromium`
  - MCP Playwright: pointer `~/.config/workvm/host-card-e2e-container` → mesmo container
