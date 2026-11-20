# Sandboxes — Locav

Ambientes isolados para Pest/mutation sem brigar pelo Sail do clone.
CLI: `~/git/bin/workvm-sandbox`.

## Uso

```bash
~/git/bin/workvm-sandbox create --name mut-a --project locav --profile mutation --from-commit <tip>
~/git/bin/workvm-sandbox job run mut-a -- php artisan test --compact path/to/Test.php
~/git/bin/workvm-sandbox destroy mut-a
```

Teto padrão: **2**. Override: `WORKVM_SANDBOX_MAX=N`.

## O que isola

| Recurso | Como |
| --- | --- |
| Código | worktree sob `~/git/locav/.sandboxes/<id>/` |
| DB / Redis | stack compartilhado `hc-locav-data` (`locav-hc-pgsql` / `locav-hc-redis`); por sandbox: `db_sb_<id>` / `db_sb_<id>_test` + `REDIS_PREFIX`. Opt-out: `WORKVM_SANDBOX_SHARED_DATA=0` |
| Rede | bridge `sb-<id>_sb_net` + externa `hc-locav-data` |

**Testing DB cache:** no create, `testing-db-cache.sh` importa `pg_dump` (schema+seed) em testing/api e patcha o TestCase do worktree para pular `migrate:fresh` se `migrations` já existe. Chave = trees `database/migrations` + `database/seeders`. Cache: `~/.local/share/workvm/cache/locav-testing-db/`. Opt-out: `WORKVM_LOCAV_TESTING_DB_CACHE=0`.

## Arquivos

- `compose.host-data.yml` — shared pgsql+redis
- `host-card-shared-data.sh` — ensure/provision/drop
- `compose.slim.yml` + `compose.sandbox-shared-data.yml` — sandbox
- `testing-db-cache.sh` — dump/import Postgres (estilo vendor)
- `project.sh` — hooks do Manager
- `host-card-ensure.sh` / `host-card-destroy.sh` — shared data no ensure do card (app compose namespaced ainda TBD)
