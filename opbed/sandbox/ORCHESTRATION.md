# Orquestração de Sandboxes — Opbed

Problema: Pest/mutation no mesmo Card corrompiam `opbed_local` e
brigavam pelo compose namespaced.

CLI: `~/git/bin/workvm-sandbox --project opbed`. Compose slim:
`opbed/sandbox/`.

## Exclusive vs compatible

**Compatible** (Card VM / mesmo sandbox): leitura, gap analysis, prompts
sem Pest runtime.

**Exclusive** (sandbox distinto ou fila): `pest --mutate`,
`pest --coverage`, `php artisan test` que escreve no DB.

**Obrigatório:** mutation e coverage **não** usam
`docker exec hc-opbed-…-backend-1`. Usam
`workvm-sandbox create --project opbed --profile mutation|tests`.

**E2E Playwright (front):** roda no **Card**, não no compose slim
(`profile e2e` hoje é só backend/pgsql/redis). Em
`opbed-frontend`: `bun run test:e2e` (cada spec cria usuário próprio).

## Warm pool + subagentes

`N = min(arquivos_restantes, 4)` (ou **2** se RAM apertada). Um sandbox +
um subagent (Task) por arquivo in-flight; pai escreve o ledger. Reuse com
rsync dirty; create só o shortfall. `--from-commit` = tip do worktree do
card / clone backend.

Prompts: `opbed/prompts/mutation-testing.md`,
`opbed/prompts/coverage-testing.md`.
