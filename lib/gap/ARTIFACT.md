# Gap seed artifact (manager → agent)

Problema: `test-gap-analysis.md` pedia ao agente MCP do card + montar change-set +
extrair testes no chat. O manager coleta requisitos (Card Spec) e testes do
change-set; o agente só **julga** o que falta e reporta / implementa.

## Onde vive

```
${XDG_DATA_HOME:-~/.local/share}/project-card-manager/gap/<project>/<code>/
  latest.json
  latest.md
```

Cópia legível também em `olie/cards/<CODE>/gap-seed.md` (quando Card Spec existe).

## `latest.json` (version 1)

| Campo | Significado |
| --- | --- |
| `version` | `1` |
| `project` / `code` | Card |
| `measured_at` | ISO local |
| `api_main` | Worktree `api-main` |
| `tip` | `git rev-parse HEAD` |
| `status` | `ready` \| `empty` \| `skip_no_backend` \| `error` |
| `spec_dir` | Path do Card Spec (`olie/cards/<CODE>`) |
| `requirements` | Trechos de `project.md` + títulos do Caderno |
| `tests[]` | `*Test.php` do change-set + títulos `it`/`test`/`describe` |
| `app_files[]` | `app/**/*.php` do change-set (contexto) |
| `agent_action` | Instrução curta para o agente |

`status=ready` → agente compara requisitos × `tests[]` e sai com **No tests to add**
ou **Tests to add** (título + descrição). Não re-monta change-set nem MCP-dump.

`status=empty` / `skip_no_backend` → nada a analisar (sem `api-main` no change-set).

`status=error` → Card Spec ou card host ausente; usuário corrige no manager.
