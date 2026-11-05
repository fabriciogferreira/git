# Orquestração de Sandboxes — Televisão (colleague review)

Problema: o stack de revisão de colegas é **sequencial e manual** — paste
`colleague-review.md` → paste `test-gap-analysis.md` → paste
`mutation-testing.md` → vários `next mutation` (um arquivo por vez). Cada
passo espera o anterior; mutation sozinha pode ser dezenas de minutos.

Objetivo: manter os **gates** (veredito + gap + mutation + testes), mas
rodar o que for **exclusive** em sandboxes paralelos **dentro** da WorkVM
do Card (`televisao-{code}`), sem clonar outra VM.

CLI / estado: `~/git/bin/workvm-sandbox`, `~/git/televisao/sandbox/README.md`.

---

## Dois tipos de prompt / job

### Compatible (podem coexistir)

Não brigam por worktree / DB / Redis / cobertura. Rodam na **própria Card VM**
ou no **mesmo** sandbox.

Exemplos:

- Miolo do `colleague-review.md` (card, PRs, mídia, contraste, veredito)
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

## Hoje (dor) vs alvo (economia de tempo)

### Hoje — sequencial na Card VM

```text
paste colleague-review.md
  → paste test-gap-analysis.md
    → paste mutation-testing.md   # 1 arquivo
      → next mutation             # 1 arquivo
        → next mutation           # …
```

Custo: espera humana entre pastes + mutation serializada por arquivo.

### Alvo — um Card VM, fan-out de sandboxes

```text
televisao-{code}                         # WorkVM do Card
│
├── (na VM — compatible)
│   ├── colleague-review (miolo: card, PRs, mídia, veredito)
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
continuam válidos: não marcar 'Revisado' / merge enquanto gap+mutation
aplicáveis não terminarem. O que muda é **como** mutation/testes correm
(paralelo em sandboxes), não a regra de outcome.

---

## Mutation: shard por arquivo

`mutation-testing.md` hoje processa **um** `*Test.php` por paste (`next mutation`).

No alvo, o orquestrador:

1. Lista os `*Test.php` do change-set (mesma regra do prompt).
2. Cria até `WORKVM_SANDBOX_MAX` sandboxes `profile=mutation` (padrão Televisão: 2).
3. Atribui **um arquivo por sandbox**; quando um termina, pega o próximo da fila.
4. Agrega ledger / findings; só então libera o outcome combinado.

Assim some a espera de `next mutation` entre arquivos — o teto de RAM da
guest limita só o paralelismo instantâneo, não a cobertura.

N sandboxes de mutation (arquivos distintos) **podem** rodar juntos.
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
| Host libvirt | Uma domain `televisao-{code}` por Card |
| Card VM | Compatible + orquestração + desktop/agente |
| Sandbox (Docker na guest) | Exclusive: mutation shard, pest, e2e, … |

Sandboxes **não** são VMs novas.

---

## Medição de economia

Antes: tempo de wall-clock do stack sequencial (colleague + gap + N× mutation paste).

Depois: mesmo card com fan-out; comparar wall-clock e pico de RAM guest
(`free`, `docker stats`, RSS do QEMU no host).

Piloto CLI já exercitado em `televisao-tv-190` (ver `HISTORICO.md`).
Orquestração automática a partir do `colleague-review.md` ainda é o
próximo passo de implementação — este arquivo é o contrato.
