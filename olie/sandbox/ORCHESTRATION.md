# Orquestração de Sandboxes — Olie (colleague review)

Problema: o stack de revisão de colegas era **sequencial e manual** — paste
`colleague-review` → paste `test-gap-analysis` → paste `mutation-testing` →
vários `next mutation`. Cada passo esperava o anterior.

Objetivo: manter os **gates** (veredito + gap + mutation + testes), mas
disparar tudo a partir de **um** paste (`colleague-review.md` = dispatcher) e
rodar o que for **exclusive** em sandboxes paralelos **dentro** da WorkVM
do Card (`olie-{code}`, ex. `olie-DOP-1262`), sem clonar outra VM.

Mesmo contrato da Televisão (`~/git/televisao/sandbox/ORCHESTRATION.md`),
adaptado aos paths Olie. CLI: `~/git/bin/workvm-sandbox`. Profiles /
compose slim Olie ainda não existem — o piloto de containers foi a Televisão.

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
- `test-gap-analysis.md` (requisitos × testes backend; escreve no card)
- Análise de front + análise de back (só leitura)
- Specs em `~/git/olie/olie-e2e` sem destruir o DB do app

### Exclusive (não podem compartilhar o mesmo ambiente mutável)

Se dois jobs escrevem no mesmo código, DB, Redis ou cobertura, usam
**Sandboxes distintos** (ou fila no mesmo).

Exemplos:

- `mutation-testing` × `php artisan test` / Pest no mesmo sandbox
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
  ├── Task: test-gap-analysis.md   # se backend (api-main)
  └── Task: mutation-testing.md    # se backend; drena todos os *Test.php
  wait → scoreboard → Colleague review outcome
```

Mutation em modo dispatcher processa **todos** os arquivos restantes do
change-set nesta corrida (não um `next mutation` por paste). Own-card
develop handoff continua um arquivo por paste.

### Alvo — fan-out de sandboxes no mesmo Card VM

```text
olie-{code}                              # WorkVM do Card
│
├── (na VM — compatible; disparados pelo colleague-review.md)
│   ├── colleague-review-core
│   └── test-gap-analysis
│
├── mutation-testing (exclusive; 1 *Test.php → 1 sandbox)
│   ├── sb-mut-<file1>
│   ├── sb-mut-<file2>
│   └── sb-mut-<fileN>                   # fila se N > WORKVM_SANDBOX_MAX
│
└── verificação em paralelo (cada um exclusive no próprio sandbox)
    ├── sb-backend-tests                 # Pest / artisan test em api-main
    ├── sb-front-e2e                     # Playwright em olie/olie-e2e
    └── sb-front-unit                    # se houver suite e o card tocar front
```

Gates do funil (**Colleague review outcome** em `workflow-policy.md`)
continuam válidos: não marcar 'Validação' / aprovar PRs enquanto
gap+mutation aplicáveis não terminarem. O que muda é **como**
mutation/testes correm (paralelo em sandboxes), não a regra de outcome.

---

## Mutation: shard por arquivo

No dispatcher colleague, o prompt manda drenar o change-set. Com sandbox:

1. Lista os `*Test.php` do change-set (mesma regra do prompt).
2. Cria até `WORKVM_SANDBOX_MAX` sandboxes `profile=mutation` (Olie guest
   costuma ser 12 GiB — teto inicial sugerido: 3; calibrar na medição).
3. Atribui **um arquivo por sandbox**; quando um termina, pega o próximo da fila.
4. Agrega `mutation-ledger.md` / findings; o dispatcher só então libera o outcome combinado.

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

Sandboxes **não** são VMs novas. Piloto de containers foi a Televisão;
Olie reusa a mesma CLI quando o profile/`olie/sandbox` slim existir.

---

## Medição de economia

Antes: wall-clock do stack sequencial (colleague + gap + N× mutation paste).

Depois: um paste dispatcher + fan-out; comparar wall-clock e pico de RAM guest
(`free`, `docker stats`, RSS do QEMU no host).

O paste `colleague-review.md` já é o disparador; ligar shards
`workvm-sandbox` automaticamente a partir dele é o próximo passo de infra.
