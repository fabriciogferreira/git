# Orquestração de Sandboxes — use-url-query

Problema: `bun run test` (Vitest) / coverage no mesmo Card brigavam pelo
`container_name` fixo do `docker-compose.yml` e pelo workdir do clone.

CLI: `~/git/bin/workvm-sandbox --project use-url-query`. Compose slim:
`use-url-query/sandbox/`.

## Exclusive vs compatible

**Compatible** (Card / mesmo stack): leitura, prompts sem suite paralela.

**Exclusive** (sandbox distinto): `bun run test`, `bun run test:coverage`,
`bun run build` quando outro job também escreve/node_modules no clone.

**Obrigatório:** coverage drain **não** usa `docker exec` no container
do Card. Usa `workvm-sandbox create --project use-url-query --profile tests`.

A imagem slim `use-url-query-sandbox-backend:tests` (Dockerfile.backend) traz
Node real além do Bun — Vitest `--coverage` falha se `node` for o fallback do
Bun (`child.channel?.unref`).

Day-to-day `bun run test` / `bun run build`: `docker compose exec use-url-query …`
(ou o container do host-card ativo).

## Escopo do slim

O slim/exclusive atual isola a **lib** (bun). Demo-api/demo-web no host-card
usam o compose host (`compose.host.yml`). Coverage/mutation da lib: sandbox
slim. Demo-api Pest coverage/mutate: workspace do host-card (ou sandbox
exclusive da API se existir). Mutation: **sem auto-skip** — ver
`mutation-testing.md` (lib Blocked sem runner; API com Pest `--mutate`).

## Warm pool + subagentes

`N = min(arquivos_restantes, 4)` (ou **2** se RAM apertada). Um sandbox +
um subagent (Task) por arquivo in-flight; pai escreve o ledger. Reuse com
rsync dirty; create só o shortfall. `--from-commit` = tip do clone
`use-url-query/use-url-query`.

Service default do job: `backend` (container bun do slim).

Prompts: `use-url-query/prompts/coverage-testing.md`,
`use-url-query/prompts/mutation-testing.md`.
