# Orquestração de Sandboxes — Televisão (colleague review)

Problema: o stack de revisão de colegas era **sequencial e manual** — paste
`colleague-review` → paste `test-gap-analysis` → paste `mutation-testing` →
vários `next mutation`. Cada passo esperava o anterior.

Objetivo: manter os **gates** (veredito + gap + mutation + coverage + testes),
mas disparar tudo a partir de **um** paste (`colleague-review.md` = dispatcher)
e rodar o que for **exclusive** em sandboxes paralelos **dentro** da host
do Card (`televisao-{code}`), sem clonar outra VM.

CLI / estado: `~/git/bin/workvm-sandbox`, `~/git/televisao/sandbox/README.md`.

**Data compartilhada:** sandboxes e host-cards reusam `hc-televisao-data`
(`televisao-hc-pgsql` / `televisao-hc-redis`) com DB/prefixo por id
(`db_sb_<id>` / `db_<dns_slug>`). Exclusive continua (DBs distintos).
Opt-out sandbox: `WORKVM_SANDBOX_SHARED_DATA=0`.

**Testing DB cache:** no create, `testing-db-cache.sh` importa `pg_dump`
(schema+`TestingSeeder`) em `db_*_test` e `db_*`, e troca o `RefreshDatabase`
do TestCase no worktree por um trait que pula `migrate:fresh` se `migrations`
já existe. Chave = hash dos trees `database/migrations` + `database/seeders`.
Cache: `~/.local/share/workvm/cache/televisao-testing-db/`. Opt-out:
`WORKVM_TELEVISAO_TESTING_DB_CACHE=0`.

Prompts: `colleague-review.md` (disparador) → paralelo
`colleague-review-core.md` + `test-gap-analysis.md` + `mutation-testing.md` +
`coverage-testing.md` (quando há backend). Scoreboard + **Colleague review
outcome** no fim do dispatcher.

---

## Dois tipos de prompt / job

### Compatible (podem coexistir)

Não brigam por worktree / DB / Redis / cobertura. Rodam na **própria host-card**
ou no **mesmo** sandbox.

Exemplos:

- Miolo `colleague-review-core.md` (card, PRs, mídia, contraste, veredito)
- `test-gap-analysis.md` (leitura de requisitos × testes; escreve no card)
- Análise de front + análise de back (só leitura de código)
- Escrita de specs e2e no meta-repo (`televisao-*-e2e`) sem destruir o DB do app

### Exclusive (não podem compartilhar o mesmo ambiente mutável)

Se dois jobs escrevem no mesmo código, DB, Redis ou cobertura, usam
**Sandboxes distintos** (ou fila no mesmo).

Exemplos:

- `mutation-testing` × `php artisan test` no mesmo sandbox
- Dois mutations no **mesmo** arquivo / mesma árvore suja
- E2E que muda dados × suite que assume DB limpo **no mesmo** DB
- Migrate/seed destrutivo × qualquer leitor do mesmo banco

Regra prática: **escreve** no mesmo recurso mutável → exclusive; **read-only**
(ou artefato próprio, ex. `cards/{CODE}/{MEDIA}.md`) → compatible.

---

## Hoje (dispatcher) vs alvo (sandboxes)

### Hoje — um paste, gates em paralelo

```text
paste colleague-review.md          # dispatcher
  bootstrap (card, branches, backend?)
  ├── Task: colleague-review-core.md
  ├── Task: test-gap-analysis.md   # se backend
  ├── Task: mutation-testing.md    # se backend; drena todos os *Test.php
  └── Task: coverage-testing.md    # se backend; drena todos os app/**/*.php
  wait → scoreboard → Colleague review outcome
```

Mutation/coverage em modo dispatcher processam **todos** os arquivos
restantes do change-set nesta corrida. Own-card develop handoff: default
também é **`correct mutations`** / **`correct coverages`** (dreno paralelo);
`next mutation` / `next coverage` = opt-in um arquivo. Mutation × coverage
no **mesmo** sandbox **não**.

