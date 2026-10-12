# Histórico

Problema resolvido entra aqui.

Formato:

```
problema: o que acontecia
por que é um problema: o custo
resolvido como: o que foi feito e por que dessa forma
```

## `project-setup olie` morria no re-seed

- **problema:** `./project-setup.sh olie` falhava com OOM (256M) e `frame_max_limit_exceeded` no `FrameDataSeeder`
- **por que é um problema:** o `post-clone` sempre rodava `migrate --seed`; com frames já no MySQL o seeder repovoava tudo e o setup inteiro saía com exit 255
- **resolvido como:** seed só se não existir frame; re-run faz só `migrate --force`. No seed fresco, `memory_limit=1G`

## Pasta `workvm/` em volta de bin, lib, projects e systemd

- **problema:** `bin`, `lib`, `projects` e `systemd` ficavam dentro de `workvm/`
- **por que é um problema:** essa pasta existia para ser a raiz do Cursor. A janela já abre `~/git`, e o nível extra só alongava caminho
- **resolvido como:** as quatro pastas subiram para a raiz. `~/.config/workvm` e `workvm.service` continuam: são o projeto ativo nesta máquina, não um diretório do repo

## Docker do projeto não sobe após reboot

- **problema:** depois do login gráfico só o `cloudflared` voltava; backend/frontend/pgsql ficavam `Exited`; Cursor não abria
- **por que é um problema:** `workvm.service` faz o `docker compose up` e abre o Cursor, mas estava em `WantedBy=graphical-session.target`. SDDM + `start-hyprland` nunca ativam esse target. Tentativa de `systemctl --user start graphical-session.target` no Hyprland falha: o unit tem `RefuseManualStart`. O cloudflared tem `restart: unless-stopped`; os outros do compose têm `restart: no`
- **resolvido como:** `WantedBy=default.target` nos units WorkVM (sobe com a sessão do usuário). `project-start.sh` já espera Wayland. No `hyprland.start`, `systemctl --user start workvm.service` como rede de segurança com Wayland no ar

## Token literal no mcp.json do e2e quebrava o MCP

- **problema:** `olie-flow-ai` no Cursor dava 401; `~/.cursor/mcp.json` ficava com Bearer antigo
- **por que é um problema:** o merge do login restaura o `.cursor/mcp.json` do e2e e ele sobrescrevia `mcps/olie.json` (`${env:…}`) com um token commitado
- **resolvido como:** e2e só declara `playwright`; `olie-flow-ai` vem de `mcps/olie.json` + `OLIE_FLOW_AI_TOKEN` em `environment.d`

## Marker `mcp.workvm-user` do e2e aparecia no git

- **problema:** `projects/*/…/.cursor/mcp.workvm-user` ficava `??` no Source Control
- **por que é um problema:** o exclude usava `.cursor/mcp.workvm-user` (raiz do repo). No e2e o path é sob `projects/`, e `!projects/**` reabre tudo
- **resolvido como:** ignore versionado `projects/**/.cursor/mcp.workvm-user`; o stub passa a excluir pelo path relativo ao repo

## MCP de projeto começa desligado no Cursor

- **problema:** os `.cursor/mcp.json` dos roots (clones, e2e) abriam desligados; era preciso ligar à mão nas settings
- **por que é um problema:** opt-in de project MCP é por workspace e por hash da config — no multi-root e após mudança no arquivo o toggle some. Uma VM = um projeto, então o custo de tools extras no contexto é baixo
- **resolvido como:** no login, `workvm_apply_mcp` junta `mcps/<MCP>.json` + `.cursor/mcp.json` dos clones/e2e em `~/.cursor/mcp.json` (user-level, sem esse opt-in). Fontes versionados são relidos a cada subida. Nos de projeto fica stub local (`mcp.workvm-user`, `skip-worktree`) porque, com o mesmo nome, o Cursor prefere o de projeto — se ele estiver desligado, ganha do global

## MCP em pasta com `mcp.json`

