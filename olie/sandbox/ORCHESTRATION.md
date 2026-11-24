# Orquestração de Sandboxes — Olie (colleague review)

Problema: o stack de revisão de colegas era **sequencial e manual** — paste
`colleague-review` → paste `test-gap-analysis` → paste `mutation-testing` →
vários `next mutation`. Cada passo esperava o anterior. Em paralelo na mesma
Card VM, Pest/mutation corrompiam o MySQL `testing` e até o `api_main`.

Objetivo: manter os **gates** (veredito + gap + mutation + coverage + testes),
disparar tudo a partir de **um** paste (`colleague-review.md` = dispatcher) e
rodar o que for **exclusive** em sandboxes paralelos **dentro** da WorkVM do
Card (`olie-{code}`), sem clonar outra VM.

CLI: `~/git/bin/workvm-sandbox`. Compose slim: `olie/sandbox/` (mesmo contrato
da Televisão em `televisao/sandbox/`).

**`.env` do sandbox:** `workvm_sandbox_olie_write_env` remove linhas `KEY=`
vazias na cópia (ex. `META_GRAPH_URL=`). Laravel trata env vazio como setado e
o default de `config()` some — baselines vermelhas no dispatcher.

Prompts: `colleague-review.md` (disparador) → paralelo
`colleague-review-core.md` + `test-gap-analysis.md` + `mutation-testing.md` +
`coverage-testing.md` (quando há backend). Scoreboard + **Colleague review
outcome** no fim do dispatcher.

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

**Data compartilhada:** sandboxes Olie **não** sobem mysql/redis/mongo
próprios — reusam `hc-olie-data` (`olie-hc-*`) com DB/prefixo por id
(`api_sb_<id>` / `testing_sb_<id>`). Exclusive continua válido (DBs
distintos); o ganho é RAM no warm pool. Opt-out: `WORKVM_SANDBOX_SHARED_DATA=0`.

**Testing DB cache (estilo vendor):** no create (após `compose up`),
`testing-db-cache.sh` importa um `mysqldump` gzip do schema+`TestingDatabaseSeeder`
em `testing_sb_*` **e** `api_sb_*`, e carimba `storage/app/migration-checksum_*.txt`
para o FastRefresh pular `migrate:fresh` no 1º Pest. Chave = hash do tree
`database/migrations` + blobs do `TestingDatabaseSeeder` e seeders que ele
chama (User/Frame/FrameData/Permissions/System/Product). Nova migration ou
mudança nesses seeders → miss. Cache em
`~/.local/share/workvm/cache/olie-testing-db/`. Opt-out:
`WORKVM_OLIE_TESTING_DB_CACHE=0`.

---

## Dispatcher + fan-out

```text
paste colleague-review.md          # dispatcher
  bootstrap (card, branches, backend?)
  ├── Task: colleague-review-core.md     # Card VM (compatible)
  ├── Task: test-gap-analysis.md         # Card VM, sem Pest runtime
  ├── Task: mutation-testing.md          # exclusive → sandboxes
  │     ├── sb-mut-<file1>
  │     └── sb-mut-<fileN>
  └── Task: coverage-testing.md          # exclusive → sandboxes
        ├── sb-cov-<app-file1>
        └── sb-cov-<app-fileN>           # todos em paralelo (Olie: sem teto)
  wait → scoreboard → Colleague review outcome
```

Mutation/coverage em modo dispatcher processam **todos** os arquivos
restantes do change-set nesta corrida. Own-card develop handoff: default
também é **`correct mutations`** / **`correct coverages`** (dreno paralelo
nesta corrida — um sandbox `profile=mutation` + um subagent por arquivo;
pai agrega o ledger); `next mutation` / `next coverage` = opt-in um
arquivo. Preferir sandbox para não tocar o `testing` da Card VM.
Mutation × coverage **em paralelo** no mesmo sandbox **não** (ambos escrevem
Pest/DB). **Own-card sequencial** (coverage → depois mutation): **reaproveitar**
o warm pool do coverage — `workvm-sandbox sync <id> --from <card-api-main>`
(dirty) + criar só o shortfall se mutation precisar de mais slots; destroy só
ao fim do mutation (ou se o usuário parar antes). **Proibido** rsync manual
para o sandbox (dest vazio → `/` apaga `$HOME`). Isolamento = um job exclusive
por sandbox **em voo**, não “um create por estágio”. Colleague **dispatcher**
(coverage ∥ mutation): pools **separados** (ainda em paralelo).

