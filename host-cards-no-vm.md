# Cards / projetos no host (sem WorkVM)

Problema: cada card (Olie, Televisão, Locav) ou projeto sem card (Opbed) hoje é uma **domain libvirt**. No host de 32 GiB isso limita quantos mundos vivos cabem — a guest paga OS + Hyprland + Cursor + compose. Os **sandboxes** (`bin/workvm-sandbox`) já isolam jobs exclusive **dentro** da VM sem clonar outra domain; a ideia é subir o **card** (ou o projeto) para o mesmo modelo de isolamento **no jarvis**, sem QEMU.

Branch: `experiment/host-cards-no-vm`. Isto é **checklist de requisitos**, não implementação. Enquanto a lista não estiver atendida, a WorkVM continua a fonte da verdade.

## Objetivo

Rodar **N cards de N projetos** ao mesmo tempo no host, **sem colisão**, com **uma janela Cursor por card** (ou por projeto, no Opbed), e **destroy** tão definitivo quanto dropar a domain hoje.

## O que a VM compra hoje (e o host tem que substituir)

| Na WorkVM | Equivalente obrigatório no host |
| --- | --- |
| Namespace de rede / portas | Portas e DNS **por card** (não `api.olie.localhost` global compartilhado) |
| Daemon Docker “só deste mundo” | `COMPOSE_PROJECT_NAME` + redes/volumes prefixados (já no sandbox) |
| Disco descartável da domain | Worktree + estado sob path por card; `destroy` apaga tudo |
| Sessão mental / Cursor | Um `.code-workspace` (e janela) por card ou projeto |
| Isolamento “cego” | Política + automação; falha de limpeza = colisão |

Token MCP / `gh` da **mesma** conta **não** precisam de isolamento entre cards do mesmo ecossistema. O que pode colidir é o **alvo** do MCP (qual container / compose), não o Bearer.

## Unidades

| Produto | Unidade viva no host |
| --- | --- |
| Olie, Televisão, Locav | **Card** (ex. `olie-dop-1165`) |
| Opbed (e similares sem card) | **Projeto** (`opbed`) |

Card e projeto sem card seguem o **mesmo contrato** de create / list / destroy; só muda o id.

## Requisitos (tem que atender)

### 1. Card = sandbox “gordo”, não pasta solta

- Worktree (ou árvore) **exclusiva** por id de card/projeto.
- Compose com `COMPOSE_PROJECT_NAME` derivado do id (padrão do `lib/sandbox/`).
- Proibido dois cards reutilizarem o stack “oficial” da VM (`olie-api-main`, nomes fixos do `project.conf` atual) no mesmo host sem namespacing.

### 2. Portas e DNS por card

- Base de portas estável por id (hoje: `workvm_sandbox_port_base` → faixa 20000+).
- DNS Olie (implementado): slug = código normalizado (`DOP-1183` → `dop-1183`):
  - Front: `http://devframe.{slug}.olie.localhost`
  - API: `http://api.{slug}.olie.localhost`
  - `.localhost` → loopback; Caddy (`workvm-host-card-proxy`, `network_mode: host`, porta `WORKVM_HOST_CARD_PROXY_PORT` default **80**) roteia pelo `Host`.
- Fallback direto: `http://127.0.0.1:{port_base}` (API) e `:{port_base+1}` (Vite).
- `WAIT_URL` / `CHROMIUM_URLS` do `project.conf` (VM) ainda usam DNS global da guest.

### 3. Destroy = dropar a domain

`destroy <id>` (ou equivalente) remove, no mínimo:

- containers do compose do card  
- redes Docker com o prefixo do projeto  
- volumes criados por esse compose (se o contrato for descartável)  
- worktree / metadados em `~/.local/share/workvm/…`  
- workspace Cursor órfão (arquivo), se foi gerado  

Sem destroy automático confiável, a política de limpeza manual **não** basta para o requisito N×N.

### 4. Uma janela Cursor por unidade