- **problema:** cada MCP era `mcps/<nome>/mcp.json`
- **por que é um problema:** o arquivo não dizia com o que conecta, e a pasta em volta não acrescentava nada
- **resolvido como:** o arquivo fica na raiz de `mcps/` e o nome é o destino (`olie.json`). O setup/login promove para `~/.cursor/mcp.json` (antes ia só para `~/git/.cursor/mcp.json`)

## MCP dentro de `workvm/`

- **problema:** a definição do MCP ficava em `workvm/mcp/`
- **por que é um problema:** não é script da VM. Misturava com `bin` e `lib` uma pasta que vários projetos só nomeiam
- **resolvido como:** foi para `~/git/mcps/<nome>/`. O `project.conf` continua dizendo o nome, e o setup copia para `~/git/.cursor/mcp.json`

## `workvm/.cursor` e um `start.sh` por projeto

- **problema:** a janela abre `~/git`, mas as rules e a skill ficavam em `workvm/.cursor`, que essa raiz não carrega. Cada projeto ainda tinha um `start.sh` que era o mesmo symlink
- **por que é um problema:** o agente não via como a VM opera nem qual projeto está setado, e a pasta repetia um arquivo sem conteúdo próprio
- **resolvido como:** `meta-repo.mdc` e a skill `sync-git-dotconfig` foram para `~/git/.cursor`. O projeto ativo passa a ser gravado em `.cursor/rules/workvm-project.mdc`. O login chama `workvm/lib/project-start.sh` com o diretório de `current`

## Projetos aninhados só para compartilhar MCP

- **problema:** `olie` e `televisao` moravam em `workvm/projects/olie-ai/` porque o Cursor só lia o MCP da pasta-grupo. `da-o-play-api` ficava em `musicians-app/` pelo mesmo motivo
- **por que é um problema:** cada projeto novo virava pasta dentro de pasta, e a janela abria a empresa só para achar o `mcp.json`
- **resolvido como:** a definição foi para `workvm/mcp/<nome>/mcp.json` (sem token). O `project.conf` só diz `MCP=olie`. No setup e no login a cópia vai para `~/git/.cursor/mcp.json`, a raiz que o Cursor já abre. Os projetos ficaram planos (`olie`, `televisao`, `da-o-play-api`)

## Cursor abre só o workspace do projeto

- **problema:** o login abria `workspace.code-workspace` com a empresa, `workvm/` e os clones. O meta-repo `~/git` (prompts, rules da raiz) ficava fora dessa janela
- **por que é um problema:** para trabalhar no projeto setado era preciso outra janela neste repositório. O agente do app não via o prompt nem o histórico daqui
- **resolvido como:** a pasta `workvm` do workspace virou a raiz `~/git`. O `start.sh` continua abrindo o workspace do projeto setado, e essa janela inclui este repo. Empresa e clones seguem como roots, para o MCP e o `.cursor` de cada um

## Looking Glass e Sunshine no meta-repo

- **problema:** o repo versionava o vídeo da VM: kvmfr, attach na domain, Sunshine no guest e o encaminhamento de portas
- **por que é um problema:** esse caminho não vai ser usado agora. Quem abre o script segue um setup que fica para outro dia
- **resolvido como:** saíram `host-looking-glass-kvmfr-setup.sh`, `vm-looking-glass-kvmfr-attach.sh`, `guest-looking-glass-setup.sh`, `guest-sunshine-setup.sh` e `vm-sunshine-ports.sh`

## Seis `start.sh` ainda iguais

- **problema:** depois de extrair a subida, cada `start.sh` repetia o mesmo laço até achar `project-start.sh`. Só o comentário mudava
- **por que é um problema:** um ajuste nesse laço tinha de ser copiado nos seis. O login gráfico chama `current/start.sh`, então o arquivo precisava continuar existindo em cada projeto
- **resolvido como:** `start.sh` virou symlink para `workvm/lib/project-start.sh`. Sem argumento, o script usa o diretório de quem foi chamado (`pwd -P` resolve o symlink `current/`). Clones, compose e e2e continuam no `project.conf`

## Overlay em `files/` separado do projeto