**Warm pool (mutation/coverage drain):** mutation `N = min(arquivos_restantes, 4)`;
coverage `N = min(lotes_via-test, 4)`. Use **`2`** se a RAM estiver apertada
(`available` ≲ 8 GiB antes do create). Não abrir um sandbox por arquivo só
porque o change-set é grande — bench DOP-1258 (8 arquivos): pools 2/4/6/8 ≈
**387–406s** de wall; pool **8** aumentou o pior shard (~349s vs ~178s) por
contenção. O CLI ainda aceita `WORKVM_SANDBOX_MAX=0` (sem teto de software);
o **prompt** manda o agente respeitar esta faixa 2–4 com reuso.

**Coverage em lote por Via test:** um `pest --coverage` por Via fecha todos os
`app/` do change-set presentes no relatório (não um job por arquivo). Bench
DOP-1183 (quente): 5 arquivos / 1 Via ~34s→~6s; 8 arquivos / 2 Vias ~53s→~13s.

**`--from-commit` obrigatório (host-card):** resolve o tip do worktree do
card (`meta.json` → `api_worktree` / `…/worktree/api-main`, `git rev-parse HEAD`)
e passa `--from-commit <tip>` em **todo** `workvm-sandbox create`. Create
“nu” usa o `HEAD` do clone em `~/git/olie/api-main` (souvent `develop`) — bench
DOP-1183: bare → `0b2c8f77` develop; tip card `4cdc921c` → só com
`--from-commit`. Recreate após descobrir o SHA errado ≈ **+58s** wall. O
mesmo SHA pode falhar em `olie-fronts` (ref inexistente); para mutation/
coverage o que importa é o `api-main` no tip.

---

## Mutation: warm pool + fila por arquivo

1. Lista os `*Test.php` do change-set (mesma regra do prompt).
2. Monta pool de **N** slots (`N = min(restantes, 4)`, ou `2` se RAM apertada): own-card **adota** sandboxes ready do coverage e só `create --from-commit <tip>` o shortfall; dispatcher ∥ coverage → pool novo. Opcional: `WORKVM_SANDBOX_MAX=N`.
3. Atribui no máximo **um arquivo por sandbox** em voo; quando um termina, **reusa** o mesmo sandbox para o próximo (`workvm-sandbox sync` dirty; sem destroy entre arquivos do dreno).
4. Em cada job: **um** `--class` por run (FQCN do pool que aquele teste exercita — não o pool inteiro; bench DOP-1281 ~1.6×). Multi-`--class` no mesmo `pest --mutate` é não confiável (R7: 0 files / só 1 file).

```bash
# tip = git -C "$api_worktree/api-main" rev-parse HEAD  (host-card meta.json)
# adopt coverage leftovers, create shortfall, then for each file on a free slot:
~/git/bin/workvm-sandbox create --name "$id" --project olie --profile mutation --from-commit "$tip"
~/git/bin/workvm-sandbox sync "$id" --from "$api_worktree/api-main"
# path (nunca inventar dest): ~/git/bin/workvm-sandbox path "$id"   # …/.sandboxes/<id>/api-main
~/git/bin/workvm-sandbox job run "$id" -- php artisan test --compact "$file"
# --class: single-quote with ONE backslash (not App\\… inside quotes → 0 Mutations)
~/git/bin/workvm-sandbox job run "$id" -- vendor/bin/pest --mutate --covered-only --min=100 \
  --ignore-min-score-on-zero-mutations '--class=App\Services\Example' "$file"
# destroy the pool after the *mutation* drain (own-card kept coverage pool until here)
```

5. Agrega `mutation-ledger.md` / findings; o dispatcher só então libera o outcome.

**Flake / deadlock:** baseline ou erro MySQL transitório (`Deadlock found`, `Lock wait timeout`, `model_has_permissions`) → **1** retry do mesmo comando no **mesmo** slot antes de Blocked (`mutation-testing.md`). Não destroy/recreate por flake.

**Watchdog de shard (pai do dreno):** se um job de baseline ficar **> 15 min** sem exit, ou um `pest --mutate` **> 45 min** sem exit (ou stdout parado > 10 min no mutate), o pai marca o arquivo **Blocked (timeout)**, libera o slot para o próximo da fila e **não** espera o shard eternamente. Preferir `timeout(1)` no host em volta do `job run` quando o CLI não encerrar sozinho (`timeout 900` baseline / `timeout 2700` mutate). Não matar um mutate que ainda imprime progresso dentro do teto.

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
