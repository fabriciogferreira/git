# Coverage artifact (manager → agent)

Problema: o prompt `coverage-testing.md` media e implementava no mesmo chat (sandbox,
Pest, ledger, ratchet) e gastava tokens em orquestração. O manager mede; o agente
só lê o artefato e, se precisar, implementa testes.

## Onde vive

```
${XDG_DATA_HOME:-~/.local/share}/project-card-manager/coverage/<project>/<code>/
  latest.json    # contrato abaixo (sempre a última medição)
  latest.md      # resumo humano
  <timestamp>/   # cópia imutável daquela corrida (json + pest logs)
```

O agent abre `latest.json` do card (ou o path que o usuário colar).

## `latest.json` (version 1)

| Campo | Significado |
| --- | --- |
| `version` | `1` |
| `project` / `code` | Card |
| `measured_at` | ISO local |
| `api_main` | Worktree `api-main` medido |
| `tip` | `git rev-parse HEAD` |
| `status` | `pass` \| `needs_work` \| `empty` \| `error` |
| `summary` | Contagens (`passed`, `failed`, `skipped_sha`, `blocked`, `no_related_test`) |
| `files[]` | Uma entrada por `app/**/*.php` do change-set (após skip `sha:`) |
| `logs.pest_dir` | Diretório com stdout do Pest por Via |

### Cada `files[]`

| Campo | Significado |
| --- | --- |
| `file` | Path repo-relative (`app/...`) |
| `fqcn` | PSR-4 |
| `status` | `pass` \| `fail` \| `skip_sha` \| `blocked` \| `no_related_test` |
| `band` | `new` \| `small` \| `large` |
| `in_scope_pct` | % das linhas executáveis do hunk cobertas |
| `in_scope_uncovered` | Lista de linhas / ranges ainda vermelhas no hunk |
| `file_raw_pct` | % Pest do arquivo inteiro |
| `prev_file_raw_pct` | Baseline do ledger (ou `null`) |
| `ratchet_target_pct` | `min(100, prev+1)` quando Large + prev existe |
| `via_tests` | `*Test.php` usados na medição |
| `sha` | `sha:<fp>` atual (`workvm-ledger-sha.sh`) |
| `agent_action` | Instrução curta se `fail` / `blocked` / `no_related_test`; senão `null` |
| `notes` | Texto livre (hunks, ratchet, PCOV) |

Gates = os de `coverage-testing.md` / ledger (in-scope 100%; Small/New → File raw 100%; Large → +1pp vs prev).

## Fluxo

1. Usuário: manager → **Coverage** (projeto + card).
2. Script grava `latest.json` / `latest.md` e atualiza linhas **pass** no `coverage-ledger.md`.
3. Usuário cola o path (ou pede “olha o coverage”) no chat.
4. Agente: se `status=pass|empty` → ok; se `needs_work` → implementa só `agent_action` nos testes; **não** sobe sandbox nem roda Pest.
5. Usuário re-roda Coverage no manager até `pass`.
