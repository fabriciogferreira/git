# Orquestração de Sandboxes — fabriciogferreira

Problema: `npm run lint` / `build` no mesmo Card brigavam pelo
`container_name` fixo do `docker-compose.yaml` e pelo workdir do clone.

CLI: `~/git/bin/workvm-sandbox --project fabriciogferreira`. Compose slim:
`fabriciogferreira/sandbox/`.

## Exclusive vs compatible

**Compatible** (Card / mesmo stack): leitura, prompts sem suite paralela.

**Exclusive** (sandbox distinto): `npm run lint`, `npm run build` quando outro
job também escreve/`node_modules` no clone.

Day-to-day lint/dev: container `frontend` do compose local ou host-card.

## Sem DB / Pest mutate

Portfólio Next.js. Não há Postgres nem `pest --mutate`. Mutation prompt → skip.

## Warm pool

`N = min(arquivos_restantes, 2)`. Service default do job: `backend` (Node slim).

Prompts: `fabriciogferreira/prompts/`.