### Alvo — fan-out de sandboxes no mesmo host-card

```text
televisao-{code}                         # host do Card
│
├── (na VM — compatible; disparados pelo colleague-review.md)
│   ├── colleague-review-core
│   └── test-gap-analysis
│
├── mutation-testing (exclusive; 1 arquivo → 1 sandbox)
│   ├── sb-mut-<file1>
│   ├── sb-mut-<file2>
│   └── sb-mut-<fileN>                   # fila se N > WORKVM_SANDBOX_MAX
│
└── verificação em paralelo (cada um exclusive no próprio sandbox)
    ├── sb-backend-tests                 # php artisan test (-p se suportado)
    ├── sb-front-e2e                     # Playwright meta-repo
    └── sb-front-unit                    # unit do front, se o card tocar front
```

Gates do funil (**Colleague review outcome** em `workflow-policy.md`)
continuam válidos: não marcar 'Revisado' / merge enquanto gap+mutation+
coverage aplicáveis não terminarem. O que muda é **como** mutation/
coverage/testes correm (paralelo em sandboxes), não a regra de outcome.

---

## Mutation: warm pool + fila por arquivo

No dispatcher colleague, o prompt manda drenar o change-set. Com sandbox:

1. Lista os `*Test.php` do change-set (mesma regra do prompt).
2. Cria um **warm pool** de `N` sandboxes `profile=mutation`: `N = min(restantes, WORKVM_SANDBOX_MAX)` com padrão Televisão **2**, faixa útil **2–4** (baixar para 2 se RAM apertada; não abrir um por arquivo só porque o lote é grande — bench Olie DOP-1258: 2/4/6/8 ≈ mesmo wall).
3. Atribui no máximo **um arquivo por sandbox** em voo; quando um termina, **reusa** o slot para o próximo (rsync dirty). Em cada job: **um** `--class` (multi-`--class` não confiável — R7).
4. Agrega ledger / findings; o dispatcher só então libera o outcome combinado. Destroy o pool ao fim do dreno.

**Flake / deadlock:** 1 retry do mesmo comando no mesmo slot antes de Blocked (`mutation-testing.md`).

**Watchdog de shard:** baseline **> 15 min** sem exit ou mutate **> 45 min** sem exit (ou stdout parado > 10 min) → Blocked (timeout), libera o slot. Opcional: `timeout 900` / `timeout 2700` em volta do `job run`.

Mutation × `artisan test` no **mesmo** sandbox **não**.

---

## Verificação paralela (além da mutation)

Enquanto gap roda na VM (ou após o veredito), sandboxes separados podem:

| Sandbox | Job | Quando |
| --- | --- | --- |
| `sb-backend-tests` | suite API (`artisan test` / Pest) | change-set tocou `televisao-api` |
| `sb-front-e2e` | Playwright em `televisao-*-e2e` | tocou o front correspondente |
| `sb-front-unit` | unit do front | houver suite e o card tocou front |

Esses três são exclusive **entre si só se compartilharem DB/stack**; com
sandbox próprio (rede/DB próprios) rodam em paralelo uns com os outros e
com shards de mutation (desde que o teto de sandboxes comporte — senão fila).

---

## Onde vive o quê

| Camada | Papel |
| --- | --- |
| Host-card | Uma domain `televisao-{code}` por Card |
| host-card | Compatible + orquestração (`colleague-review.md`) + desktop/agente |
| Sandbox (Docker na guest) | Exclusive: mutation shard, pest, e2e, … |

Sandboxes **não** são VMs novas.

---

## Medição de economia

Antes: tempo de wall-clock do stack sequencial (colleague + gap + N× mutation paste).

Depois: um paste dispatcher + fan-out; comparar wall-clock e pico de RAM guest
(`free`, `docker stats`, RSS do QEMU no host).

Piloto CLI já exercitado em `televisao-tv-190` (ver `HISTORICO.md`).
O paste `colleague-review.md` já é o disparador; ligar shards
`workvm-sandbox` automaticamente a partir dele é o próximo passo de infra.
