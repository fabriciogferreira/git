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
- Roots do workspace apontam meta-repo + clones compartilhados (edição).
- **Runtime Olie:** cada card tem `state_dir/worktree/api-main` (git worktree) +
  `state_dir/vendor` (rsync do vendor). Compose/`Pest -p` usam esses paths —
  dois cards podem rodar a suite em paralelo sem corromper o clone.
- Janelas distintas isolam chat/foco; **não** isolam sozinhas `~/.cursor/mcp.json` — ver §5.

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
  MySQL × N workers. O host-card aplica `compose.mysql-host.yml` (sem binlog,
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

| Momento | Ação |
| --- | --- |
| Início de qualquer trigger acima | `ensure` **antes** de git/stage/review pesado |
| Fim de um dia / fechar o chat | **não** destroy — o estado fica |
| Card em `done` / 'concluído' (ex. production-review Pass + yes) | `destroy` depois do move confirmado |
| Chat `finish card` / `finalize card` | `destroy` + fecha janela Cursor + clones compartilhados → branch base (`develop`/…) (não mexe no board) |
| Colleague-review / correction terminam o paste | **não** destroy — o card ainda vive no funil |

Não misturar domain libvirt do mesmo código com host-card sem regra explícita.

## CLI

`bin/workvm-host-card` + `lib/host-card.sh`: estado em
`~/.local/share/workvm/host-cards/<project>/<id>/`, workspace
`<project>/<id>.code-workspace`, `port_base` estável.

Hooks (compose slim + Cursor):

| Projeto | ensure | destroy |
| --- | --- | --- |
| olie | `olie/sandbox/host-card-ensure.sh` — compose slim + Vite front + `olie-e2e` (`compose.e2e-host.yml`); DNS `api.{slug}.olie.localhost` / `devframe.{slug}.olie.localhost` via Caddy (`lib/host-card-proxy.sh`). Pest: `bin/workvm-host-card-pest`. Playwright MCP → `hc-*-olie-e2e-1` | `host-card-destroy.sh` — `compose down -v` + reload proxy |
| televisao | `televisao/sandbox/host-card-ensure.sh` — `compose.host.yml` (pgsql + Laravel + Next); DNS `api|devframe.{slug}.olie.localhost` | idem |
| locav | ainda sem hook compose (só workspace/estado) | genérico |

`WORKVM_HOST_CARD_OPEN_CURSOR=0` pula abrir o Cursor. Default: abre
`<id>.code-workspace` com `cursor --new-window`. No Olie, a pasta `api-main`
do workspace é o **worktree do card** (não o clone compartilhado), para o
agente editar in-workspace o mesmo path que o compose monta.

`ensure` faz **clone/pull** dos `CLONE_REPOS` do `project.conf` (igual à
WorkVM: fronts, backoffice, landing, …) e monta o workspace só com os
roots que existem (mesma lista do `workspace.code-workspace` do projeto).

Mutation/Pest exclusive **continuam** em `workvm-sandbox` filho (worktree
detach) — o host-card não substitui o shard.

## Ordem sugerida de ataque

1. ~~Formalizar id + port_base~~ (CLI `ensure`).  
2. ~~Hook compose slim (Olie + Televisão)~~ + Cursor no ensure.  
3. Hook Locav (quando houver compose slim).  
4. Segundo card em paralelo (smoke de colisão).  
5. Sandbox filho (mutation) em cima do card host.  
6. Opbed como unidade projeto (`--project opbed`).  
7. Desligar Card VM no agent quando §9 estiver verde.