- Abrir `cursor <workspace-do-card-ou-projeto>` (mesmo espírito de `workvm_open_cursor`).
- Janelas distintas isolam chat/foco; **não** isolam sozinhas `~/.cursor/mcp.json` — ver §5.

#### Worktrees e workspace (contrato)

**Alvo:** um **git worktree por repositório por card**, mais um worktree do
meta-repo `~/git`. O `.code-workspace` do card abre **só** esses worktrees
(nenhum clone “pai” / `(shared)` só para o SCM).

| Fase | O quê |
| --- | --- |
| **Hoje (Olie)** | Worktree de **todos** os `CLONE_REPOS` + meta-repo `~/git` por card; workspace **só** esses paths (sem `(shared)`). `vendor` / `node_modules` via reflink (btrfs) ou rsync a partir da base em `~/git/olie/…`. Compose monta worktree `api-main` + `olie-fronts` + e2e do meta worktree. **Dados:** 1× MySQL/Redis/Mongo compartilhados (`hc-olie-data`, imagens ≈ `docker-workspace`); por card só `api_<slug>` / `testing_<slug>` / `REDIS_PREFIX`. |
| **Hoje (todo projeto)** | Meta-repo `worktree/git` em **todo** host-card (Opbed, boilerplate, use-url-query, Locav, Televisão, …). Workspace nunca aponta o `~/git` ao vivo — evita dirty cruzado entre janelas. Clones de produto nos sem-card continuam shared até haver worktree por repo. |
| **Depois** | Restringir worktree aos repos **prováveis** do card (não o fan-out inteiro). Lista/heurística TBD. |
| **Mais tarde** | Polir isolamento `vendor` / `node_modules` (golden, skip yarn no front se já copiado, etc.). |

Regras estáveis:

- No `ensure`, se já existir branch local/remota cujo nome contém o código do
  card (ex. `feature/DOP-1273-…`), o worktree desse repo faz checkout nela; os
  clones sob `~/git/<projeto>/…` e o `~/git` “ao vivo” ficam na branch base
  (ex. `develop` / `main`) e não são roots do workspace do card.
- A mesma branch git só pode estar checked out em **um** worktree — cards em
  paralelo usam cada um a sua `feature/…` (ou detached), não todos em `develop`.
- Compose / Pest no Olie já montam o worktree + vendor do card; os demais
  projetos seguem o mesmo espírito quando ganharem hook.
- Playwright privado: gravar só na pasta **`olie-e2e` do workspace** (meta
  worktree do card). `~/git/olie/olie-e2e` fica fora da janela e dispara
  aprovação de escrita; ensure injeta rule `host-card-e2e-path.mdc`.

### 5. MCP: roteamento, não token por janela

- Tokens compartilhados (Olie MCP, management, `gh` da mesma conta) são **ok** entre cards.
- O merge user-level (`~/.cursor/mcp.json`) precisa de servidores cujo **comando/URL** acerte o stack do card (Boost/`docker exec` no container certo), ou de um wrapper que resolva o id do card ativo.
- Isolar token/conta só quando houver **dois empregadores / identidades** diferentes — fora do escopo mínimo desta ideia.

### 6. Teto de concorrência (RAM / CPU) e MySQL do Pest

- Por padrão o compose do host-card **não** põe `cpus`/`mem_limit`: os containers
  disputam o host (CFS). Sandbox slim na Card VM continua com teto (1 g / 1 CPU).
- Teto opcional no host: `WORKVM_HOST_CARD_MEM=2g` e/ou `WORKVM_HOST_CARD_CPUS=2`
  no ambiente antes do ensure.
- Pest `--parallel` no jarvis (24 threads) ≠ WorkVM (9 vCPUs): o gargalo é **um**
  MySQL × N workers. **Teto de workers = 22** em `bin/workvm-host-card-pest`
  (`min(nproc, 22)` desde 2026-11-16): com 23+ o Paratest morre em SIGSEGV
  (exit 139). Override: `WORKVM_HOST_CARD_PEST_PROCESSES`. O host-card aplica
  `compose.mysql-host.yml` (sem binlog,
  fsync relaxado, buffer ~4 GiB, datadir em **tmpfs**, DBs `testing_test_1..32`
  pré-criados). Ajustes: `WORKVM_HOST_CARD_MYSQL_BUFFER`, `_MAX_CONN`, `_TMPFS`.
