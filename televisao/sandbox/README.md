# Sandboxes — piloto Televisão

Ambientes isolados **dentro** da WorkVM do Card (`televisao-{code}`), sem
clonar VM por tarefa.

Orquestração (colleague review, exclusive vs compatible, shard de
mutation): **[ORCHESTRATION.md](./ORCHESTRATION.md)**.

## Uso

```bash
# Na guest do Card (project-setup televisao já rodou)
~/git/bin/workvm-sandbox create --name tests-a --project televisao --profile tests
~/git/bin/workvm-sandbox create --name mut-b --project televisao --profile mutation
~/git/bin/workvm-sandbox create --name e2e-c --project televisao --profile e2e

~/git/bin/workvm-sandbox job run tests-a -- php -r 'echo getenv("REDIS_HOST"), "\n";'
~/git/bin/workvm-sandbox gui attach e2e-c
~/git/bin/workvm-sandbox destroy mut-b
```

Teto padrão: **2** sandboxes (guest apertada). Override: `WORKVM_SANDBOX_MAX=3`.
Com N arquivos de mutation > teto, fila (ver ORCHESTRATION).

## Concorrência (resumo)

| Tipo | Onde | Exemplo |
| --- | --- | --- |
| **Compatible** | Card VM ou mesmo sandbox | gap analysis + miolo do colleague review |
| **Exclusive** | Sandbox dedicado (ou fila) | mutation × artisan test; 1 arquivo mutate por sandbox |

## O que isola

| Recurso | Como |
| --- | --- |
| Código | worktree sob `~/git/televisao/.sandboxes/<id>/` |
| DB / Redis | instâncias + volumes por `COMPOSE_PROJECT_NAME` |
| Rede | bridge `sb-<id>_sb_net` (e2e **sem** `network_mode: host`) |
| Portas host | só após `gui attach` (`compose.gui.yml`) |

## Arquivos

- `ORCHESTRATION.md` — fan-out do colleague review / economia vs pastes sequenciais
- `compose.slim.yml` — stack slim (piloto; TV real usa pgsql — slim ainda traz mysql ocioso a cortar)
- `compose.gui.yml` — publish da porta API
- `project.sh` — hooks do Manager

O compose do clone (`televisao-api`) continua para o desktop interativo da VM.
