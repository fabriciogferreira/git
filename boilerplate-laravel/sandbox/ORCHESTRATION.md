# Orquestração de Sandboxes — boilerplate-laravel

Problema: Pest/mutation no mesmo Card corrompiam o Postgres do
`compose.dev.yaml` e brigavam pelo compose namespaced.

CLI: `~/git/bin/workvm-sandbox --project boilerplate-laravel`. Compose slim:
`boilerplate-laravel/sandbox/`.

## Exclusive vs compatible

**Compatible** (Card / mesmo stack): leitura, prompts sem Pest runtime.

**Exclusive** (sandbox distinto ou fila): `pest --mutate`,
`pest --coverage`, `php artisan test` que escreve no DB.

**Obrigatório:** mutation e coverage **não** usam
`docker exec` no `workspace`/`php-fpm` do Card. Usam
`workvm-sandbox create --project boilerplate-laravel --profile mutation|tests`.

**Driver:** imagem `:sandbox` com **PCOV** (ensure no create). Preferível a
Xdebug nestes jobs por line coverage ~2,8× mais rápido
([PCOV or Xdebug?](https://phpunit.expert/articles/pcov-or-xdebug.html));
Pest aceita os dois. Card/compose.dev fica com Xdebug — não alterar o
Dockerfile do clone só por mutation.

Day-to-day tests/PHPStan/CS Fixer: `docker compose exec workspace …`
(ou o container workspace do host-card ativo).

## Warm pool + subagentes

`N = min(arquivos_restantes, 4)` (ou **2** se RAM apertada). Um sandbox +
um subagent (Task) por arquivo in-flight; pai escreve o ledger. Reuse com
rsync dirty; create só o shortfall. `--from-commit` = tip do clone
`boilerplate-laravel/boilerplate-laravel`.

Service default do job: `backend` (container CLI do slim).

Prompts: `boilerplate-laravel/prompts/mutation-testing.md`,
`boilerplate-laravel/prompts/coverage-testing.md`.
