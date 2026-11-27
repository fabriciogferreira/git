# Pest suite artifact (manager → agent)

Problema: `pest-parallel.md` mandava o agente rodar a suite full no chat. O
manager já tem **Pest** (`workvm-host-card-pest`). Medir lá; o agente só lê o
artefato e, se vermelho, conserta.

## Onde vive

```
${XDG_DATA_HOME:-~/.local/share}/project-card-manager/pest/<project>/<code>/
  latest.json
  latest.md
  <timestamp>/   # cópia + log
```

Ledger: `olie/prompts/pest-ledger.md` (uma linha por card@tip quando **pass**).

## `latest.json` (version 1)

| Campo | Significado |
| --- | --- |
| `version` | `1` |
| `project` / `code` | Card |
| `measured_at` | ISO local |
| `api_main` | Worktree |
| `tip` | `git rev-parse HEAD` short |
| `status` | `pass` \| `needs_work` \| `error` |
| `exit_code` | Exit do `workvm-host-card-pest` |
| `summary` | Contagens parseadas do log (`passed`, `failed`, `skipped`, …) |
| `failures` | Lista curta de testes/arquivos falhos (best-effort) |
| `agent_action` | Instrução se vermelho; senão `null` |
| `log` | Path do log da corrida |

Gate: suite **full** green (`exit_code=0`). **Pest Changed** não substitui este gate.

## Fluxo

1. Usuário: manager → **Pest**.
2. Script grava artefato; se pass, upsert no `pest-ledger.md` (`sha:` tip).
3. Agente: `pass` → ok / pre-QA; `needs_work` → implementa fixes a partir de `failures` / log; usuário re-roda Pest.
