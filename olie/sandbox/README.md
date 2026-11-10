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

Teto padrão: **3** sandboxes (guest ~12 GiB). Override: `WORKVM_SANDBOX_MAX=2`.
Com N arquivos de mutation > teto, fila (ver ORCHESTRATION).

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
| DB / Redis / Mongo | instâncias + volumes por `COMPOSE_PROJECT_NAME` |
| Rede | bridge `sb-<id>_sb_net` (e2e **sem** `network_mode: host`) |
| Portas host | só após `gui attach` (`compose.gui.yml`) |

## Arquivos

- `ORCHESTRATION.md` — fan-out do colleague review
- `compose.slim.yml` — stack slim (mysql + redis + mongo + app + http + e2e)
- `compose.gui.yml` — publish da porta API
- `Dockerfile.app` — `olie/api-main` + PCOV
- `mysql-init/` — cria `testing` + `api_main`
- `project.sh` — hooks do Manager
