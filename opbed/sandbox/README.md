# Sandboxes — Opbed

Ambientes isolados para Pest/mutation sem brigar pelo Postgres do Card
(`opbed_local`). CLI: `~/git/bin/workvm-sandbox`.

## Uso

```bash
~/git/bin/workvm-sandbox create --name mut-a --project opbed --profile mutation --from-commit <tip>
~/git/bin/workvm-sandbox job run mut-a --service backend -- php artisan test --compact path/to/Test.php
~/git/bin/workvm-sandbox destroy mut-a
```

Teto padrão: **2**. Override: `WORKVM_SANDBOX_MAX=N`.

Service default do job: `backend` (meta `default_service`). Prefira
`--service backend` nos prompts.

## O que isola

| Recurso | Como |
| --- | --- |
| Código | worktree sob `~/git/opbed/.sandboxes/<id>/` |
| DB / Redis | stack compartilhado `hc-opbed-data` (`opbed-hc-pgsql` / `opbed-hc-redis`); por sandbox: `db_sb_<id>` / `db_sb_<id>_test` + `REDIS_PREFIX`. Opt-out: `WORKVM_SANDBOX_SHARED_DATA=0` |
| Rede | bridge `sb-<id>_sb_net` + externa `hc-opbed-data` |

**Testing DB cache:** no create, `testing-db-cache.sh` importa `pg_dump` (schema+seed) e patcha o TestCase do worktree. Opt-out: `WORKVM_OPBED_TESTING_DB_CACHE=0`.

**Proibido** para mutation/coverage: `docker exec hc-opbed-…-backend-1` — use o sandbox.

## Arquivos

- `compose.host-data.yml` — shared pgsql+redis
- `host-card-shared-data.sh` — ensure/provision/drop
- `compose.slim.yml` + `compose.sandbox-shared-data.yml` — sandbox
- `testing-db-cache.sh` — dump/import Postgres
- `project.sh` — hooks do Manager
- `ORCHESTRATION.md` — exclusive vs compatible + warm pool
- `host-card-ensure.sh` / `host-card-destroy.sh` — Card + shared data
