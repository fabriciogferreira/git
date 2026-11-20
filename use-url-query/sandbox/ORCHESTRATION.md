# Orquestração de Sandboxes — use-url-query

Problema: `bun test` / coverage no mesmo Card brigavam pelo
`container_name` fixo do `docker-compose.yml` e pelo workdir do clone.

CLI: `~/git/bin/workvm-sandbox --project use-url-query`. Compose slim:
`use-url-query/sandbox/`.

## Exclusive vs compatible

**Compatible** (Card / mesmo stack): leitura, prompts sem suite paralela.

**Exclusive** (sandbox distinto): `bun test`, `bun test --coverage`,
`bun run build` quando outro job também escreve/node_modules no clone.

**Obrigatório:** coverage drain **não** usa `docker exec` no container
do Card. Usa `workvm-sandbox create --project use-url-query --profile tests`.

Day-to-day `bun test` / `bun run build`: `docker compose exec use-url-query …`
(ou o container do host-card ativo).

## Sem DB / Redis / Pest mutate

Biblioteca TypeScript + bun. Não há Postgres, testing-db-cache nem
`pest --mutate`. Mutation prompt → skip (ver `mutation-testing.md`).

## Warm pool + subagentes

`N = min(arquivos_restantes, 4)` (ou **2** se RAM apertada). Um sandbox +
um subagent (Task) por arquivo in-flight; pai escreve o ledger. Reuse com
rsync dirty; create só o shortfall. `--from-commit` = tip do clone
`use-url-query/use-url-query`.

Service default do job: `backend` (container bun do slim).

Prompts: `use-url-query/prompts/coverage-testing.md`,
`use-url-query/prompts/mutation-testing.md`.
