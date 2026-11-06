# Sandboxes — Olie (contrato)

Ambientes isolados **dentro** da WorkVM do Card (`olie-{code}`), sem clonar
VM por tarefa. A CLI é a mesma da Televisão: `~/git/bin/workvm-sandbox`.

Orquestração (colleague review dispatcher, exclusive vs compatible, shard de
mutation): **[ORCHESTRATION.md](./ORCHESTRATION.md)**.

## Estado

- **Dispatcher de prompts:** `colleague-review.md` → paralelo core + gap + mutation.
- **Compose slim / `project.sh` Olie:** ainda não — piloto de containers em
  `televisao/sandbox/`.

## Concorrência (resumo)

| Tipo | Onde | Exemplo |
| --- | --- | --- |
| **Compatible** | Card VM ou mesmo sandbox | core + gap analysis |
| **Exclusive** | Sandbox dedicado (ou fila) | mutation × Pest; 1 arquivo mutate por sandbox |

Teto sugerido inicial na guest Olie (12 GiB): `WORKVM_SANDBOX_MAX=3` (calibrar).
