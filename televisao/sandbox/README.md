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
| **Compatible** | host-card ou mesmo sandbox | gap analysis + miolo do colleague review |
| **Exclusive** | Sandbox dedicado (ou fila) | mutation × artisan test; 1 arquivo mutate por sandbox |

## O que isola

| Recurso | Como |
| --- | --- |
| Código | worktree sob `~/git/televisao/.sandboxes/<id>/` |
| DB / Redis | stack compartilhado `hc-televisao-data` (mesmo dos host-cards); por sandbox: `db_sb_<id>` / `db_sb_<id>_test` + `REDIS_PREFIX`. O serviço `app` exporta **`SB_TESTING_DATABASE`** (Pest; Docker env vence PHPUnit force). Opt-out: `WORKVM_SANDBOX_SHARED_DATA=0` |
| Rede | bridge `sb-<id>_sb_net` + externa `hc-televisao-data` (e2e **sem** `network_mode: host`) |
| Portas host | só após `gui attach` (`compose.gui.yml`) |

## Arquivos

- `ORCHESTRATION.md` — fan-out do colleague review / economia vs pastes sequenciais
- `compose.host-data.yml` / `host-card-shared-data.sh` — shared pgsql+redis
- `compose.slim.yml` + `compose.sandbox-shared-data.yml` — sandbox (mysql local fica unused com shared)
- `Dockerfile.app` — `televisao/api-sandbox:latest` (PHP 8.4 + pdo_pgsql + PCOV + git); build no primeiro `create` (ou quando o Dockerfile muda)
- `compose.host.yml` + `compose.host-shared-data.yml` — host-card
- `compose.gui.yml` — publish da porta API
- `project.sh` — hooks do Manager

`job run` no profile `mutation`/`tests` usa `working_dir=/work/televisao-api` e monta
`SB_API_VENDOR` do clone `~/git/televisao/televisao-api/vendor`.

O compose do clone (`televisao-api`) continua para o desktop interativo da VM.
