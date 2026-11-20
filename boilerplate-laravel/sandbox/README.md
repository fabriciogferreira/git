# Sandboxes — boilerplate-laravel

Ambientes isolados para Pest/mutation sem brigar pelo Postgres do Card.
CLI: `~/git/bin/workvm-sandbox`.

## Uso

```bash
~/git/bin/workvm-sandbox create --name mut-a --project boilerplate-laravel --profile mutation --from-commit <tip>
~/git/bin/workvm-sandbox job run mut-a --service backend -- php artisan test --compact path/to/Test.php
~/git/bin/workvm-sandbox destroy mut-a
```

Teto padrão: **2**. Override: `WORKVM_SANDBOX_MAX=N`.

Service default do job: `backend`. Prefira `--service backend` nos prompts.

Antes do primeiro sandbox: `composer install` no clone e imagem
`boilerplate-laravel-workspace:sandbox` (host-card/`compose up --build` cria).

## O que isola

| Recurso | Como |
| --- | --- |
| Código | worktree sob `~/git/boilerplate-laravel/.sandboxes/<id>/` |
| DB / Redis | stack `hc-boilerplate-laravel-data` (`bl-hc-pgsql` / `bl-hc-redis`); por sandbox: `db_sb_<id>` / `db_sb_<id>_test` + `REDIS_PREFIX`. Opt-out: `WORKVM_SANDBOX_SHARED_DATA=0` |
| Rede | bridge `sb-<id>_sb_net` + externa `hc-boilerplate-laravel-data` |

**Testing DB cache:** no create, `testing-db-cache.sh` importa `pg_dump` e patcha o TestCase. Opt-out: `WORKVM_BL_TESTING_DB_CACHE=0`.

**Proibido** para mutation/coverage: `docker exec` no workspace do Card — use o sandbox.

## Arquivos

- `compose.host-data.yml` — shared pgsql+redis
- `host-card-shared-data.sh` — ensure/provision/drop
- `compose.slim.yml` + `compose.sandbox-shared-data.yml` — sandbox
- `testing-db-cache.sh` — dump/import Postgres
- `project.sh` — hooks do Manager
- `ORCHESTRATION.md` — exclusive vs compatible + warm pool
- `host-card-ensure.sh` / `host-card-destroy.sh` — Card + shared data
- `compose.host.yml` — stack navegável no host-card