- 32 GiB: N cards com Cursor + compose completo ainda estouram sem **MAX** de
  cards vivos (espírito de `WORKVM_SANDBOX_MAX`) — isso é limite de quantos
  sobem, não cgroup por container.
- Medir pico: RSS do Cursor × N + `docker stats`; decidir slim vs compose “de login”.

### 7. Jobs exclusive continuam em sandbox filho

- Mutation / Pest / e2e que escrevem no mesmo DB **não** rodam no stack “principal” do card em paralelo sem shard.
- Reusar `workvm-sandbox` (backend container) **em cima** do card no host — a orquestração em `*/sandbox/ORCHESTRATION.md` permanece; só muda o chão (guest → jarvis).

### 8. Card-agent / liberação de VM

- Hoje o site sobe domain `projeto-codigo` via `workvm-ensure-card-vm` / `workvm-card-agent`.
- No modo host: create do card no jarvis (sem `virsh`), SSH/agente apontando para o workspace local — **ou** fase 1 só manual (sem agent) até o contrato create/destroy estabilizar.
- Não misturar: card vivo na VM **e** no host para o mesmo código sem regra clara.

### 9. Aceite (definição de pronto da ideia)

1. Dois cards Olie + um card Televisão + Opbed sobem no host sem compartilhar porta/DNS/DB.  
2. Cada um tem sua janela Cursor; chats não misturam roots.  
3. `destroy` de um card não derruba os outros.  
4. Um exclusive (mutation) roda em sandbox filho sem corromper o MySQL do card irmão.  
5. Pico de RAM documentado e abaixo do teto escolhido (melhor que 1 WorkVM “cheia” por card).

## Fora de escopo (por enquanto)

- Apagar WorkVMs / libvirt do meta-repo.  
- Isolamento multi-conta GitHub / multi-emprego (dúvida em `life.md`).  
- Substituir o desktop Hyprland do host por sessão por card.  
- Jogo / passthrough GPU (outro tema; branch `docs/rtx3060-win11-passthrough`).

## Relação com o que já existe

| Peça | Papel nesta ideia |
| --- | --- |
| `bin/workvm-sandbox` + `lib/sandbox/` | Prova de N stacks no mesmo OS (portas + compose name) |
| `olie/sandbox/`, `televisao/sandbox/` | Compose slim + `ORCHESTRATION.md` — reusar no host |
| WorkVM / `config-vm.xml` | Continua válida até o aceite §9; otimizar RAM da guest é plano paralelo em `life.md` |
| `host-cards-no-vm.md` (este arquivo) | Lista do que falta para a ideia valer |

## Contrato dos prompts trigger

Triggers que **montam** o ambiente no início (idempotente — multi-dia = resume):

| Prompt | Projeto |
| --- | --- |
| `implementation.md` | olie / locav / televisao |
| `correction.md` | idem |
| `colleague-review.md` | idem |
| `production-review.md` | idem |

Regra compartilhada: secção **Host card environment** em cada `*/prompts/workflow-policy.md`.

```bash
~/git/bin/workvm-host-card ensure  --project <olie|locav|televisao> --code '{{ code }}'
~/git/bin/workvm-host-card destroy --project <olie|locav|televisao> --code '{{ code }}'
```

No chat do Cursor, `ensure`/`destroy` precisam de shell **unrestricted**
(`required_permissions: ["all"]`): gravam `~/.cursor/mcp.json` e estado em
`~/.local/share/workvm/host-cards/`. `PermissionError` nesse path (e DNS/`gh`
falsos) é sandbox do agente, não chmod — ver **Host card environment** nos
`workflow-policy.md` e allow em `.cursor/permissions.json`.