- **problema:** `files/olie/` era uma árvore paralela a `workvm/projects/olie-ai/olie`. Os dois descreviam o mesmo projeto
- **por que é um problema:** o delta de Cursor ficava longe do `project.conf`, do compose e do e2e. Quem mexia num não via o outro
- **resolvido como:** o overlay foi para `workvm/projects/olie-ai/olie/overlay/`. A pasta se chama `cursor/` e só na cópia para `~/git/olie/` vira `.cursor`, para o workspace que abre `workvm/` não carregar essas rules de produto. `files/` saiu

## SR-IOV da iGPU versionado no meta-repo

- **problema:** o setup da VF da iGPU estava no repo: scripts de host e guest, bind vfio, drop-in do Limine, unit systemd e `workvm/docs/igpu-sriov.md`
- **por que é um problema:** essa implementação não é o caminho desta VM agora. Quem abre o doc ou o script segue um setup que ainda não vai ser usado
- **resolvido como:** esses arquivos saíram. Looking Glass (kvmfr) e Sunshine ficam. O SR-IOV volta quando for a hora de implementar de novo

## Listas `TASKS.md` e `tasks.md` vazias

- **problema:** as duas listas estavam com todos os itens marcados e só apontavam uma para a outra
- **por que é um problema:** o agente abria um backlog encerrado para achar o que fazer. O relato já está em `HISTORICO.md`
- **resolvido como:** os dois arquivos saíram. O que foi feito continua neste histórico

## Pós-clone Laravel copiado

- **problema:** `boilerplate-laravel/post-clone.sh` e `vid2agent-code/post-clone.sh` repetiam o mesmo bootstrap: `.env`, UID do volume e `compose.dev.yaml`
- **por que é um problema:** um ajuste no migrate ou no `.env` ficava num projeto e o outro seguia quebrando do jeito antigo
- **resolvido como:** o corpo foi para `workvm/lib/laravel-post-clone.sh`, que recebe o caminho do app. Cada `post-clone.sh` só acha o helper e passa o diretório do clone. O migrate sobe `postgres` e `redis` antes, porque o artisan precisa resolver o host `postgres` na rede do compose

## `common.sh` com git, Cursor e sessão juntos

- **problema:** `workvm/lib/common.sh` tinha cerca de 860 linhas misturando clone, patch de Cursor, Docker, Wayland e merge de JSON
- **por que é um problema:** achar uma função exigia ler o arquivo inteiro. Uma mudança de fetch passava pelo código que abre o browser
- **resolvido como:** o corpo foi para `git.sh`, `cursor.sh` e `session.sh`. `common.sh` só dá `source` nos três, na mesma ordem, então quem já carregava `common.sh` continua vendo as mesmas funções. `workvm_discover_repo_root` segue procurando `common.sh` para achar a raiz do meta-repo

## Sem shellcheck nos scripts

- **problema:** os `*.sh` não passavam por checagem. Com `set -u`, um array que o `project.conf` não declara derruba a subida, e o log do compose omitia `COMPOSE_FILE` mesmo quando o conf definia
- **por que é um problema:** o login gráfico roda `start.sh`. Um array vazio ou um `-f` faltando só aparece quando a sessão já subiu, e cada projeto logava o compose de um jeito
- **resolvido como:** `workvm/bin/check.sh` roda shellcheck nos scripts versionados e, com stubs, sobe `workvm_project_start` sem Docker nem Cursor. O conf sem arrays não pode estourar; o log tem de citar `-f` quando `COMPOSE_FILE` existe; o e2e não herda esse arquivo. `vm-setup.sh` instala o `shellcheck`. Os avisos que o check já pegava (variável morta, `A && B || C`, `export` com comando) foram corrigidos no próprio script

## E2E dentro das pastas de clone

- **problema:** `olie/olie-e2e` e `televisao/*-e2e` só entravam no git porque o `.gitignore` reabria `olie/` e `televisao/` no meio de um repo que ignora o resto dos clones
- **por que é um problema:** esses testes não podem ir para o remoto da empresa. Foram feitos aqui para o card ser verificado no browser sem passar a mão. Do jeito antigo, o caminho parecia clone de produto e o ignore precisava de uma exceção só para eles
- **resolvido como:** as três suítes foram para `workvm/projects/olie-ai/olie/olie-e2e` e `workvm/projects/olie-ai/televisao/*-e2e`, que já são versionados com o meta-repo. As exceções `!olie/` e `!televisao/` saíram. Compose, workspace, prompts e a rule do `olie-fronts` apontam para o caminho novo. `.env` das suítes continua fora do git

