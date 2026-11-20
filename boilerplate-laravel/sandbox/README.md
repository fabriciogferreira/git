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

Antes do primeiro sandbox: `composer install` no clone e imagem base
`boilerplate-laravel-workspace:latest` (compose.dev). O create garante
`boilerplate-laravel-workspace:sandbox` **com PCOV** via
`Dockerfile.workspace` (o Dockerfile do clone / Card não muda — Xdebug no
Card basta para o dia a dia; mutation/coverage usam o sandbox).

### Por que PCOV no sandbox (não só Xdebug)

Pest aceita **Xdebug 3+ ou PCOV** para `--mutate` / `--coverage`. Nos
sandboxes preferimos **PCOV** por velocidade de **line coverage**: no
benchmark de [PCOV or Xdebug?](https://phpunit.expert/articles/pcov-or-xdebug.html)
(Sebastian Bergmann), coletar line coverage ficou ~**2,8×** mais lento com
Xdebug (~53s) do que com PCOV (~19s) na mesma suite. Mutation reusa o
driver muitas vezes — o gap se multiplica. Card continua com Xdebug para
debug/smoke; exclusive mutate/coverage → imagem `:sandbox` com PCOV.

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
- `Dockerfile.workspace` — base workspace + PCOV → tag `:sandbox`
- `testing-db-cache.sh` — dump/import Postgres
- `project.sh` — hooks do Manager (incl. ensure da imagem com PCOV)
- `ORCHESTRATION.md` — exclusive vs compatible + warm pool
- `host-card-ensure.sh` / `host-card-destroy.sh` — Card + shared data
- `compose.host.yml` — stack navegável no host-card