| Momento | Ação |
| --- | --- |
| Início de qualquer trigger acima | `ensure` **antes** de git/stage/review pesado |
| Fim de um dia / fechar o chat | **não** destroy — o estado fica |
| Card em `done` / 'concluído' (ex. production-review Pass + yes) | `destroy` depois do move confirmado |
| Chat `finish card` / `finalize card` | `destroy` + clones → branch base; **não** fecha Cursor (usuário fecha à mão após o hint) |
| Colleague-review / correction terminam o paste | **não** destroy — o card ainda vive no funil |

Não misturar domain libvirt do mesmo código com host-card sem regra explícita.

## CLI

`bin/workvm-host-card` + `lib/host-card.sh`: estado em
`~/.local/share/workvm/host-cards/<project>/<id>/`, workspace
`<project>/<id>.code-workspace`, `port_base` estável.

Hooks (compose slim + Cursor):

| Projeto | ensure | destroy |
| --- | --- | --- |
| olie | `olie/sandbox/host-card-ensure.sh` — compose slim seletivo via `meta.stack_groups`: `back`=`app`; `front`=`http`+Vite+`olie-e2e` (infere na 1ª abertura; `add --group` / `--groups`). DNS `api.{slug}.olie.localhost` / `devframe.{slug}.olie.localhost` via Caddy (`lib/host-card-proxy.sh`). Pest: `bin/workvm-host-card-pest`. Playwright MCP → `hc-*-olie-e2e-1` (só com front) | `host-card-destroy.sh` — `compose down -v` + reload proxy |
| televisao | `televisao/sandbox/host-card-ensure.sh` — `compose.host.yml` (pgsql + Laravel + Next); DNS `api|devframe.{slug}.olie.localhost` | idem |
| opbed | `opbed/sandbox/host-card-ensure.sh` — `compose.host.yml` (pgsql + Laravel + Next); unidade projeto `--code opbed`; DNS `api|devframe.opbed.olie.localhost` | `host-card-destroy.sh` |
| locav | ainda sem hook compose (só workspace/estado) | genérico |

`WORKVM_HOST_CARD_OPEN_CURSOR=0` pula abrir o Cursor. Default: abre
`<id>.code-workspace` com `cursor --new-window`. No Olie, a pasta `api-main`
do workspace é o **worktree do card** (não o clone compartilhado), para o
agente editar in-workspace o mesmo path que o compose monta. Transição:
ver §4 — worktree de todos os repos + meta-repo; depois só os prováveis;
`vendor` / `node_modules` depois.

`ensure` faz **clone/pull** dos `CLONE_REPOS` do `project.conf` (igual à
WorkVM: fronts, backoffice, landing, …) e monta o workspace só com os
roots que existem (mesma lista do `workspace.code-workspace` do projeto).
Clones sob `~/git/<projeto>/` continuam a fonte dos `git worktree add`; o
workspace do card deve apontar para `state_dir/worktree/…`, não para esses
clones (alvo §4).

Mutation/Pest exclusive **continuam** em `workvm-sandbox` filho (worktree
detach) — o host-card não substitui o shard.

## Ordem sugerida de ataque

1. ~~Formalizar id + port_base~~ (CLI `ensure`).  
2. ~~Hook compose slim (Olie + Televisão)~~ + Cursor no ensure.  
3. Hook Locav (quando houver compose slim).  
4. ~~**Worktree de todos os `CLONE_REPOS` + meta-repo `~/git` por card** (Olie)~~; workspace só esses paths; sem `(shared)`.  
5. Restringir worktree aos repos **prováveis** do card (heurística TBD).  
6. Polir `vendor` / `node_modules` (golden / skip install redundante).  
7. Segundo card em paralelo (smoke de colisão).  
8. Sandbox filho (mutation) em cima do card host.  
9. ~~Opbed como unidade projeto (`--project opbed`)~~ + compose host.  
10. Desligar Card VM no agent quando §9 estiver verde.
