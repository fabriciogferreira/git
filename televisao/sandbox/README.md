# Sandboxes — piloto Televisão

Ambientes isolados **dentro** da WorkVM do Card (Docker), sem clonar VM por tarefa.

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

Teto padrão: **2** sandboxes (guest 8 GiB). Override: `WORKVM_SANDBOX_MAX=3`.

## O que isola

| Recurso | Como |
| --- | --- |
| Código | worktree sob `~/git/televisao/.sandboxes/<id>/` (se o clone existir) |
| MySQL / Redis | containers + volumes `sb-<id>_*` |
| Rede | bridge `sb-<id>_sb_net` (e2e **sem** `network_mode: host`) |
| Portas host | só após `gui attach` (`compose.gui.yml`) |

## Arquivos

- `compose.slim.yml` — stack slim (mysql, redis, app, http, e2e)
- `compose.gui.yml` — publish da porta API
- `project.sh` — hooks do Manager

O compose “oficial” do clone (`televisao-api`) continua para o desktop interativo da VM. Sandboxes usam este slim até haver override wrap do compose da empresa.
