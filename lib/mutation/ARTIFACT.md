# Mutation artifact (manager → agent)

Problema: o prompt `mutation-testing.md` media e implementava no mesmo chat
(sandbox, `pest --mutate`, ledger, drain paralelo) e gastava tokens em
orquestração. O manager mede; o agente só lê o artefato e, se precisar,
aperta asserts (ou documenta `equivalent`).

## Onde vive

```
${XDG_DATA_HOME:-~/.local/share}/project-card-manager/mutation/<project>/<code>/
  latest.json
  latest.md
  <timestamp>/   # plan + logs pest/mutate
```

## `latest.json` (version 1)

| Campo | Significado |
| --- | --- |
| `version` | `1` |
| `project` / `code` | Card |
| `measured_at` | ISO local |
| `api_main` | Worktree medido |
| `tip` | `git rev-parse HEAD` (short) |
| `status` | `pass` \| `needs_work` \| `empty` \| `error` |
| `summary` | `passed` / `failed` / `skipped_sha` / `blocked` |
| `files[]` | Um por `*Test.php` do change-set (após skip `sha:`) |
| `logs.mutate_dir` | Stdout baseline + mutate |

### Cada `files[]`

| Campo | Significado |
| --- | --- |
| `file` | `tests/.../*Test.php` |
| `status` | `pass` \| `fail` \| `skip_sha` \| `blocked` |
| `result` | `100%` \| `equivalent` \| `—` (ledger Result) |
| `classes` | `--class` FQCNs + path + hunks |
| `in_scope_untested` | Lista `{id, line, mutator, path, fqcn}` ainda vivos no hunk |
| `pest_raw_score` | Score Pest da última corrida (pode ser &lt;100 com OOS) |
| `sha` | `sha:` test + production paths do `--class` |
| `agent_action` | Instrução se `fail`/`blocked`; senão `null` |
| `notes` | Texto livre |

Gates: só mutações **in-scope** (hunks do diff). Zero in-scope ou todas mortas → `100%`. Sobreviventes behavior-preserving → agente marca `equivalent` (com ids) no próximo ciclo / ledger — o medidor **não** inventa equivalent sozinho. OOS untested não falha o gate.

## Fluxo

1. Usuário: manager → **Mutation**.
2. Script: change-set → baseline → `pest --mutate --covered-only` (1 `--class` por run) → `latest.json` + upsert **pass** no `mutation-ledger.md`.
3. Agente: se `needs_work`, implementa kills (ou justifica equivalent no ledger); **não** sobe sandbox nem roda mutate.
4. Usuário re-roda Mutation até `pass`.
