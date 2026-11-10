# Orquestração de Sandboxes — Olie (colleague review)

Problema: o stack de revisão de colegas era **sequencial e manual** — paste
`colleague-review` → paste `test-gap-analysis` → paste `mutation-testing` →
vários `next mutation`. Cada passo esperava o anterior. Em paralelo na mesma
Card VM, Pest/mutation corrompiam o MySQL `testing` e até o `api_main`.

Objetivo: manter os **gates** (veredito + gap + mutation + testes), disparar
tudo a partir de **um** paste (`colleague-review.md` = dispatcher) e rodar o
que for **exclusive** em sandboxes paralelos **dentro** da WorkVM do Card
(`olie-{code}`), sem clonar outra VM.

CLI: `~/git/bin/workvm-sandbox`. Compose slim: `olie/sandbox/` (mesmo contrato
da Televisão em `televisao/sandbox/`).

Prompts: `colleague-review.md` (disparador) → paralelo
`colleague-review-core.md` + `test-gap-analysis.md` + `mutation-testing.md`
(quando há backend). Scoreboard + **Colleague review outcome** no fim do
dispatcher.

---

## Dois tipos de prompt / job

### Compatible (podem coexistir)

Não brigam por worktree / DB / Redis / cobertura. Rodam na **própria Card VM**
ou no **mesmo** sandbox.

Exemplos:

- Miolo `colleague-review-core.md` (card, PRs, mídia, contraste, veredito)
- `test-gap-analysis.md` (requisitos × testes backend; **só leitura** — sem
  `php artisan test` na Card VM quando mutation está em paralelo)
- Análise de front + análise de back (só leitura)

### Exclusive (não podem compartilhar o mesmo ambiente mutável)

Se dois jobs escrevem no mesmo código, DB, Redis ou cobertura, usam
**Sandboxes distintos** (ou fila no mesmo).

Exemplos:

- `mutation-testing` × `php artisan test` / Pest
- Dois mutations no **mesmo** arquivo / mesma árvore suja
- E2E que muda dados × suite que assume DB limpo **no mesmo** DB
- Migrate/seed destrutivo × qualquer leitor do mesmo banco

Regra prática: **escreve** no mesmo recurso mutável → exclusive; **read-only**
(ou artefato próprio, ex. `cards/{CODE}/{MEDIA}.md`) → compatible.

**Obrigatório:** com `olie/sandbox/project.sh` presente, o gate de mutation
(e qualquer Pest baseline) **não** usa `docker exec olie-api-main`. Usa
`workvm-sandbox create --project olie --profile mutation|tests`.

---

## Dispatcher + fan-out

```text
paste colleague-review.md          # dispatcher
  bootstrap (card, branches, backend?)
  ├── Task: colleague-review-core.md     # Card VM (compatible)
  ├── Task: test-gap-analysis.md         # Card VM, sem Pest runtime
  └── Task: mutation-testing.md          # exclusive → sandboxes
        ├── sb-mut-<file1>
        ├── sb-mut-<file2>
        └── sb-mut-<fileN>               # fila se N > WORKVM_SANDBOX_MAX
  wait → scoreboard → Colleague review outcome
```

Mutation em modo dispatcher processa **todos** os arquivos restantes do
change-set nesta corrida (não um `next mutation` por paste). Own-card
develop handoff continua um arquivo por paste — também preferir sandbox
`profile=mutation` para não tocar o `testing` da Card VM.

---

## Mutation: shard por arquivo

1. Lista os `*Test.php` do change-set (mesma regra do prompt).
2. Cria até `WORKVM_SANDBOX_MAX` sandboxes `profile=mutation` (default Olie: 3).
3. Atribui **um arquivo por sandbox**; quando um termina, pega o próximo da fila.
4. Em cada sandbox:

```bash
~/git/bin/workvm-sandbox create --name "mut-$(basename "$file" .php | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | cut -c1-40)" \
  --project olie --profile mutation
~/git/bin/workvm-sandbox job run "$id" -- php artisan test --compact "$file"
~/git/bin/workvm-sandbox job run "$id" -- vendor/bin/pest --mutate --covered-only --min=100 \
  --ignore-min-score-on-zero-mutations --class=App\\... "$file"
~/git/bin/workvm-sandbox destroy "$id"
```

5. Agrega `mutation-ledger.md` / findings; o dispatcher só então libera o outcome.

N sandboxes de mutation (arquivos distintos) **podem** rodar juntos.
Mutation × suite Pest no **mesmo** sandbox **não**.

---

## Verificação paralela (além da mutation)

| Sandbox | Job | Quando |
| --- | --- | --- |
| `sb-backend-tests` | suite `api-main` (Pest / `artisan test`) | change-set tocou `api-main` |
| `sb-front-e2e` | Playwright em `olie/olie-e2e` | tocou `olie-fronts` (ou front relevante) |
| `sb-front-unit` | unit do front | houver suite e o card tocou front |

Com sandbox próprio (rede/DB próprios) rodam em paralelo uns com os outros e
com shards de mutation (fila se passar do teto).

---

## Onde vive o quê

| Camada | Papel |
| --- | --- |
| Host libvirt | Uma domain `olie-{code}` por Card |
| Card VM | Compatible + orquestração (`colleague-review.md`) + desktop/agente |
| Sandbox (Docker na guest) | Exclusive: mutation shard, pest, e2e, … |

Sandboxes **não** são VMs novas.

---

## Medição de economia

Antes: wall-clock do stack sequencial (colleague + gap + N× mutation paste),
ou paralelo na Card VM com DB compartilhado (incidente DOP-1165).

Depois: um paste dispatcher + fan-out em sandboxes; comparar wall-clock e pico
de RAM guest (`free`, `docker stats`, RSS do QEMU no host).
