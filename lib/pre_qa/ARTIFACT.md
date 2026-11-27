# Pre-QA artifact (manager → agent)

Problema: `pre-qa.md` misturava julgamento (UX, docs impact, evidência) com I/O
mecânico (commitlint, `gh pr create`, checklist, forms, move). O manager faz o
mecânico; o agente só julga o que falta e posta Decisões/Evidência.

## Onde vive

```
${XDG_DATA_HOME:-~/.local/share}/project-card-manager/pre-qa/<project>/<code>/
  latest.json
  latest.md
```

## `latest.json` (version 1)

| Campo | Significado |
| --- | --- |
| `version` | `1` |
| `project` / `code` | Card |
| `measured_at` | ISO local |
| `status` | `pass` \| `needs_work` \| `blocked` \| `error` |
| `dry_run` | `true` se não escreveu board/PRs |
| `docs_update` | `sim` \| `nao` \| `unknown` (flag `--docs`) |
| `gates` | Pest/Coverage/Mutation artifact status (when backend) |
| `repos[]` | Por clone: branch, commitlint, PR url/number, push |
| `checklist` | Toggle **Pull Request criado** result |
| `forms` | Docs form + PR URL fields written |
| `move` | Destination step + verified stage |
| `agent_actions[]` | O que o agente ainda deve fazer |

`status=pass` → board em QA/CR, PRs ok, checklist ok. Agente: evidência/decisões + relatório.

`status=needs_work` → mecânico parcial (ex.: commitlint vermelho, PR sem reviewer). Agente corrige código/mensagens; user re-roda **Pre-QA**.

`status=blocked` → falta gate manager (Pest/Coverage) ou Card Spec / Open.

## Flags do binário

```
workvm-host-card-pre-qa --project olie --code CODE \
  [--docs sim|nao] [--dry-run] [--skip-pr] [--skip-move] [--skip-checklist]
```

Default: **apply** (cria PR, toggle, move). Manager menu = apply. Use `--dry-run` para só planejar.