## Skills do Laravel Boost dentro de `files/olie/`

- **problema:** `files/olie/api-main/.cursor/skills/` versionava `laravel-best-practices`, Horizon, Pest, Octane e as outras skills do Boost
- **por que é um problema:** o README do api-main manda regenerar isso com `boost:update`. O overlay é aplicado com `rsync` por cima do clone, então a cópia congelada aqui diverge da que o Boost gera
- **resolvido como:** essas pastas saíram do overlay. Ficam as rules Olie, as skills `olie-project-*`, o `mcp.json` e o README. O Boost volta a existir só depois de `boost:update` no clone

## Workspace com `/home/fabricio/git`

- **problema:** os `workspace.code-workspace` apontavam para `/home/fabricio/git/...`
- **por que é um problema:** outro usuário ou outro `GIT_ROOT` abre a janela e as pastas não existem
- **resolvido como:** cada `path` ficou relativo ao próprio arquivo `.code-workspace`. O Cursor resolve a partir dali, então `workvm` e os clones acompanham o meta-repo sem gravar o home

## Duas tabelas do que cada pasta faz

- **problema:** `layout.mdc`, `workvm/.cursor/rules/meta-repo.mdc` e o `README.md` repetiam a lista de pastas e scripts
- **por que é um problema:** um caminho muda num arquivo e o outro fica velho. O agente segue a cópia errada
- **resolvido como:** a tabela caminho → problema ficou só em `layout.mdc`. `meta-repo.mdc` guarda o como (projeto ativo, workspace, patch de clones, token do MCP) e aponta para o mapa, sem copiá-lo. O `README.md` também só aponta. Cada rule abre dizendo o que não repetir

## `tasks.md` e `TASKS.md` ao mesmo tempo

- **problema:** `tasks.md` era uma segunda lista, com tudo marcado, e citava `workvm/projects/olie` e `workvm/projects/televisao`
- **por que é um problema:** esses diretórios não existem mais (hoje `olie-ai/olie` e `olie-ai/televisao`). Quem abre o arquivo acha caminho velho ou trata checklist concluído como trabalho aberto
- **resolvido como:** `tasks.md` ficou só como checklist encerrado, com uma linha no topo para `TASKS.md` e `HISTORICO.md`, e os dois caminhos corrigidos. Item novo entra em `TASKS.md`; o porquê de cada um resolvido entra em `HISTORICO.md`

## Nome e e-mail dentro do `vm-setup.sh`

- **problema:** `vm-setup.sh` trazia o usuário da VM e o e-mail do git como valor padrão. `host-looking-glass-kvmfr-setup.sh` repetia o mesmo usuário quando não havia `SUDO_USER`
- **por que é um problema:** o nome fica no histórico do git, e outra máquina não reusa o script sem editar código
- **resolvido como:** a identidade foi para `vm.local.conf`, que o git ignora. O versionado é `vm.local.conf.example`, só com as chaves. `workvm_load_vm_local` lê o arquivo; variável já exportada no ambiente não é sobrescrita. O kvmfr usa `SUDO_USER` como dono de `/dev/kvmfr0` e só cai no conf se o script rodar como root sem sudo

## Looking Glass em `/dev/shm`

- **problema:** `vm-looking-glass-attach.sh` gravava IVSHMEM em `/dev/shm/looking-glass`, e `workvm/host/tmpfiles.d/10-looking-glass.conf` criava esse arquivo. No mesmo host, `vm-looking-glass-kvmfr-attach.sh` apagava esse shmem da domain
- **por que é um problema:** com a VF da iGPU, o QEMU falha com `vfio: DMA mapping failed` e a VM não sobe. Dois scripts faziam a mesma coisa de jeitos incompatíveis
- **resolvido como:** o script de shmem e o tmpfiles que criava `/dev/shm/looking-glass` foram apagados, não marcados como obsoletos. O caminho que fica é kvmfr (`host-looking-glass-kvmfr-setup.sh` + `vm-looking-glass-kvmfr-attach.sh`, client em `/dev/kvmfr0`). O attach kvmfr continua removendo um `<shmem name='looking-glass'>` que já esteja na domain, porque uma VM antiga pode ter sido configurada pelo script removido. `guest-looking-glass-setup.sh` e `workvm/docs/igpu-sriov.md` apontam só para kvmfr

## Seis `start.sh` iguais

- **problema:** cada projeto em `workvm/projects/` tinha o próprio `start.sh` com a mesma subida (achar o repo, fetch, overlay, Wayland, compose, Cursor, browser). Televisão ainda copiava um laço de compose de e2e
- **por que é um problema:** um ajuste (timeout, compose opcional, env do MCP) precisava ser repetido nos seis arquivos e algum ficava para trás
- **resolvido como:** a sequência foi para `workvm/lib/project-start.sh`. O `start.sh` de cada projeto só localiza esse arquivo e chama `workvm_project_start`. Clones, URLs, `COMPOSE_DIR` e `E2E_COMPOSE_DIRS` continuam no `project.conf` — a diferença é dado, não código. O e2e sobe sem herdar `COMPOSE_FILE` do app (`compose.dev.yaml` não existe na pasta do Playwright). `~/.config/environment.d` segue garantido dentro de `workvm_open_cursor`, então a chamada extra que só a Televisão fazia saiu

## Senha ao instalar

- **problema:** ficar digitando senha na VM para instalar pacote
- **por que é um problema:** perde tempo a cada `sudo`
- **resolvido como:** `setup_passwordless` em `vm-setup.sh` grava `/etc/sudoers.d/<usuário>` com `NOPASSWD: ALL`. O sudoers vem antes do resto do setup para o próprio script não pedir senha de novo

## Senha do usuário

- **problema:** a VM pedia a senha do usuário
- **por que é um problema:** perde tempo no login e no setup
- **resolvido como:** o mesmo `setup_passwordless` roda `passwd -d`. Senha vazia, não outra senha gravada no repo

## Copiar do host para a VM

- **problema:** texto copiado no host não cola na VM
- **por que é um problema:** perde tempo redigitando entre host e guest
- **resolvido como:** `setup_clipboard` instala `spice-vdagentd` e o binário `wayland-vdagent`. O agente clássico do SPICE não cola no Hyprland (Wayland), então o autostart em `.config/hypr/hyprland.lua` sobe `/usr/local/bin/wayland-vdagent` e o serviço de usuário `spice-vdagent` fica mascarado

## Tela de login

- **problema:** toda vez que a VM liga aparece o login
- **por que é um problema:** perde tempo antes de começar a trabalhar
- **resolvido como:** `setup_autologin` grava `/etc/sddm.conf.d/autologin.conf` (`User`, `Session=hyprland`, `Relogin=true`) e liga o SDDM. Depende da senha vazia; sem isso o autologin para no greeter

## Clonar os repositórios

- **problema:** criar pasta e clonar cada repo do GitHub na mão
- **por que é um problema:** cada VM nova repete os mesmos clones e a branch errada quebra o compose
- **resolvido como:** `workvm/projects/<id>/project.conf` lista `CLONE_REPOS` (`url`, caminho, branch). `project-setup.sh` chama `workvm_clone_project_repos`. A lista fica no projeto, não espalhada no script

## Cursor e browser ao ligar a VM

- **problema:** ao iniciar a VM os repos não abrem no Cursor e o browser não abre
- **por que é um problema:** o dia começa montando o ambiente na mão
- **resolvido como:** `project-setup.sh` aponta `~/.config/workvm/current` para o projeto e liga `workvm.service`. No login gráfico o service roda `current/start.sh`, que abre o workspace e o Chromium. O service espera a sessão gráfica porque, sem Wayland, o Cursor abre no vazio
