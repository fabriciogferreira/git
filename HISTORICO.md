# Histórico


## Pest TIA: owned repos vs empresa

- **problema:** TIA ajuda em suites grandes; `Pest.php` + `/.pest/` precisa de commit — ok em repos próprios, impossível em Olie/Locav/Televisão.
- **por que é um problema:** patch local em clone da empresa suja o worktree; sem `--ci` a regressão full-suite encolheria.
- **resolvido como:** **próprios** (`boilerplate-laravel`, `opbed-backend`): `pest()->tia()->locally()` + `directory('.pest/tia')`, `/.pest/` no `.gitignore`, `git` na imagem CLI. **Empresa:** sem tocar `Pest.php`; `PEST_TIA_LOCALLY=1` só no compose sandbox do meta + `git` nas imagens sandbox do meta. Gates de regressão passam `--ci`.

## boilerplate-laravel: PCOV na imagem do sandbox (não no Card)

- **problema:** host-card/`compose.host.yml` buildava `boilerplate-laravel-workspace:sandbox` com `XDEBUG_ENABLED=false` e sem PCOV; Pest `--mutate` / `--coverage` exigem Xdebug 3+ ou PCOV. O Card (compose.dev) já tinha Xdebug — mexer no Dockerfile do clone era escopo errado.
- **por que é um problema:** o caminho oficial (exclusive) é `workvm-sandbox`; sem driver na tag `:sandbox` mutation/coverage quebram. Xdebug no Card basta para smoke, mas line coverage com Xdebug é bem mais lento que PCOV (Bergmann: ~53s vs ~19s na mesma suite — ~2,8×; mutation multiplica o custo do driver).
- **resolvido como:** `sandbox/Dockerfile.workspace` + `workvm_sandbox_bl_ensure_sandbox_image` no create (PCOV só na tag `:sandbox`). Card/Dockerfile do clone intactos. Preferência PCOV nos sandboxes documentada com [PCOV or Xdebug?](https://phpunit.expert/articles/pcov-or-xdebug.html) (números de line coverage; Pest aceita os dois).

## Opbed: prompts sem card / PR (pre-deploy)

- **problema:** prompts Olie-style (card, colleague review, pre-QA/PR) não batem com o Opbed — não há cards nem PR; push em `main` já faz deploy.
- **por que é um problema:** o agente abre funil/PR/host-card e atrasa o fluxo real (implementar → gates → commit → produção).
- **resolvido como:** `opbed/prompts/` com `implementation` / `correction` / `production-review` / `pre-deploy` (+ mutation/coverage); `{{ feature }}` no lugar de `{{ code }}`; sync `config.prompts` projeto 7.

Problema resolvido entra aqui.

## Projeto fabriciogferreira (portfólio Next)

- **problema:** o meta não listava o portfólio pessoal; sem `project.conf`/prompts/sandbox o setup e o host-card não existiam.
- **por que é um problema:** clone manual fora do fluxo WorkVM/host-card; sem gates pre-deploy alinhados aos outros projetos sem card.
- **resolvido como:** `fabriciogferreira/` com conf + post-clone (`.env`), prompts (`{{ feature }}`, Vercel), sandbox Node + host-card Next; CLI/manager/gitignore/layout.

## Host-card: meta worktree `git` em todos os projetos

- **problema:** só Olie criava `worktree/git`; Opbed/boilerplate/use-url-query/Locav/Televisão abriam o `~/git` ao vivo no `.code-workspace`.
- **por que é um problema:** N janelas Cursor no jarvis viam o mesmo dirty do meta-repo (prompts, HISTORICO, sandbox) umas das outras.
- **resolvido como:** `ensure` chama `add_meta_worktree` para todo projeto; `bind_workspace_worktree` aponta `git` (+ `prompts`) ao worktree do card; `destroy` remove o meta worktree (helper compartilhado).

## use-url-query: prompts + sandboxes (estilo Opbed/boilerplate)

- **problema:** o meta só tinha `project.conf`/workspace; sem prompts pre-deploy nem `workvm-sandbox --project use-url-query`.
- **por que é um problema:** coverage/bun test no `container_name` fixo do Card; fluxo de feature sem prompts alinhados (sem card/PR, push em `main`).
- **resolvido como:** `use-url-query/prompts/` (`{{ feature }}`; mutation N/A); `use-url-query/sandbox/` (slim bun + host-card, sem DB); CLI/manager aceitam o projeto; `.gitignore` libera prompts/sandbox; `COMPOSE_FILE=docker-compose.yml` no conf.

## boilerplate-laravel: prompts + sandboxes (estilo Opbed)

- **problema:** o meta só tinha `project.conf`/post-clone; sem prompts pre-deploy nem `workvm-sandbox --project boilerplate-laravel`, mutation/coverage não tinham isolamento.
- **por que é um problema:** mesmo atrito do Opbed antes do sandbox — Pest no Postgres do Card; fluxo de feature sem prompts alinhados (sem card/PR, push em `main`).
- **resolvido como:** `boilerplate-laravel/prompts/` (`{{ feature }}`); `boilerplate-laravel/sandbox/` (slim + `hc-boilerplate-laravel-data` + testing-db-cache + host-card); CLI/manager aceitam o projeto; `.gitignore` libera prompts/sandbox.

## Opbed: sandboxes para mutation/coverage

- **problema:** `pest --mutate` / coverage no Card Opbed usavam o mesmo Postgres `opbed_local` do compose namespaced; um mutate órfão corrompia migrations e derrubava a suite.
- **por que é um problema:** N jobs exclusive no mesmo DB/compose; sem workvm-sandbox `--project opbed` o agente só tinha `docker exec hc-opbed-…-backend-1`.
- **resolvido como:** `opbed/sandbox/` estilo Locav (`project.sh`, slim, `hc-opbed-data`, testing-db-cache, ORCHESTRATION); CLI `workvm-sandbox` aceita `opbed`; job default `backend`; prompts `opbed/prompts/` com drain + subagentes. Mutation/coverage proibidos no backend do Card.

## Correction: não fechar review no GitHub antes das validações

- **problema:** o `correction.md` pedia Resolve de threads + audit comment no body (e o agente tratava commit/push/audit como fim do paste) **antes** de `implementation-validation` (e da cadeia gap → coverage → mutation → Pest → pre-qa).
- **por que é um problema:** marcar “resolvido” no PR sem as validações dá falsa segurança ao revisor; o tip pode ainda falhar em validation/CI; commit/push prematuro publica código não validado.
- **resolvido como:** §10b (olie) / §8b (locav/televisão) e **Closing PR review feedback** no `workflow-policy` — no paste de correction só corrigir + testes locais + rascunho do audit; **não** Resolve, **não** audit comment, **não** commit/push “de fechamento”. Fechamento GitHub (Resolve + audit + push do tip) fica no `pre-qa.md` §5.0 **depois** das validações. Próximo paste após correction continua sendo `implementation-validation.md`.

## Olie: UX na evidence table (sem axe)

- **problema:** evidência de Front só tinha deploy/e2e/tsc/lint; contraste, feedback de request e comportamento de overlay/z-index ficavam só no feeling do colleague.
- **por que é um problema:** regressões de loading/erro API, dropdown que não fecha e CTA atrás de overlay voltavam do QA sem rastro no card; axe/WCAG brigaria com o design system Olie.
- **resolvido como:** rows `contraste` / `feedback` / `comportamento` no template Front da evidence table + **UX rows** em `workflow-policy.md` (verificação via e2e/browser/`elementFromPoint`, **sem** gate axe); hooks em colleague-review-core / colleague scoreboard / implementation.

## Olie: tabelas JS→TS e Options→Composition na evidência

- **problema:** fronts ainda são majoritariamente JS/Options API; a migração gradual para TypeScript e Composition API não deixava rastro no card quando um arquivo mexido não era convertido ou um arquivo novo nascia no estilo legado.
- **por que é um problema:** revisor não via o motivo; agentes seguintes repetiam JS/Options sem justificativa.
- **resolvido como:** em `olie/prompts/workflow-policy.md` quatro tabelas no bloco Implementation/Correção (JS→TS + Options→Composition), cada uma com path + motivo; checklist em `implementation.md` / `pre-qa.md` / `correction.md`; notas no overlay `management.mdc`.

## Evidence table no conteúdo do card (triggers)

- **problema:** scoreboard de implementation / QA/CR / correção / revisão produção ficava só no chat do Cursor; no card não dava para ver o que rodou (deploy, e2e, tsc, pint, mutation %, etc.) nem a rodada.
- **por que é um problema:** revisor e agente seguinte perdiam o rastro; silêncio no card (policy antiga) escondia evidência útil sem ser “dívida de autor”.
- **resolvido como:** contrato **Evidence table on project content** em `olie|locav|televisao/prompts/workflow-policy.md` (upsert por `###` estável; diff A..B sem commit de format; e2e privado Olie/TV vs Cypress Locav); hooks em pre-qa / correction / colleague-review / production-review. Exceção explícita em **Card content vs chat**.

## Host-card Olie: stack seletivo back/front

- **problema:** `ensure`/`open` sempre subiam `app`+`http`+`front-management`+`olie-e2e` (~Vite+e2e) mesmo em cards só de API; N cards no jarvis estouravam RAM.
- **por que é um problema:** bugfix/backend não precisa de browser; reopen repetia o stack completo; não havia caminho para “ligar o front depois”.
- **resolvido como:** `meta.stack_groups` — `back`=`app`; `front`=`http`+`front-management`+`olie-e2e` (front implica back). Primeira abertura infere (branch no `olie-fronts` com o CODE → front; senão back) e persiste; reopen reusa. Override `--groups` / `WORKVM_HOST_CARD_GROUPS`; `workvm-host-card add --group front|back` une e re-ensure. Chat: `add front` / `add back` no `workflow-policy`.

## PR review body sem Resolve (audit comment)

- **problema:** correction/pre-QA só fechavam threads inline (botão Resolve). Reviews CHANGES_REQUESTED só no body (ex. api-main#726) não têm Resolve; o agente concluía “sem comentário” ou não deixava trilha no GitHub.
- **por que é um problema:** bloqueantes do revisor ficavam abertos sem sinal público; retorno a QA/CR sem evidência de fechamento.
- **resolvido como:** em **olie**, **locav** e **televisao**: `workflow-policy` **Closing PR review feedback** (thread vs body); `correction.md` lê get_reviews e só **rascunha** o fechamento (olie §10b, locav/televisao §8b); o audit comment no review body + Resolve das threads saem no `pre-qa.md` §5.0 **depois** das validações (ver entrada acima).

## Sandbox: 1º Pest frio (~migrate:fresh) em todo create

- **problema:** cada sandbox Olie/Televisão/Locav pagava ~70–95s no 1º `artisan test` (migrate:fresh + seed de teste no DB shared vazio), mesmo com warm pool e tip igual.
- **por que é um problema:** mutation/coverage em N arquivos ou N cards repetiam o mesmo schema; wall-clock dominado por bootstrap de DB, não pelo Pest.
- **resolvido como:** cache estilo vendor — `mysqldump` (Olie) / `pg_dump` (TV/Locav) em `~/.local/share/workvm/cache/{olie,televisao,locav}-testing-db/`, chave = migrations + seeders; no create importa testing+api e (Olie) carimba FastRefresh ou (TV/Locav) patcha TestCase no worktree para pular migrate se `migrations` existe. Opt-out: `WORKVM_*_TESTING_DB_CACHE=0`.

## Host-card: CaptainHook / commit-msg quebra no api-main

- **problema:** no pre-QA do DOP-1278, `git commit` no worktree `api-main` falhava: hooks em `.git/hooks` fazem `docker exec olie-api-main` (container inexistente no host-card) e passam o path host de `COMMIT_EDITMSG` sob `.git/worktrees/…`, que o `hc-*-app-1` não monta → `Commit message file not found`.
- **por que é um problema:** bloqueia commits/PRs em todo card no jarvis; workarounds manuais (`--no-verify` / editar hook) não devem virar hábito.
- **resolvido como:** `bin/workvm-host-card-captainhook` (resolve `hc-<id>-app-1`, faz pipe do msg file); `lib/host-card-hooks/api-main/*`; `workvm_host_card_install_api_captainhook` no ensure (`core.hooksPath`). `pre-qa.md` / `workflow-policy` documentam o loop CaptainHook no host-card e o commit do meta na branch live (`experiment/host-cards-no-vm`), não só `main`.

## Host-card ensure: Auto-review aprova Shell sem elevar `all`

- **problema:** no colleague review (DOP-1257) o agente pedia `required_permissions: ["all"]` (e `request_smart_mode_approval`); o Shell rodava mesmo assim no sandbox padrão — `Permission denied` em `~/.cursor/mcp.json`, `/var/run/docker.sock` ausente enquanto `dockerd` estava vivo, DNS/`FETCH_HEAD` falsos. O ensure abortava no merge MCP antes do compose.
- **por que é um problema:** o allow do Auto-review para `workvm-host-card` auto-aprovava o tool call sem desligar o sandbox; o agente parava o dispatcher achando host quebrado (ou loopava ensure inútil). Stack do card ficava down.
- **resolvido como:** (1) `permissions.json` — tira ensure/sandbox do allow genérico; **block** pede approval de unrestricted/`all` (não auto-run sandboxed). (2) resume soft-fail de MCP/CLONE quando `~/.cursor/mcp.json` já tem servers / `:47331` escuta; exit `75` + `WORKVM_AGENT_SANDBOX=1` se hook falha com sock oculto e dockerd vivo. (3) bridge: `bin/workvm-host-card-agent-bridge` + unit systemd + `agent-ensure` / `install-agent-bridge` — pedido em `worktree/git/.workvm-agent-ensure-request.json` (gravável no sandbox). (4) `workflow-policy` / `stop-on-broken-tooling`: se o footer do Shell ainda diz SANDBOXING após `all`, usar bridge ou approval card — não chmod/DNS.

## Host-card: prompts em `~/git` pediam permissão (Olie/Locav/Televisão)

- **problema:** no host-card o agente editava `~/git/olie/prompts/…` (e equivalentes Locav/Televisão); esse path não é root do `.code-workspace` (o meta está em `…/worktree/git`) → Cursor pedia approve “fora do workspace”.
- **por que é um problema:** atrito em todo ajuste de prompt/HISTORICO/overlay; o usuário tem que aprovar edições que deveriam ser locais ao card.
- **resolvido como:** rule `host-card-meta-repo-path.mdc` (`alwaysApply`) — escrever só em `git/olie|locav|televisao/…` do workspace; nota em `olie`/`locav`/`televisao` `workflow-policy` (Host card / Prompt templates). Mesmo padrão do `host-card-e2e-path` para e2e.

## `get-project-media-tool`: sempre `filter: "default"`

- **problema:** o default da tool é `filter: "content"`, que lista só mensagens/arquivos de usuário e omite logs de sistema (movimentação no funil: de onde saiu / para onde foi).
- **por que é um problema:** no colleague review do DOP-1257 o agente viu o chat e o vídeo, mas não a trilha de etapas; tratou o card como primeiro QA/CR e deu Pass sem perceber que já tinha ido a Validação/produção e voltado porque o fix não resolveu.
- **resolvido como:** regra **Project media** em `olie/prompts/workflow-policy.md` — chamar sempre com `filter: "default"`. Cross-refs nos passos de mídia de `colleague-review.md`, `colleague-review-core.md`, `implementation.md`, `correction.md`, `production-review.md`. Skills de image/video analysis no overlay alinhadas.

## Colleague review: bounce pós-produção / merge

- **problema:** cards que já passaram Validação/Revisão produção/Concluído (PR mergeado, deploy feito) e voltam para Corrigir/QA/CR eram revisados como primeiro colleague pass (happy path local → Pass).
- **por que é um problema:** a evidência que importa é a regressão pós-deploy e o caminho no funil nos logs; “não consegui reproduzir” do autor vira pedido de tentativa, não Pass; sucesso só no host-card não apaga vídeo de produção.
- **resolvido como:** **Return from production / merged bounce** em `workflow-policy.md`; bootstrap do `colleague-review.md` classifica `bounce` a partir dos logs (`filter: "default"`); `colleague-review-core.md` exige reproduzir o cenário do bounce e Fail se a evidência pós-deploy continuar válida; scoreboard com campo Bounce.

## Prompt health: resolva / documente / resolva permanentemente

- **problema:** atritos repetidos entre cards (tooling/VM); o agente resolvia no silêncio ou só pedia “arrume a tool”, e a solução não ficava para o próximo card.
- **por que é um problema:** tempo de card gasto em problema já visto; HISTORICO/rules não alimentavam o fluxo.
- **resolvido como:** rule `stop-on-broken-tooling.mdc` + `workflow-policy` (Olie/Locav/Televisão) — no stop, diagnosticar, checar HISTORICO, e esperar `resolva` | `documente` | `resolva permanentemente`.

## Host-card: e2e fora do workspace pedia permissão

- **problema:** prompts apontavam `~/git/olie/olie-e2e`; no host-card essa pasta não é root do `.code-workspace` (só o worktree `…/worktree/git/olie/olie-e2e`) → create de spec pedia approve “fora do workspace”.
- **por que é um problema:** fricção a cada card sem e2e; risco de gravar no meta shared em vez do worktree do card.
- **resolvido como:** path resolution em `workflow-policy` + prompts/overlay; ensure escreve rule `host-card-e2e-path.mdc` no meta/e2e do card (exclude local).

## Own-card: reaproveitar sandboxes coverage → mutation

- **problema:** após coverage o pool era destruído e mutation recriava N containers (~minutos) só para o estágio seguinte.
- **por que é um problema:** wall-clock e RAM; isolamento exclusive só exige um job Pest por sandbox **em paralelo**, não destroy entre estágios sequenciais.
- **resolvido como:** prompts/ORCHESTRATION — own-card não destroy no fim do coverage; mutation adota ready + create shortfall; destroy no fim do mutation. Dispatcher ∥ coverage/mutation continua com pools separados.

## Host-card open: sync do meta worktree para o HEAD do ~/git

- **problema:** `open`/`ensure` em card já criado só logava “meta worktree já existe”; prompts/sandbox no `worktree/git` ficavam no commit do create.
- **por que é um problema:** updates no meta-repo (`experiment/…`) não apareciam na janela do card sem recreate.
- **resolvido como:** `workvm_host_card_sync_meta_worktree` — `reset --hard` no detached worktree para o HEAD do meta ao vivo (add_meta + open). Untracked no card permanece.

## Sandbox mutation/tests: não sobe `http` (php -S)

- **problema:** profile `mutation`/`tests` no slim incluía o serviço `http` (~256–512 MiB) só para CLI Pest.
- **por que é um problema:** warm pool × N sandboxes gastava RAM sem servir mutation/coverage.
- **resolvido como:** `http` só nos profiles `e2e` e `slim` (Olie/TV/Locav). Host-card continua com `slim` (API no browser).

## Auto-review: warm pool sandbox sem card de aprovação a cada create/job

- **problema:** `permissions.json` pedia unrestricted shell antes de todo `workvm-sandbox create/job run/destroy`; no DOP-1278 o dreno de mutation/coverage virava N cards de OK.
- **por que é um problema:** warm pool 2–4 + job por arquivo = atrito contínuo na janela do card; o agente já pede `required_permissions: ["all"]`.
- **resolvido como:** `workvm-sandbox` create/job/destroy/list/status/gui passam para **allow** com shell unrestricted; **block** fica só em `workvm-host-card` ensure/open/destroy (+ bridge). Promover `~/.cursor/permissions.json` (ou `workvm_apply_cursor_permissions` após commit).

## Televisão/Locav: PostgreSQL/Redis compartilhados (hc-*-data)

- **problema:** TV host-card e sandboxes subiam pgsql/redis (ou mysql) por unidade; Locav não tinha sandbox nem shared data.
- **por que é um problema:** mesma pressão de RAM do Olie; Locav mutation batia no Sail único.
- **resolvido como:** `televisao/sandbox/compose.host-data.yml` + shared overlays (host + sandbox); `locav/sandbox/` (shared + slim + project.sh + ensure/destroy só data). DB/prefixo por id; destroy só DROP. Opt-out sandbox: `WORKVM_SANDBOX_SHARED_DATA=0`.

## Sandbox Olie: MySQL/Redis/Mongo compartilhados (hc-olie-data)

- **problema:** cada `workvm-sandbox create` subia mysql+redis+mongo no slim — warm pool 2–4 × ~1.75 GiB de data além do app.
- **por que é um problema:** mesma pressão de RAM que N host-cards com data próprio; isolamento exclusive só precisa de database/prefixo.
- **resolvido como:** create/destroy Olie reusa `hc-olie-data` + `compose.host-card-shared-data.yml`; provisiona `api_sb_<id>` / `testing_sb_<id>`(+`_test_*`); patch `phpunit.xml` do worktree; destroy só DROP. Opt-out: `WORKVM_SANDBOX_SHARED_DATA=0`.

## Host-card Olie: workspace vazio no resume (Explorer/SCM)

- **problema:** `write_workspace` no ensure reescrevia o stub com `folders: []`; com a janela já aberta o Cursor hot-reloada o vazio; `bind_workspace_worktree` preenchia o disco depois e o ensure só focava → Explorer/SCM sem repos (ex. DOP-1276).
- **por que é um problema:** card “aberto” sem worktrees na UI; parece isolamento quebrado.
- **resolvido como:** stub só se o `.code-workspace` ainda não existe; bind continua sendo a escrita de folders; se folders ainda estiver vazio com janela aberta, ensure reabre.

## Host-card destroy: não fecha a janela Cursor

- **problema:** `finish card` / `destroy` chamava `workvm_close_cursor_workspace` no fim do teardown; o agent ainda estava na janela do card → diálogo “prompts running”.
- **por que é um problema:** confirmação manual e chat interrompido no finalize.
- **resolvido como:** destroy não fecha Cursor; imprime `close_cursor=manual` + hint para o usuário fechar à mão; chat command em `workflow-policy.md`.

## Host-card Olie: MySQL/Redis/Mongo compartilhados

- **problema:** cada card subia mysql+redis+mongo próprios (slim) — N cards × 3 serviços no jarvis.
- **por que é um problema:** RAM/CPU; isolamento real só precisava de database/prefixo.
- **resolvido como (teste, sem commit):** `compose.host-data.yml` (mysql:8.4, mongo:5, redis-stack como `docker-workspace`) + `compose.host-card-shared-data.yml`; ensure provisiona `api_<slug>` / `testing_<slug>*`; destroy só DROP do card; stack `hc-olie-data` permanece.

## Host-card ensure: não fechar janela já aberta

- **problema:** `ensure` (colleague review passo 0) sempre `close` + reopen do `.code-workspace` por causa do hack SCM; no meio do review a janela/chat do card caía.
- **por que é um problema:** o dispatcher morre ou o usuário vê a janela fechando em loop.
- **resolvido como:** se a janela do card já está aberta, ensure só **foca**; close+SCM+reopen fica no `workvm-host-card open`. Prompts: `OPEN_CURSOR=0` quando o chat já é a janela do card.

## Host-card: worktree por repo (Olie)

- **problema:** isolamento do card misturava worktree só do `api-main`, clones shared no workspace e pasta `api-main (shared)` para o SCM — frágil e confuso.
- **por que é um problema:** edição/SCM no path errado; sujeira do meta-repo shared vaza entre janelas; remendo de UI virava arquitetura.
- **resolvido como (Olie, sem commit de teste):** `prepare_olie_isolation` — worktree de todos os `CLONE_REPOS` + meta `worktree/git`; reflink/rsync de `vendor` e `node_modules`; workspace só esses paths; compose `SB_FRONTS` / `SB_E2E` no worktree do card. Fases seguintes (repos prováveis; polir heavy) em `host-cards-no-vm.md` §4.

## Prompt `correction`: force-push antes da verificação

- **problema:** `olie/prompts/correction.md` §4 mandava `git push --force-with-lease` logo após o rebase terminar, e só depois retomar findings/TDD/verificação.
- **por que é um problema:** o tip do PR era publicado sem checar se a resolução de conflito (e o resto da correção) estava correta; falhas só apareciam depois do push.
- **resolvido como:** §4/§11 — após o rebase local, plano/findings/testes primeiro; force-push é o **último** write remoto da passada. Sync do texto no Opbed `config.prompts`.

## Meta-repo `~/git`: SCM listava só clones (ex. Televisão)

- **problema:** janela do folder `~/git` no Source Control mostrava `televisao-*` (e outros clones) e não o meta-repo.
- **por que é um problema:** chat/edição no meta-repo; SCM poluído e o `git` da raiz some da lista.
- **resolvido como:** `~/git/.vscode/settings.json` com `git.autoRepositoryDetection: false` + `repositoryScanIgnoredFolders` dos produtos; state SCM do folder com `visible` só `~/git`.

## Host-card: SCM sem `api-main` (worktree órfão)

- **problema:** Explorer ok (conflito); Source Control sem `api-main`. Ignore do shared piorava; sem o repo pai o Git abria o worktree (`kind: worktree`) e o painel omitia.
- **por que é um problema:** rebase/UU invisíveis no SCM.
- **resolvido como:** (1) Sem meta-repo `..` no `.code-workspace` do card (+ pasta `prompts/`). (2) **Não** `git.ignoredRepositories` no shared. (3) Incluir pasta `api-main (shared)` → `~/git/olie/api-main` para o pai existir no SCM; editar o 1º `api-main` (worktree). (4) `git.detectWorktrees: false` para não puxar worktrees de outros cards. (5) `ensure_scm_repos_visible` no open.

## Host-card: `open` foca o workspace do card (não o meta-repo)

- **problema:** `ensure` com a janela do card já aberta fazia skip; o usuário ficava no chat/`~/git` e não via rebase/conflitos no worktree.
- **por que é um problema:** correção/colleague edita `…/host-cards/…/worktree/api-main` enquanto a UI mostra o clone ou o meta-repo.
- **resolvido como:** `workvm_focus_cursor_workspace` + ensure/open focam a janela existente; CLI `workvm-host-card open`; chat command `open PROJECT CODE` nas workflow-policy. Hyprland 0.56: focus via `hl.dsp.focus({ window = "address:…" })` (o `focuswindow` antigo quebra como o `closewindow`).

## Mutation: discovery R7 (por que o wall ainda é alto)

- **problema:** mesmo com `--class` scoped / warm pool / R1–R6, o mutate ainda domina o colleague review (~54 min no DOP-1281).
- **por que é um problema:** risco de gastar mais prompts “otimizando discovery” sem ganho.
- **resolvido como:** bench DOP-1183 (`/tmp/dop1183-r7-mutate-discovery`): wall ≈ **~0,3s/mutante** quente; class gorda coberta (`AutomationRunInstance`) ~48s / 134 mutantes; multi-`--class` **quebrado** (3→0 files, 2→1 file) → obriga 1 class por run; `--covered-only` ≠ filtro in-scope (Pest ainda avalia todos os covered da class). **Sem** fix de prompt/CLI — alavanca real seria filtro por linha no Pest (upstream). Nota nos prompts mutation + ORCHESTRATION.

## Mutation: retry de deadlock/baseline flake + watchdog

- **problema:** deadlock MySQL (`model_has_permissions`) / baseline flaky derrubava o shard; mutate sem exit prendia o slot do warm pool.
- **por que é um problema:** Blocked cedo ou dreno parado (DOP-1281); wall do colleague review sobe sem progresso no ledger.
- **resolvido como:** prompts mutation (Olie/Locav/Televisão) — **1** retry automático no mesmo slot para flake/deadlock antes de Blocked; ORCHESTRATION — watchdog 15 min baseline / 45 min mutate (libera slot). Sem mudar schema do app.

## Mutation: quoting canônico de `--class` no `job run`

- **problema:** exemplos com `App\\Foo` dentro de aspas simples faziam o Pest receber `\\` literal → `0 Mutations for 0 Files`.
- **por que é um problema:** mutate “vazio” e re-runs; DOP-1281 reportou o escape no `job run`.
- **resolvido como:** prompts Olie/Locav/Televisão + ORCHESTRATION — forma canônica `'--class=App\Foo'` (um `\`); tabela do que quebra. Smoke argv: quoted `\\` → duplo; quoted `\` → certo; unquoted `\` → bash come.

## Coverage: lote por Via test (não 1 Pest por `app/`)

- **problema:** `correct coverages` / dispatcher rodava um `pest --coverage` por arquivo `app/`; o mesmo Via era repetido.
- **por que é um problema:** wall do measure sobe linear com o número de `app/` mesmo quando um relatório já lista todos.
- **resolvido como:** prompts Olie/Locav/Televisão + ORCHESTRATION — batch por Via; um coverage fecha o lote; pool `N = min(lotes, 4)`. Bench DOP-1183 (quente): 5/1 Via ~34s→~6s; 8/2 Vias ~53s→~13s.

## Change-set: feature já mergeada (`develop...HEAD` vazio)

- **problema:** com a branch já em `develop`, `develop...HEAD` vinha vazio; gap/mutation/coverage improvisavam ou pulavam backend.
- **por que é um problema:** colleague review do DOP-1281 montou a lista à mão via commits `DOP-XXXX`; risco de gate “no backend” falso.
- **resolvido como:** receita **Backend change-set** em `workflow-policy` (Olie/Locav/Televisão) + ponteiros nos gates: dirty → three-dot → merge `M^1...M^2` / `--grep=<CODE>` (pula sync “merge develop into”). Smoke DOP-1281: three-dot 0 → union ≈ 49 paths.

## Sandbox: `--from-commit` tip do card (não bare create)

- **problema:** `workvm-sandbox create` sem tip usava `HEAD` do clone (`develop`); coverage/mutation rodavam no SHA errado e recriavam.
- **por que é um problema:** bench DOP-1183 bare → `0b2c8f77` develop vs tip card `4cdc921c`; recreate ≈ +58s wall + risco de mutate no commit errado (DOP-1281).
- **resolvido como:** prompts Olie/Televisão + `ORCHESTRATION` obrigam `--from-commit <tip do api worktree do card>`; create nu proibido.

## Sandbox: strip `KEY=` vazio no `.env` (META_GRAPH_URL=)

- **problema:** `.env` do card com `META_GRAPH_URL=` (e outras `KEY=`) ia para o sandbox; `env()` via como setado → `graph_url` `''` em vez do default Meta.
- **por que é um problema:** baselines Pest vermelhas no colleague review; minutos de strip manual (DOP-1281 ~2 min + re-runs).
- **resolvido como:** `sed` em `workvm_sandbox_olie_write_env` remove `^[A-Z][A-Z0-9_]*=\s*$` só na cópia do sandbox. Bench DOP-1183: before fail (`''` vs `https://graph.facebook.com`, ~96s); after 1ª baseline verde sem intervenção.

## Host-card: olie-e2e não fica Up com o card morto

- **problema:** `olie-e2e` tinha `restart: unless-stopped`; após reboot/kill do Docker o app ficava Exited e o e2e voltava sozinho.
- **por que é um problema:** RAM e Playwright MCP apontando para card sem stack; “finalizei o card” sem `destroy` deixava e2e vivo.
- **resolvido como:** `restart: "no"` em `compose.e2e-host.yml`; `workvm_host_card_olie_stop_orphan_e2e` no ensure (para e2e Up com app down); recreate do e2e se o container antigo ainda tiver `unless-stopped`.

## Mutation/coverage: warm pool 2–4 (não 1 sandbox por arquivo)

- **problema:** o dreno criava um sandbox (ou job) por `*Test.php` / `app/` file; com N grande o wall não caía e o shard pesado sofria contenção.
- **por que é um problema:** create+rsync e CPU/IO compartilhados; no jarvis, 8 mutates frios juntos alongam o pior arquivo sem encurtar o lote.
- **resolvido como:** regra **warm pool** em `olie` (`mutation-testing` / `coverage-testing` / `sandbox/ORCHESTRATION.md` + README), espelho Televisão/Locav: `N = min(restantes, 4)`, **`2`** se RAM apertada; reusar slot (rsync dirty); não abrir um por arquivo só porque o change-set é grande. Bench DOP-1258 (8 arquivos, tip `cc57e847`): pools **2/4/6/8** ≈ **387–406s** wall; pool 8 piorou Endpoint (~349s vs ~178s).

## Mutation ledger `sha:`: skip só para retries neste meta-repo

- **problema:** dava para ler o skip por `sha:` como se o autor do card stampasse no handoff e a 1ª colleague review viesse quente.
- **por que é um problema:** `mutation-ledger.md` é privado deste meta-repo; outros devs da empresa não têm o arquivo — a 1ª review de card de colega continua fria.
- **resolvido como:** nota **Personal ledger only** em `olie|locav|televisao/prompts/mutation-testing.md`: skip = retries seus (2ª review / try again / outro chat) com tip igual. Bench DOP-1258 (3 arquivos stampados): skip ~70 ms vs cold remutate parede ~29 s (~400×; cold sem create de sandbox).

## Mutation: `--class` por teste, não o pool inteiro do change-set

- **problema:** `mutation-testing` mandava passar **todas** as FQCN `app/` do change-set em **cada** `*Test.php`; com `--covered-only` classes só tocadas de passagem ainda geravam mutate longo (ex. CloudConnector +171s num teste de templates).
- **por que é um problema:** a descoberta do colleague review (1ª onda) fica no teto do pior shard; pool largo × N testes paga wall-clock sem fechar survivors úteis.
- **resolvido como:** escopo **per-test** em `olie|locav|televisao/prompts/mutation-testing.md` (+ nota em `olie/sandbox/ORCHESTRATION.md`): pool do change-set → filtrar FQCN que o teste exercita (`use` + drivers HTTP/jobs). Bench DOP-1281 no host-card: `ChannelMessageTemplatesTest` full 21 classes ~657s vs scoped 8 ~416s (**~1.6×**); leve ~4.7×.

## Colleague review: gap/mutation/coverage → reviewer-fix, não Corrigir

- **problema:** o outcome do colleague review mandava mover para 'Corrigir' se gap, mutation ou coverage reportassem trabalho — mesmo com o core Pass — e ainda gravava esses resultados no conteúdo do projeto.
- **por que é um problema:** o revisor fecha esses três gates no próprio chat; bounce e nota no card só fazem sentido quando há fail de produto/aceitação (fora desses três).
- **resolvido como:** **Colleague review outcome** (Olie/Locav/Televisão): Corrigir só se o colleague core (ou outro fail fora de gap/mutation/coverage) falhar; gap/mutation/coverage sozinhos → QA/CR + reviewer-fix no chat (`add` / `to correct` / `correct mutations` / `correct coverages` / `try again`), **sem** escrever no projeto. Só cola gap/mutation/coverage no card quando o bounce for por fail fora desses gates. `colleague-review`, `workflow`, `test-gap-analysis`, `mutation-testing` alinhados.

## Correction: plano deve ler comentários dos PRs do card

- **problema:** o correction montava o plano só com o texto do card/retorno e podia omitir threads de review do GitHub (ou listá-los e não fechar o lote).
- **por que é um problema:** findings line-level ficam de fora do triage; o revisor vê pendência que o plano “não viu”.
- **resolvido como:** em `olie`/`locav`/`televisao` `prompts/correction.md` §Analyze — obrigatório carregar review threads de cada PR do formulário/conteúdo **antes** do plano; se houver comentários, entram no triage como qualquer finding; o plano lista PRs checados e threads.

## Correction: marcar thread do PR como Resolved

- **problema:** `correction.md` fechava o trabalho sem marcar “Resolve conversation” nos comentários de review do PR; o código já estava corrigido e o revisor ainda via threads abertas.
- **por que é um problema:** parecer de pendência falsa e retrabalho de “ainda não resolveu o comentário”.
- **resolvido como:** §Resolve GitHub PR review threads + critério de conclusão em `olie`/`locav`/`televisao` `prompts/correction.md` — só resolve o thread depois que **todos** os pontos daquele comentário estão feitos (MCP ou `gh` GraphQL `resolveReviewThread`); reporta threads resolvidos e os que ficaram abertos.

## Own-card: drain paralelo por padrão

- **problema:** no handoff próprio, coverage/mutation avançavam com `next coverage` / `next mutation` (um arquivo por paste); N arquivos = N pastes + wall-clock serial, enquanto o colleague dispatcher já drenava em paralelo.
- **por que é um problema:** bench DOP-1258 (3 arquivos, create+mutate+destroy): sequencial ~472s vs paralelo ~230s (~2×); ainda sem a espera humana entre pastes.
- **resolvido como:** default own-card = `correct coverages` / `correct mutations` ao abrir o prompt (Olie/Locav/Televisão); `next *` fica opt-in. `workflow-policy` + `olie/sandbox/ORCHESTRATION.md` alinhados.

## Mutation/coverage: ledger por SHA (file@blob)

- **problema:** o budget de re-run evitava repetir no mesmo chat, mas entre chats/colleague o dispatcher ainda reabria sandbox + mutate/coverage no mesmo tip já fechado no ledger (path-only ou “card pass”).
- **por que é um problema:** 2º pass em arquivos já `100%`/`equivalent` pagava create+mutate+destroy de novo (bench DOP-1258: 3 arquivos → ~227s wall paralelo).
- **resolvido como:** stamp `sha:<fp>` nas Notes via `bin/workvm-ledger-sha.sh` (blobs do teste + `--class` prod / do `app/` no coverage); skip cross-chat só com Result done **e** fingerprint igual; sem `sha:` → re-roda uma vez e carimba. Prompts mutation/coverage + workflow-policy (Olie/Locav/Televisão). Bench after: skip dos 3 arquivos em ≪1s (sem sandbox).

## Mutation/coverage: orçamento de re-run (equivalent cedo)

- **problema:** no colleague review o agente re-rodava `pest --mutate` / `--coverage` “para confirmar” ou sem assert novo; no jarvis isso repetia o mesmo score (ex. SafeUrlGuard 54.65% ×4) e queimava minutos por arquivo.
- **por que é um problema:** wall-clock do gate era dominado por re-medida inútil, não por fechar in-scope/+1pp.
- **resolvido como:** seção **Re-run budget** em `mutation-testing.md` e re-measure budget em `coverage-testing.md` (Olie, Locav, Televisão) + nota em `workflow-policy.md`: classificar killable vs `equivalent` após 1 reporte; re-rodar só após mudança real de teste (≤1 re-mutate por `--class`); proibido re-medir árvore inalterada. Bench local DOP-1258: ~200s (4×) → ~23s (1×) no mesmo score. Depois: tabela **Expensive re-run budget** em `workflow-policy` + bullets nos triggers `colleague-review`(+core), `pest-parallel`, `test-gap-analysis`, `implementation-validation`, `pre-qa`, `production-review`, `correction` nos três produtos.

## Host-card ensure: worktree api-main na branch do card

- **problema:** `open olie DOP-…` criava o worktree em detached HEAD/`develop`; a janela Cursor não mostrava os arquivos já commitados na `feature/DOP-…`.
- **por que é um problema:** reopen/colleague review dependia de checkout manual (ou do prompt de implementation) só para ver o diff do card.
- **resolvido como:** `workvm_host_card_prepare_api_isolation` recebe o código; resolve branch local/`origin` pelo nome (contém o código) e faz checkout só no worktree do card (`lib/host-card.sh`); hook Olie passa `$code`. Sem branch → HEAD/develop como antes.

## Olie sandbox: sem teto de 3

- **problema:** colleague mutation/coverage enfileiravam após 3 sandboxes (`WORKVM_SANDBOX_MAX` default 3), mesmo no jarvis com host-card.
- **por que é um problema:** N `*Test.php` viravam fila artificial; o usuário pediu paralelismo sem o limite de 3.
- **resolvido como:** default Olie `0` (= sem teto) em `olie/sandbox/project.sh` + `lib/sandbox/manager.sh` (só bloqueia se `max > 0`); docs/prompts alinhados; cap opcional `WORKVM_SANDBOX_MAX=N`.

## Host-card Opbed: ensure só abria Cursor

- **problema:** `workvm-host-card ensure --project opbed` clonava repos e abria a janela, sem compose — o board/API não subiam no jarvis.
- **por que é um problema:** “open opbed” ficava igual a abrir workspace vazio; Olie/Televisão já tinham hook de stack.
- **resolvido como:** `opbed/sandbox/compose.host.yml` + `host-card-ensure.sh` / `host-card-destroy.sh` (pgsql + backend + front, portas `port_base`, DNS Caddy, sem cloudflared).

## Host-card ensure: PermissionError em ~/.cursor/mcp.json no chat

- **problema:** `workvm-host-card ensure` no colleague review / prompts falhava com `PermissionError: … ~/.cursor/mcp.json` (e avisos falsos de DNS/`gh`/`docker.sock`); o agente pedia chmod/DNS/`gh auth` ao usuário ou parava o dispatcher como “tooling broken”.
- **por que é um problema:** o arquivo já era `fabricio` `600` e o host (jarvis) está ok com shell `all`; a falha era o sandbox do Shell no Cursor. Retry sem `all` (ou parar sem approval card) repetia o erro; o stack do card já estava ok no host.
- **resolvido como:** bullet **Shell permissions** + **Sandbox symptom cluster** em `olie|locav|televisao/prompts/workflow-policy.md` (primeiro `ensure` já com `all`; se Auto-review bloquear → approval card, não chmod); exceção no `colleague-review.md` Olie; allow em `.cursor/permissions.json`; mensagem em `lib/cursor.sh` (`workvm_apply_mcp`); nota em `host-cards-no-vm.md`.

## Host-card Pest: teto de 22 processes no jarvis

- **problema:** `workvm-host-card-pest` usava `nproc` (24 no jarvis); com `--processes` 23 ou 24 o Paratest matava workers com SIGSEGV (exit 139) e a suite abortava sem contagem.
- **por que é um problema:** o gate `pest-parallel` ficava vermelho por infra, não por regressão; retry manual com menos workers era ad hoc.
- **resolvido como:** default `min(nproc, 22)` em `bin/workvm-host-card-pest` (2026-11-16; 22 completou a suite). Override `WORKVM_HOST_CARD_PEST_PROCESSES`. Documentado em `olie/prompts/pest-parallel.md`, `host-cards-no-vm.md` §6, `layout.mdc`.

## Gap analysis: comando `add` para fechar testes faltantes

- **problema:** depois de **Tests to add**, o handoff misturava implementação de testes com `to correct` (validação / Needs code fixes); não havia frase curta só para gravar os testes recomendados pelo gap.
- **por que é um problema:** o autor pedia algo tipo “add” e o agente não tinha contrato; ou usava `to correct` e a intenção ficava ambígua.
- **resolvido como:** comando **`add`** em `olie/prompts/workflow-policy.md` (Chat commands) + `test-gap-analysis.md`: implementa só a lista título+descrição daquele pass, depois `try again` no gap. `to correct` fica para validation / Pest parallel.

## Host-cards sem WorkVM (jarvis)

- **problema:** cada card virava domain libvirt; N cards × N projetos no host de 32 GiB não cabiam (OS + Hyprland + Cursor + compose por guest). Pest `-p` em dois cards no mesmo clone/vendor corrompia a suite; MySQL default no host (24 threads) engasgava.
- **por que é um problema:** custo de VM por card e colisão de porta/DB/DNS; dual Pest inválido; suite travava ou falhava em massa.
- **resolvido como:** `bin/workvm-host-card` + `lib/host-card.sh` / proxy Caddy (`*.olie.localhost`); compose slim+front+MySQL tmpfs (`compose.mysql-host.yml`); worktree `api-main` + vendor rsync **por card**; triggers nos prompts Olie/Locav/Televisão. Contrato: `host-cards-no-vm.md`.

## Checklist manual Olie → prompts

- **problema:** o checklist antigo (planejamento de impactos, loop front `frame_id`/permissão/i18n, limpeza de comentários de debug, triage de correção) vivia só na cabeça; os prompts cobriam parte disso e deixavam gaps.
- **por que é um problema:** o agente planejava sem forçar meios/requests/telas; validação de tenant focava no backend; pre-QA só tirava `console`; correção absorvia achados fora de escopo sem freio.
- **resolvido como:** reforço pontual em `implementation` (§4.3 + §8), `implementation-validation` (`multitenancy`/`front-back`), `pre-qa` (comentários de debug + sem regressão visual), `correction` (triage in-scope/simple/out-of-scope + stop se >3 findings novos). Sync `config.prompts` no Opbed. Sem prompt novo de checklist. O mesmo espelho em Locav (`project_id` 4) e Televisão (`project_id` 6), trocando `frame_id`/`pt-br` por ownership/`autorizacao` do produto; sync Opbed nos dois.

## PRs extras sem campo de formulário → conteúdo do card

- **problema:** Televisão (e o mesmo padrão em Locav/Olie) tem mais repositórios com PR do que campos **Pull Request (front)/(back)**; meet/outros PRs ficavam só no relatório do chat.
- **por que é um problema:** o board não mostra o link; revisor e autor perdem o PR sem campo dedicado.
- **resolvido como:** `workflow-policy` + `pre-qa` (Olie/Locav/Televisão): form quando o label casa; senão append dos URLs no conteúdo do projeto via `edit-project-tool` (sem inventar campo). Sincronizado em `config.prompts` no Opbed.

## Own-card handoff: coverage antes do pre-QA

- **problema:** depois do mutation o handoff próprio recomendava `pre-qa.md`; `coverage-testing.md` existia mas era opcional e não bloqueava `next prompt`.
- **por que é um problema:** o autor pedia coverage no fluxo de correction e o agente saltava para PRs; a medição de linhas do diff ficava fora da cadeia.
- **resolvido como:** cadeia own-card = gap → mutation → **coverage** → pre-QA. Mutation recomenda `coverage-testing.md`; coverage ganha stack gate (como mutation) e só então recomenda `pre-qa.md`. Cross-refs: `correction`, `implementation-validation`, `workflow`, `workflow-policy`, `pre-qa`, `README`, ledgers.

## Own-card mutation: `correct mutations` (drain paralelo)

- **problema:** no handoff próprio, o stack de mutation só avançava com `next mutation` (um `*Test.php` por paste); N arquivos restantes viravam N pastes e wall-clock, enquanto o colleague dispatcher já drenava em paralelo com sandbox por arquivo.
- **por que é um problema:** o autor esperava fechar o ledger antes do pre-QA e a sessão virava fila manual; a infra (`workvm-sandbox`) já existia mas o contrato do chat não tinha frase para o drain.
- **resolvido como:** comando **`correct mutations`** em `olie/prompts/mutation-testing.md` + `workflow-policy` (Chat commands): um sandbox `--profile mutation` e um subagent por arquivo restante; o pai agrega `mutation-ledger.md` e respeita `WORKVM_SANDBOX_MAX`. `next mutation` continua o caminho de um arquivo. Cross-refs: README, workflow, implementation-validation, pre-qa, correction, `olie/sandbox/ORCHESTRATION.md`.

## Pre-QA: restrições do step antes de mover para QA/CR

- **problema:** o agente tentava `move-project-to-funnel-step` para QA/CR e tomava `incoming_restrictions` (ex.: rádio Postman do form do step ainda vazio), depois preenchia e movia de novo.
- **por que é um problema:** falha evitável no handoff; parece prompt-health / tooling quebrado quando é só gate de formulário do destino.
- **resolvido como:** `workflow-policy` (**Moving a card**) e `pre-qa.md` Phase 5 exigem responder as restrições / forms do step de destino **antes** da move; só então mover e verificar o estágio.

## E2E privado: não citar no card, repo ou Caderno

- **problema:** agentes citavam `olie-e2e` / Playwright do meta-repo (e o equivalente da Televisão) em conteúdo do projeto Olie, PR de empresa e Caderno; esses specs são só do dono da WorkVM.
- **por que é um problema:** o board e os remotes da empresa apontam para uma suite que outros desenvolvedores não têm; ruído e expectativa falsa de cobertura compartilhada.
- **resolvido como:** política **Private E2E suites** em `olie/prompts/workflow-policy.md` (+ `project` / `implementation` / `pre-qa` / `correction` / `colleague-review-core`); Televisão alinhada em `Running Playwright`; Locav documentado como exceção (Cypress nativo em `locav-front`). Uso local e commit no meta-repo continuam; citação pública não.

## Gap analysis no handoff próprio: lista só no chat

- **problema:** `test-gap-analysis` no fluxo de implementação (após `implementation.md` / validation) gravava lacunas no conteúdo do card Olie; o autor ainda ia fechar os testes antes do pre-QA/PR, e o card ficava com lista provisória.
- **por que é um problema:** ruído no board e no conteúdo do projeto; a lacuna já seria resolvida no mesmo handoff.
- **resolvido como:** em Olie, Televisão e Locav, handoff próprio lista título+descrição só no chat Cursor; colleague review continua gravando no conteúdo do card. Prompts: `test-gap-analysis.md`, `workflow.md`, `workflow-policy.md`, `README.md`.

## Caderno/forum: MCP notebook no lugar do helper HTTP

- **problema:** `workflow-policy` mandava ler fórum via `workvm-olie-management-read.sh` (`get-forum` / threads TipTap) e dizia que não havia tool MCP; o agente parava no proxy sandbox ou pedía OK de token. As tools MCP já existiam com o nome **notebook** (Caderno).
- **por que é um problema:** preferência MCP→HTTP quebrava; a listagem de “todos os fóruns/subfóruns” parecia ausente porque o nome mudou (`get-notebook-tool` = árvore `pages` + `children`).
- **resolvido como:** `workflow-policy` (Televisão / Locav / Olie), cross-refs dos prompts, `meta-repo` / `layout` e cabeçalho do helper: Caderno via `get-notebook-tool` + `read-notebook-page-tool`; helper HTTP só sob MCP auth.

## Auto-review: `permissions.json` no fluxo pull → vm-setup → project-setup

- **problema:** o Auto-review lia `~/.cursor/permissions.json`, mas o fonte versionado em `~/git/.cursor/permissions.json` não era copiado no `pull-meta` / `vm-setup` / `project-setup` (só o MCP ia para user-level). VM nova ou após pull ficava com Auto-review velho ou ausente. No sandbox do agente Cursor, `~/git/.cursor` ainda pode ficar bind-montado RO e o worktree stale.
- **por que é um problema:** rules/prompts novos do meta-repo entravam no workspace, mas leituras GitHub/MCP/fórum/checklist continuavam pedindo OK; o fluxo documentado de “baixar e rodar setup” não bastava; `git status` sujava com diff falso.
- **resolvido como:** `workvm_apply_cursor_permissions` em `lib/cursor.sh` lê o blob `HEAD:.cursor/permissions.json` (não o disco RO) e escreve `~/.cursor/permissions.json`; chamado em `bin/pull-meta.sh`, `vm-setup.sh`, `project-setup.sh` e `lib/project-start.sh`. Fonte canônico permanece no meta-repo.


## Olie sandbox slim (isolamento mutation/Pest)

- **problema:** o dispatcher do colleague-review Olie rodava core + gap + mutation em paralelo na Card VM; Pest/mutation compartilhavam MySQL `testing` e chegaram a deixar `api_main` sem schema (`frames` missing) — review DOP-1165 Blocked.
- **por que é um problema:** a orquestração já dizia exclusive → sandbox, mas `olie/sandbox/` só tinha o contrato; sem compose slim o agente caía no `docker exec olie-api-main`.
- **resolvido como:** `olie/sandbox/project.sh` + `compose.slim.yml` + `Dockerfile.app` (PCOV) + `mysql-init`; prompts (`colleague-review`, `mutation-testing`, `test-gap-analysis`, `workflow-policy`) **obrigam** `workvm-sandbox --project olie` para Pest/mutation em paralelo; gap no dispatcher fica só leitura. Mesma CLI da Televisão. `vendor` via bind-mount `SB_API_VENDOR` (symlink absoluto no host não resolve no container).

## Funnel catalog: não cair em `get-available-steps` com MCP ok

- **problema:** o agente já tinha `index-project-funnels-tool` (ou um `[]` de `search` estreito) e ainda abria `curl`/`get-available-steps` “por precaução”, gerando prompt de token e violando a preferência MCP.
- **por que é um problema:** leitura coberta pelo MCP vira HTTP autenticado; `[]` no filtro é tratado como MCP morto.
- **resolvido como:** `workflow-policy` (Televisão / Locav / Olie) e `televisao/prompts/colleague-review.md` reforçam hard ban: empty filter ≠ down; retry unfiltered; HTTP só com `needsAuth`/401 no próprio index.

## Colleague review: um paste dispara core + gap + mutation em paralelo

- **problema:** `colleague-review.md` era o miolo da review e, com backend, ainda pedia pastes seguintes (`test-gap-analysis` → `mutation-testing` → N× `next mutation`). O wall-clock e a espera humana entre pastes dominavam o QA/CR (Televisão e Olie).
- **por que é um problema:** o revisor colava três (ou mais) prompts; o funil ficava em QA/CR entre pastes; a economia prevista em `ORCHESTRATION.md` não existia no texto que o agente executa.
- **resolvido como:** nos dois produtos, `colleague-review.md` virou **dispatcher** (bootstrap → Task paralelo → scoreboard → **Colleague review outcome**). O miolo foi para `colleague-review-core.md`. Gap e mutation ganharam **dispatcher mode** (sem `next prompt`; mutation drena todos os `*Test.php` restantes). `workflow-policy` / `workflow` / README / `ORCHESTRATION.md` alinhados (`televisao/sandbox/`, `olie/sandbox/`). Shard Docker Olie: ver entrada **Olie sandbox slim** acima.

## Sandbox Manager (piloto Televisão + contrato Olie)

- **problema:** no mesmo Card, testes / mutation / e2e compartilhavam um compose, DB, Redis e worktree; operação destrutiva em um passo afetava os outros. O colleague stack ainda exigia pastes sequenciais, o que alongava o wall-clock.
- **por que é um problema:** não dava para rodar mutation e e2e em paralelo com isolamento real sem clonar outra WorkVM (cara em RAM no host de 32 GiB); mutation serializada por arquivo desperdiçava a guest ociosa.
- **resolvido como:** `bin/workvm-sandbox` + `lib/sandbox/` (backend container; VM stub). Piloto Televisão em `televisao/sandbox/`; Olie em `olie/sandbox/` (compose slim + `project.sh` + PCOV). Contrato: `*/sandbox/ORCHESTRATION.md`. Selftest: `bin/workvm-sandbox-selftest.sh`. Dispatcher colleague já paralelo; exclusive Pest/mutation Olie **deve** usar sandbox (não `olie-api-main` na Card VM).

## Pre-QA: commitlint / CaptainHook antes do PR (OS-556)

- **problema:** o card OS-556 voltou de Validação para Corrigir porque o CI do `olie-fronts` falhou em **Lint commit messages** (`subject-full-stop`: subject com `.` no fim). O lint de produto estava verde; a §4.2 do `pre-qa.md` só pedia “seguir a convenção” sem rodar o validador.
- **por que é um problema:** o card já tinha sido aprovado e avançado; o retorno automático por CI de mensagem gasta sprint e mascara entrega pronta.
- **resolvido como:** `olie/prompts/pre-qa.md` §4.2 exige `yarn commitlint` (front, espelhando `.github/workflows/ci.yml` + husky) e CaptainHook `hook:commit-msg` (api-main, espelhando `conventional-commits.yml` + `captainhook.json` com `descriptionEndMark: ""`) no range do PR **antes** da Phase 4, e confirma o check verde no GitHub depois do push.

## Modelo genérica `archlinux` → `base-dev`

- **problema:** a domain genérica (Arch + Hyprland + Docker) se chamava `archlinux`, nome de distro, não de papel.
- **por que é um problema:** scripts/docs e o hábito mental misturam “é Arch” com “é a modelo de onde nascem olie/televisao”.
- **resolvido como:** `virsh domrename archlinux base-dev` (`qemu:///system`). Disco pode continuar `archlinux.qcow2` até `sudo -E bin/workvm-rename-base-dev-disk.sh`. Projetos/cards já clonados não mudam de nome.

## UFW no host: forward libvirt preso em NIC antiga (`enp7s0`)

- **problema:** na VM `televisao`, `vm-setup.sh` / `pacman -Sy` dava timeout em todos os mirrors BR (`core.db` / `extra.db`). Ping para a internet na guest funcionava; TCP 443 não.
- **por que é um problema:** o sintoma parece mirror morto ou rede da guest. `televisao` é clone da modelo `base-dev` (na época `archlinux`), então a primeira hipótese era disco/imagem da modelo. Não era: o bloqueio estava no **host**. Qualquer WorkVM na `default` (NAT/`virbr0`) quebrava igual — `olie`, cards, etc.
- **resolvido como:** no host, UFW tinha `DEFAULT_FORWARD_POLICY=DROP` e a rota `ufw route allow in on virbr0 out on enp7s0`. A NIC viva passou a ser `enp6s0`; `enp7s0` sumiu. ICMP still passava (`ufw-before-forward` libera echo-request); TCP ia para a policy DROP. Ajuste: `ufw route delete … enp7s0` + `ufw route allow in on virbr0 out on enp6s0` (v4 e v6). Detalhe operacional em `host-setup.md`.

## Prompt `{{ code }}` não vai no commit do meta-repo

- **problema:** o agente (ou o paste manual no editor) substituía `{{ code }}` pelo código do card (ex. `DOP-1262`) dentro de `*/prompts/*.md` e podia subir isso no `git push` do meta-repo; no host-card a sujeira aparece em todas as janelas (meta-repo compartilhado).
- **por que é um problema:** o arquivo versionado deixa de ser template paste-ready; o próximo card herda um código errado.
- **resolvido como:** rule `prompt-templates-hands-off.mdc` + chat commands (`colleague review CODE` / `run prompt NAME CODE`) — o agente lê o template, substitui só na memória e executa; `bin/workvm-paste-prompt` opcional (clipboard); dirty → `git checkout --` antes do commit. Worktree de `~/git` por card **não** é a solução (peso e risco de commit no lugar errado).

## Colleague QA/CR: Validação/Revisado só depois de gap + mutation (Olie / Locav / Televisão)

- **problema:** na Olie (e Locav) o colleague paste aprovava PRs e avançava o funil, só *recomendando* `test-gap-analysis` + `mutation-testing` depois. A Televisão já tinha o gate; Olie/Locav divergiam.
- **por que é um problema:** o card saía de QA/CR sem os gates de teste; findings de gap/mutation chegavam tarde e o loop de correção quebrava.
- **resolvido como:** nos três produtos, com backend (Locav: também front no gap), ficar em QA/CR; aprovar/mover ('Validação' Olie; 'Revisado' Locav/TV) ou 'Corrigir' só depois do stack (ou skip explícito). `mutation-testing.md` no fim do stack colleague aplica o outcome combinado, não `pre-qa.md`.

## Clone dos CLONE_REPOS via gh (sem chave SSH)

- **problema:** `project-setup` clonava com `git clone` nas URLs `git@github.com:…` do `project.conf`. VM nova precisava de chave SSH só para baixar os repos.
- **por que é um problema:** o pre-QA já exige `gh auth login`; configurar SSH era atrito extra na WorkVM.
- **resolvido como:** `workvm_clone_repo` usa `gh repo clone` (HTTPS + `gh auth setup-git`) quando `gh auth status` ok; senão cai no `git clone` antigo. Clones já existentes com origin SSH passam para HTTPS no setup/login. `CLONE_REPOS` continua com URL SSH (slug é derivado).

## Super+E não abre o gerenciador de arquivos

- **problema:** Super+E chamava `dolphin`, mas o `vm-setup` não instalava o pacote. O bind falhava em silêncio.
- **por que é um problema:** a WorkVM fica sem explorador de arquivos pelo atalho do Hyprland.
- **resolvido como:** `setup_apps` instala `dolphin` (já era o `fileManager` no `hyprland.lua`).

## Super+R: hyprlauncher some de novo no virtio (sem virgl)

- **problema:** Super+R chamava `hyprlauncher-virtio.sh`; o processo abria e segfaultava. Sem UI.
- **por que é um problema:** a WorkVM fica sem menu de apps depois do `vm-setup`.
- **resolvido como:** a GPU do guest está `virtio_gpu` com `-virgl`. O compositor anunciava dmabuf FP16 (`AB4H`) e o hyprtoolkit escolhia esse formato; `CREATE_DUMB` no card falha com EINVAL. Mantém o preload render→card e no `hyprland.lua` liga `render.use_fp16 = 0` + `quirks.skip_non_kms_dmabuf_formats = true` para o menu ficar em XR24/AR24.

## Prompt `test-gap-analysis` antes da mutation (Olie / Locav / Televisão)

- **problema:** mutation endurecia testes existentes, mas gaps de requisito do card (casos de uso sem teste) só apareciam por acaso; Locav ainda tinha front sem passo de análise.
- **por que é um problema:** regressões do card passavam no mutate se ninguém escreveu o cenário; o autor não recebia lista clara do que faltava cobrir.
- **resolvido como:** `test-gap-analysis.md` nos três produtos, **antes** de `mutation-testing.md`. Televisão/Olie: só backend. Locav: backend + frontend (Cypress). Encadeado em workflow, colleague-review, implementation-validation e READMEs; gaps vão para o conteúdo do card e contam no outcome de QA/CR.

## Auto-review: leitura Olie (token + curl) sem card de permissão

- **problema:** o classificador Auto-review bloqueava `source ~/.config/environment.d` + `curl` Bearer mesmo em leituras (`get-forum`, threads, project GET); o agente pedia OK a cada card. Prompts Locav/Olie ainda mandavam curl inline para fórum e search.
- **por que é um problema:** atrito no colleague review / fórum; ordem de ferramenta divergia entre produtos.
- **resolvido como:** `.cursor/permissions.json` + helper só de fórum; **Tool preference** (MCP → `gh` → curl) em `televisao`/`locav`/`olie` `workflow-policy.md` e nota em `meta-repo.mdc`. Locav fórum passou ao helper. pre-QA cria PR com `gh` primeiro (exceção documentada).

## Catálogo de funil: MCP `index-project-funnels-tool`, não HTTP `get-available-steps`

- **problema:** para resolver 'Revisado' / etapas ao vivo, o agente caía em `curl` + `get-available-steps` e o Auto-review pedia permissão numa leitura.
- **por que é um problema:** atrito no colleague review / mutation outcome; o MCP já expõe steps e `funnel_status`.
- **resolvido como:** `workflow-policy` (Televisão, Locav, Olie) e `colleague-review` (TV/Locav) mandam `index-project-funnels-tool` primeiro; HTTP só se MCP estiver `needsAuth`/401.

## Televisão: workdir do backend é `/srv`, não `/var/www/html`

- **problema:** prompts e o MCP Boost da Televisão usavam `docker exec -w /var/www/html televisao-backend`; nesse container `/var/www/html` está vazio e o app monta em `/srv`. No merge MCP, o restore do stub ainda trazia o `mcp.json` do git da empresa (sem `-w`/env) e apagava o env do overlay.
- **por que é um problema:** mutation-testing (e qualquer passo PHP do prompt) falhava ao achar `vendor/bin/pest`/composer; o Boost no Cursor também rodava no workdir errado.
- **resolvido como:** prompts `televisao/prompts/{project,mutation-testing,implementation,correction,pre-qa}.md` e overlay `televisao-api/cursor/mcp.json` usam `/srv`; `workvm_apply_mcp` / `wrap_docker_mcp` faz `setdefault` de `WORKVM_DOCKER_MCP_WORKDIR=/srv` quando o container é `televisao-backend`.

## Colleague review: e2e do revisor só na Televisão (e Olie)

- **problema:** `televisao` `colleague-review.md` reprovava o card se a branch do autor não tinha Playwright; o revisor não criava os specs. Locav chegou a ser alinhado por engano ao mesmo modelo.
- **por que é um problema:** e2e da Televisão vive no meta-repo (não vai no clone da empresa); o autor não entrega isso. Locav Cypress está embutido em `locav-front` — aí quem escreve e2e é o autor na própria branch.
- **resolvido como:** Televisão (como Olie): revisor cria/estende `televisao-*-e2e` em `main` do `~/git`; falta de e2e do autor não é fail. Locav: autor cria Cypress em `cypress/e2e`; na review só se confere — missing coverage é fail; o revisor não adiciona specs.

## Colleague QA/CR: Corrigir só depois de review + mutation

- **problema:** `colleague-review.md` mandava mover o card para 'Corrigir' no fail antes de rodar `mutation-testing.md` quando o backend mudava.
- **por que é um problema:** o autor perdia a janela de mutation na branch ainda em QA/CR; o funil já pedia correção sem o segundo gate.
- **resolvido como:** outcome em `workflow-policy.md` / `colleague-review.md` / `workflow.md` / `mutation-testing.md`: com backend, ficar em QA/CR até os dois gates; mover para 'Corrigir' só se pelo menos um reprovar; pass completo só então vira 'Revisado'.

## Revisão de card dos colegas: mutation, comentários no card e aprovação/merge

- **problema:** a revisão de card do time só tinha dois caminhos (voltar para recuar ou avançar), mas o resultado não cobria a sequência completa: não havia instrução de recomendar `mutation-testing` depois que o backend é tocado, nem destino para registrar os comentários do que deve ser arrumado (ficavam no PR), nem o que fazer com aprovação/merge e status do funil.
- **por que é um problema:** o handoff para o tech lead e o merge final dependiam de regras informais; o autor recebia correções dispersas e o funil não refletia o resultado da revisão.
- **resolvido como:** `olie/prompts/colleague-review.md`, `locav/prompts/colleague-review.md` e `televisao/prompts/colleague-review.md` ganham a seção **Outcome** (fechamento em dois caminhos), a recomendação de `mutation-testing.md` quando o backend mudou, gravação dos comentários de correção no conteúdo do card, menção ao responsável ('atribuído a') no report e, no aprovação, marcação do PR aprovado (`pull_request_review_write`, event `APPROVE`), merge de todos quando todos passaram e mudança do status do funil para 'Revisado' (Olie move o card para 'Validação'; senão para 'corrigir'). `workflow.md` e `workflow-policy.md` dos três projetos documentam o fluxo completo do colleague review.

## OpenCode na guest sem MCP GitHub

- **problema:** `workvm-opencode.sh` só copiava `~/.cursor/mcp.json`; o GitHub no Cursor é plugin e não aparecia no OpenCode. Com `{env:GITHUB_PERSONAL_ACCESS_TOKEN}`, o OpenCode substituía var ausente por `""` e o remote respondia `400 Authorization header is badly formatted`
- **por que é um problema:** PRs/issues no agente local sumiam; o 400 parecia falha do MCP; o próximo run do script apagava config manual
- **resolvido como:** o script grava o PAT em `~/.config/opencode/github-pat` (`gh auth token` ou o env) e injeta `mcp.servers.github` com `Authorization: Bearer {file:github-pat}` e `oauth: false`

## project-setup usava meta-repo velho (MCP Boost atrás do remoto)

- **problema:** `./project-setup.sh` aplicava overlay/MCP do `~/git` local sem `git pull`; a VM Televisão rodava setup e ainda via `workvm-docker-mcp: waiting…` no stderr (script antigo)
- **por que é um problema:** o usuário achava que setup = última versão; o pull só rodava no próximo login (`workvm-git-pull.service`)
- **resolvido como:** `project-setup.sh` começa com `workvm_pull_repo` `--ff-only` na `main` do meta-repo; depois re-source de `lib/common.sh` e segue overlay/MCP

## Pull do meta-repo falhava por stub MCP com skip-worktree

- **problema:** `workvm_apply_mcp` deixa `.cursor/mcp.json` stub (`mcpServers: {}`) + `skip-worktree`; `git status` limpo, mas `git pull --ff-only` abortava se o remoto mudasse esses arquivos. `git checkout` ainda falhava com `Device or resource busy` com o Cursor com o arquivo aberto
- **por que é um problema:** login (`pull-meta.sh`) e pull manual do meta-repo ficavam atrás do `origin/main` até intervenção
- **resolvido como:** `workvm_mcp_prepare_repo_pull` restaura os stubs versionados antes do merge (escrita no mesmo inode, sem unlink); `workvm_pull_repo` chama isso; o `project-start` reaplica os stubs depois

## MCP Boost/Playwright falhava no login (compose ainda subindo)

- **problema:** no login o Cursor conectava `laravel-boost` / Playwright via `docker exec` antes do `olie-api-main` (e dos e2e) estarem `running`; o MCP ficava `failed` e não reconectava sozinho
- **por que é um problema:** Boost e Playwright sumiam da sessão até reload manual, em todo boot em que o Cursor abria cedo (autostart/restauração)
- **resolvido como:** `bin/workvm-docker-mcp.sh` espera o container (até 180s) e só então faz `docker exec -i`; `workvm_apply_mcp` reescreve qualquer server `docker exec` para esse wrapper; overlays olie (Boost + Playwright) e mcp.json dos e2e da televisão apontam para o script. O wait é silencioso no stderr — um `echo` de “waiting” fazia o Cursor marcar `[error]` e cancelar (`Client closed`) no meio da espera. Playwright ainda quebrava depois: `@latest` exige chrome-for-testing e sandbox; `bin/workvm-playwright-mcp.sh` usa o Chromium de `/ms-playwright` com `--headless --no-sandbox`. Televisão: overlay `televisao-api/cursor/mcp.json` + `WORKVM_DOCKER_MCP_WORKDIR=/var/www/html` no Boost (`televisao-backend`)

## Mutation testing liberava pre-QA com stack incompleto

- **problema:** depois de um arquivo no ledger, `next prompt` (ou o fechamento do paste) podia recomendar `pre-qa.md` enquanto ainda faltavam `*Test.php` do diff no `mutation-ledger.md`
- **por que é um problema:** o gate pessoal de mutação era pulado; o handoff seguia sem fechar o stack
- **resolvido como:** `mutation-testing.md` bloqueia `next prompt` → pre-QA até o ledger cobrir o change set; comando `next mutation` documentado em `workflow-policy.md` / README / pre-qa / validation para o próximo arquivo

## PHPStan sujava o Source Control do api-main

- **problema:** `vendor/bin/phpstan analyse` grava em `olie/api-main/storage/phpstan/` e o `.gitignore` da empresa não cobre esse path
- **por que é um problema:** a pasta aparece como untracked no Cursor/git status e polui o stage do card
- **resolvido como:** `CLONE_GIT_EXCLUDES` no `olie/project.conf` + `workvm_apply_clone_git_excludes` em `project-setup` e `project-start` grava `/storage/phpstan/` em `.git/info/exclude` do clone (local; sem mudar o remoto)

## Correction não apontava para implementation-validation

- **problema:** `olie/prompts/correction.md` e `locav/prompts/correction.md` terminavam sem next paste; só o `workflow.md` dizia o handoff
- **por que é um problema:** depois da correção o agente parava sem recomendar `implementation-validation.md`; o usuário tinha que lembrar ou colar à mão
- **resolvido como:** ambos os `correction.md` passam a indicar `implementation-validation.md` no completion (como o mapa do workflow); pre-QA/board validation só depois

## Agente mexia no repositório docs da Olie

- **problema:** correção/planos tratavam `olie-ai/docs` (`~/git/olie/docs`) como repo do card (rebase, conflito OpenAPI, PR)
- **por que é um problema:** docs.olie.ai não é entrega de card; rebase/PR ali gera conflito e atrito fora do produto
- **resolvido como:** rule `olie-docs-hands-off.mdc` (alwaysApply), seção em `olie/prompts/workflow-policy.md`, exclusão explícita em `correction.md` §4–5, linha em `layout.mdc`; agente aborta rebase acidental nesse clone

## Correção não obrigava revisar mídia do card

- **problema:** `correction.md` só dizia para ler análises já gravadas e não reanalisar; o agente podia montar o plano só com texto do retorno
- **por que é um problema:** screenshot e screencast do revisor ficavam fora do diagnóstico; faltava evidência visual no plano
- **resolvido como:** olie/locav/televisao `correction.md` ganham § Card media review — listar mídia via MCP, analisar a que ainda não tem `.md` (skills + fallback de vídeo), citar o media id no plano; nunca postar no conteúdo do projeto. O mesmo bloco entra em `implementation.md`, `colleague-review.md` e `production-review.md` (antes do plano, do veredito QA/CR e dos checks de produção)

## Conversão de vídeo parava quando o vid2agent estava fora

- **problema:** as skills `*-project-video-conversion` mandavam parar (ou só reportar blocker) quando `10.0.2.2:18080` não respondia
- **por que é um problema:** screencast do card ficava sem markdown reutilizável e a correção/implementação seguia sem a evidência do vídeo
- **resolvido como:** API continua preferida; se inacessível, o agente analisa localmente (ffprobe/ffmpeg + frames), grava o mesmo `cards/{CARD}/{MEDIA}.md` no schema fixo do vid2agent, com proveniência `agent-local`, sem instalar o stack na guest nem postar no conteúdo do projeto

## Pre-QA não subia o meta-repo em `main`

- **problema:** e2e, `cards/`, ledger e prompts mudavam em `~/git` no pre-QA e ficavam só locais; o remoto `main` não recebia
- **por que é um problema:** outra VM ou login com pull do meta-repo não via o trabalho do card; ledger e specs sumiam do remoto
- **resolvido como:** `pre-qa.md` (olie, televisao, locav) ganha §4.3 — commit e `git push` direto em `main` do meta-repo (sem PR), só com paths do card; stubs/secrets fora

## Comandos curtos no chat de develop (next prompt / try again / to correct)

- **problema:** depois de um prompt, o usuário tinha que colar o próximo arquivo inteiro, ou explicar de novo para retomar ou corrigir falhas da validation
- **por que é um problema:** atrito e resposta inconsistente entre sessões
- **resolvido como:** `workflow-policy.md` define `next prompt`, `try again` e `to correct`; `implementation.md` e `implementation-validation.md` reconhecem os três (`next` de checklist continua separado). O mesmo fluxo (mutation após validation se backend + comandos) foi aplicado em `televisao/prompts/` e `locav/prompts/` (`televisao-api` / `LocavApi`)

## Validation ia direto para pre-QA sem mutation no backend

- **problema:** depois de `implementation-validation.md`, o fluxo sempre apontava para `pre-qa.md`, mesmo quando o card mudava `api-main`
- **por que é um problema:** o mutation testing pessoal ficava fora da ordem do card e o backend ia para QA/CR sem essa passada
- **resolvido como:** validation recomenda `mutation-testing.md` só se o diff local tocou `api-main`, e depois `pre-qa.md`; sem backend, segue direto para pre-QA. `workflow.md`, `README.md`, `pre-qa.md` e `mutation-testing.md` alinhados

## Correção com conflito parava sem force-push da branch

- **problema:** `olie/prompts/correction.md` mandava iniciar o rebase, deixar o conflito com o usuário e parar. Depois da resolução, o agente não tinha ordem de atualizar o remoto
- **por que é um problema:** o PR ficava no tip antigo; o `git push` normal falha após rebase e o revisor continua vendo conflito
- **resolvido como:** o prompt manda, após o usuário resolver, confirmar o rebase limpo e fazer `git push --force-with-lease` na branch do card/PR antes de seguir o resto da correção

## Meta-repo só fazia fetch no login

- **problema:** `workvm-git-pull.service` rodava `git fetch` em `~/git`; o working tree ficava velho até um pull manual
- **por que é um problema:** overlays, prompts e scripts do meta-repo não entravam na VM no login
- **resolvido como:** `bin/pull-meta.sh` chama `workvm_pull_repo` (`fetch` + `merge --ff-only`). Divergência ou rede só avisam; a sessão sobe igual

## Revisão de produção resolvia o reCAPTCHA sozinha

- **problema:** no login de `gui1.olie.ai` o desafio de imagens aparecia e o agente clicava nos quadros até passar
- **por que é um problema:** a revisão atrasava muito antes de testar o card
- **resolvido como:** `olie/prompts/production-review.md` manda parar, destrancar o browser e pedir ao usuário para resolver o desafio. O teste segue depois que o login entra no app

## A VM da Olie não clona o repositório docs

- **problema:** `project.conf` não listava `olie-ai/docs`. O `project-setup.sh` não criava `olie/docs`
- **por que é um problema:** card que altera o guia (ex. DOP-1233, PR 9) não tem o clone nesta VM
- **resolvido como:** `CLONE_REPOS` ganha `git@github.com:olie-ai/docs.git` em `olie/docs`, branch `main`. O workspace abre essa pasta junto com os outros clones

## `vm-setup` pede um pacote que o mirror já apagou

- **problema:** `pacman -S docker-buildx` baixava `docker-buildx-0.38.0-1` e os mirrors respondiam 404. O arquivo no mirror era `0.38.1-1`
- **por que é um problema:** o sync local (`/var/lib/pacman/sync`, aqui de 17 de outubro) ainda citava o nome antigo. O script não atualizava o banco, a transação abortava e o Docker ficava sem buildx
- **resolvido como:** `setup_base` roda `pacman -Sy` antes do primeiro `-S`. O resto do script instala o nome que o mirror publica agora

## Relato e revisão de produção sem o preview hospedado

- **problema:** card com relato, e a revisão de produção, não tinham URL nem conta do preview em `dashboard.enterscience.com.br`. O agente ficava no localhost ou parava sem credencial
- **por que é um problema:** o problema relatado está nesse preview; o localhost não reproduz
- **resolvido como:** `implementation.md` manda reproduzir o relato nesse dashboard e no Meet, com as duas contas de teste. `production-review.md` testa no mesmo host. A senha fica no prompt e fora do relatório

## `.cursor` do boilerplate-next some do stage no próximo login

- **problema:** o `project-start` reescreve `.mdc` com `alwaysApply: true` e marca `skip-worktree`
- **por que é um problema:** o `.cursor` deste boilerplate é para subir no git do clone. O próximo arquivo, ou a próxima edição dessas rules, não aparece no stage
- **resolvido como:** `CURSOR_CLONE_PATCH=0` em `boilerplate-next/project.conf`. O patch dos outros projetos continua. `workvm-local-agents.mdc` segue no exclude local

## Prompt da Televisão parava em `needsAuth` com o MCP autenticado

- **problema:** o card `tv-35` parava antes de carregar. O desktop mostrava `olie-flow-ai` autenticado; o agente lia `needsAuth` e não usava a HTTP de management
- **por que é um problema:** Olie e Locav já tratam esse status como **MCP auth** e seguem. O prompt da Televisão ainda mandava parar e tratar como premissa quebrada
- **resolvido como:** a mesma exceção entrou nos prompts da Televisão e em `workflow-policy.md`. `needsAuth` com o desktop autenticado não para o card: o agente usa o proxy local ou a HTTP de management

## Prompt via `needsAuth` com o MCP já autenticado no desktop

- **problema:** o Cursor desktop e o request do MCP diziam que `olie-flow-ai` estava autenticado; o agente do prompt parava em `needsAuth` e pedia `mcp_auth`
- **por que é um problema:** `api.olie.ai` publica descoberta OAuth, o Cursor ignora o Bearer do `mcp.json`, e o login interativo não existe nesse agente. O card (ex. `tv-35`) não carrega
- **resolvido como:** o merge aponta `olie-flow-ai` para `127.0.0.1:47331`. O proxy responde 404 na descoberta e encaminha `/mcp/management` com `OLIE_FLOW_AI_MCP_TOKEN`. O workflow manda seguir por aí, ou pela HTTP de management, sem pedir login de novo

## `docker compose up` do Next não instala

- **problema:** o `project-start` sobe o compose, o build avisa que o plugin buildx não existe, cai no builder clássico e para no `RUN --mount` do `Dockerfile.dev`
- **por que é um problema:** o `npm ci` não roda. O login segue com "docker compose failed" e a porta 3000 não sobe
- **resolvido como:** `vm-setup.sh` instala `docker-buildx` junto com `docker` e `docker-compose`. O Compose volta a usar BuildKit, que é o que o `RUN --mount` do guia Docker exige

## Projeto boilerplate-next em `boilerplate-next/`

- **problema:** o clone `fabriciogferreira/boilerplate-next` existia em `boilerplate-next/boilerplate-next/`, mas o meta-repo não tinha `project.conf`
- **por que é um problema:** o `project-setup.sh` não lista projeto por nome no script; descobre pasta com `project.conf`. Sem isso o menu não oferece o Next, o login não faz fetch nem abre o workspace
- **resolvido como:** definição em `boilerplate-next/` (`project.conf`, workspace), clone fora do git, branch `main`, `COMPOSE_FILE=compose.yaml`. Sem `post-clone.sh`: não há `.env` nem bootstrap. Produção do compose ficou no profile `prod` para o `docker compose up -d` do login subir só `nextjs-dev` (os dois publicam a porta 3000). Escolhas do container: `DECISIONS.md` no clone

## Prompt do card era colado à mão no Opbed

- **problema:** mudar `olie/prompts`, `locav/prompts` ou `televisao/prompts` não mudava o site. O texto tinha de ser copiado e salvo em produção
- **por que é um problema:** o arquivo e o Opbed divergem, e o paste do card usa a cópia velha
- **resolvido como:** o `PUT /api/user/1` regrava só `config.prompts`, com o `config` inteiro em volta. Olie fica na empresa 1. Locav e Televisão ficam nos projetos 4 e 6, porque a API aceita um dono só. A rule `opbed-prompts.mdc` manda repetir isso no próximo create, update ou delete. O token fica em `~/.config/environment.d/opbed.conf`

## Chat da Olie, Locav e Televisão abria a execução do card

- **problema:** os prompts mandavam o agente fazer `POST …/project-executions` ao começar implementação, correção ou revisão
- **por que é um problema:** a página `/job` do Opbed já dispara essa execução. O chat abria outra
- **resolvido como:** Olie, Locav e Televisão não chamam mais esse request. A política diz para seguir o card sem esperar a execução. Quem envia é o `/job`

## Análise de mídia da Televisão iria para o conteúdo do card

- **problema:** imagem e vídeo do card da Televisão não tinham skill. Sem ela, a análise entra no conteúdo do projeto
- **por que é um problema:** o texto da mídia polui o card, e a correção analisa de novo
- **resolvido como:** `televisao-project-image-analysis` e `televisao-project-video-conversion` no overlay dos quatro clones. O Markdown vai para `~/git/televisao/cards/{CARD_CODE}/{MEDIA_ID}.md` e é commitado neste meta-repo, como na Olie. Não usa `save-media-tool`

## Televisão sem prompts de card

- **problema:** o trabalho no board da Televisão não tinha texto para colar no agente. Os da Locav cobrem o mesmo funil, com outros nomes de etapa e outro stack
- **por que é um problema:** cada card reexplica ordem, PR e revisão, e o agente segue Cypress e portas da Locav
- **resolvido como:** `televisao/prompts/` copia o conjunto da Locav com as etapas deste board ('Não Iniciado', 'Revisão de produção', e as demais). Playwright fica nos e2e do meta-repo. Os quatro clones e o `televisao-backend` substituem LocavApi e o front. O id da etapa continua ao vivo, sem número fixo

## Televisão em 1 vCPU

- **problema:** a domain `televisao` estava em 1 vCPU. No primeiro minuto da subida o load foi ~3,7
- **por que é um problema:** compose, Cursor e browser ficam na fila nesse núcleo
- **resolvido como:** `<vcpu>4</vcpu>` em `televisao/config-vm.xml`. O 9 continua só na Olie, a guest mais pesada. Aplicar com a VM parada: `bin/apply-config-vm.sh televisao`

## Televisão fica em 8 GiB

- **problema:** a domain `televisao` em 8 GiB, com compose + Cursor IDE + uma aba, mostrava ~2,6 GiB available e ~54 MiB de swap na subida. Parecia pouco
- **por que é um problema:** aumentar sem medida tira RAM do host de 32 GiB
- **resolvido como:** `televisao/config-vm.xml` permanece em 8 GiB. O available cobre a carga medida; o swap da subida não pede mais memória

## Login da VM abria Cursor e Brave

- **problema:** ao subir a VM o `project-start` abria o Cursor e o Brave
- **por que é um problema:** o trabalho passou a ser pelo site; a janela e o browser na VM só ocupam a sessão
- **resolvido como:** o login chama o `project-start` sem abrir os dois. A instalação do projeto passa `WORKVM_OPEN_APPS=1` e abre, para conferir o que subiu

## A fila do Job não disparava a execução do board

- **problema:** marcar os cards gravava a ordem, mas ninguém mandava o request de execução
- **por que é um problema:** o board continua sem mostrar o card, e o exemplo do request já estava no workflow
- **resolvido como:** o botão Executar manda o `POST …/project-executions` do `workflow-policy.md`, um card por vez, pelo tempo de 'Tempo que eu acho', e só então abre o próximo

## A ordem da execução no board só existia no prompt

- **problema:** os códigos e a ordem da execução visível tinham que ser colados no chat
- **por que é um problema:** cada conversa pedia a lista de novo, e o Job já é onde os cards estão
- **resolvido como:** no Job, o checkbox grava `config.board_executions` na ordem marcada. O prompt lê essa lista e não pede os códigos

## Revisão de produção ainda abria o EsOlie

- **problema:** o prompt de production review verificava `https://esolie.olie.ai/overview`
- **por que é um problema:** o que vale para o card é o frame gui1, e sem login a página não mostra o produto
- **resolvido como:** a revisão entra em `https://gui1.olie.ai/auth/login` no frame gui1. A senha fica só em `olie/prompts/production-review.md`

## Vários cards na VM e uma execução visível no board

- **problema:** as VMs permitem trabalhar vários cards ao mesmo tempo, e o board da Olie mostra uma execução por vez
- **por que é um problema:** abrir duas execuções ao mesmo tempo aparece para a equipe como dois cards em execução
- **resolvido como:** o usuário avisa a equipe quais códigos vai pegar. Neste chat, os códigos informados só recebem o request de execução, em sequência, cada um pelo tempo de 'Tempo que eu acho'. O trabalho nos cards segue em paralelo nas VMs

## Card não tem como desligar a VM sem apagar o clone

- **problema:** o card só ligava a VM ou a apagava junto com o disco
- **por que é um problema:** pausar o trabalho destruía o clone, e deixar ligado ocupava o host
- **resolvido como:** o botão Pausar manda `shutdown` no clone `projeto-codigo`. A domain e o disco ficam. O Conectar seguinte liga a mesma VM

## Chat do card junta o home com ~/git

- **problema:** o `cursor-agent` respondia `Workspace directory does not exist: /home/fabricio/~/git`
- **por que é um problema:** o card manda o workspace `~/git` e a mensagem não abre o repositório
- **resolvido como:** o turno troca `~/` por `$HOME` antes do `--workspace`. O caminho que chega no CLI é absoluto

## Mensagem do card não acha o comando agent

- **problema:** `POST /api/work-vm/turn` respondia `bash: line 1: agent: command not found`
- **por que é um problema:** o SSH da VM já funciona, mas o chat chama o CLI `agent`. A VM só tem o aplicativo `cursor` (`cursor-bin`), que não inclui esse comando
- **resolvido como:** o comando é `cursor-agent`, do pacote AUR `cursor-cli` (`yay -S cursor-cli`). O turno instala esse pacote quando o comando falta. `vm-setup.sh` instala junto com o `cursor-bin`. Sem login e sem `~/.config/workvm/cursor-api-key`, a resposta diz isso em vez de `Not logged in`

## Mensagem do card estoura o SSH da VM

- **problema:** `POST /api/work-vm/turn` respondia `ssh: connect to host 192.168.122.1 port 22947: Connection timed out`
- **por que é um problema:** o chat do card sai do site no Coolify. Esse IP e essa porta só existem na rede da libvirt, então a mensagem não chega na VM
- **resolvido como:** o site grava o turno em `users.config.work_vm_commands` (`action=turn`) e o agente no host faz o SSH do guest com a chave que já lê os MCPs. O `agent` roda lá, e a resposta volta pelo mesmo pedido

## Apagar a VM no site espera três minutos e diz que o host não respondeu

- **problema:** `POST /api/work-vm/drop` ficava até o prazo (180s) e voltava `O host não respondeu o pedido da VM`, com `name` e `ip` nulos
- **por que é um problema:** o host já tinha apagado a VM no mesmo segundo e publicado o resultado. O card tratava isso como falha e o id do pedido era reutilizado, então a consulta seguinte não achava a resposta
- **resolvido como:** o resultado fica numa cópia (cache) que a consulta lê se a lista em `users.config` perder a linha. O id não recua (`work_vm_command_seq`). A primeira consulta é imediata e não reaproveita um 404 cacheado. Criar ou apagar a VM passa na frente da leitura de MCPs

## Lista de MCPs da VM falha às vezes

- **problema:** `POST /api/work-vm/mcps` às vezes voltava `O host não respondeu o pedido da VM`
- **por que é um problema:** a lista some no card mesmo com a VM no ar. Um GET falho encerrava a espera, e um clone em andamento segurava a leitura
- **resolvido como:** o site insiste na consulta até o prazo. Um pedido de MCP que ficou `running` sem o agente devolver resultado voltava a ser `pending` na busca seguinte, senão o card esperava esse pedido até desistir. O agente no host lê MCPs enquanto o clone roda

## Card em produção não cria a VM no host

- **problema:** criar ou apagar um card em opbed.com fazia SSH para `fabricio@192.168.122.1` e a conexão estourava
- **por que é um problema:** esse endereço só existe na rede da libvirt. O site no Coolify não alcança o host, então a VM não nasce e o delete também falha
- **resolvido como:** o site grava o pedido em `users.config.work_vm_commands` quando a porta 22 do host não responde. Não há tabela: isso não é dado do produto. `bin/workvm-card-agent.py` no host busca o pedido e roda o script local, inclusive a lista de MCPs da VM. O token fica em `~/.config/workvm/agent.conf`. Dentro da VM o SSH direto continua

## Plano do Cursor acaba e a VM fica sem agente

- **problema:** o chat do Cursor para quando o plano acaba. O OpenCode não lê `~/.cursor/mcp.json`, então modelo local e MCP não entram juntos
- **por que é um problema:** a VM já tem o merge de MCP do login e a RTX no host, e mesmo assim não há um comando que ligue os dois
- **resolvido como:** `bin/workvm-opencode.sh` roda dentro da guest. Instala o OpenCode 2, grava `~/.config/opencode/opencode.json` com o Ollama em `10.0.2.2:11435` (`qwen3.8-4b`) e traduz os MCP do Cursor (`${env:}` vira `{env:}`). Não sobe o Ollama nem copia token

## Opbed no teto genérico de RAM/vCPU

- **problema:** a domain `opbed` ficava em 8 GiB e 1 vCPU. A Olie, com a mesma carga (compose, Cursor, browser), está em 12 GiB e 9 vCPU
- **por que é um problema:** a guest troca e o host não sabe o teto certo desse projeto
- **resolvido como:** `opbed/config-vm.xml` com o mesmo teto da Olie. `apply-config-vm.sh` só lê nome, RAM e vCPU

## Hook do vid2agent não roda na subida seguinte

- **problema:** a `vid2agent-code` foi religada e `10.0.2.2:18080` voltou a recusar conexão. O Ollama, que já estava no host, continuou
- **por que é um problema:** o libvirt 12.8 só lê `/etc/libvirt/hooks/qemu`. O symlink tinha ficado em `~/.config/libvirt/hooks/qemu`, então o `virtqemud` não chamou o script. O `setsid` de dentro do hook também falha quando o libvirt é o líder de sessão
- **resolvido como:** o script vai para `/etc/libvirt/hooks/qemu` e usa `nohup`. O `virtqemud` precisa reiniciar uma vez para reler a lista de hooks. O forward desta VM foi recolocado na hora (`127.0.0.1:18080` → guest `:80`)

## vid2agent-code sobe sem API nem Ollama

- **problema:** o forward `127.0.0.1:18080` e o Ollama em `127.0.0.1:11434` dependiam de um hook só no host. Esse arquivo sumiu. A VM `vid2agent-code` ficava running e as outras tomavam connection refused em `10.0.2.2`
- **por que é um problema:** a conversão de vídeo do card falha mesmo com a VM ligada; o agente baixa o MP4 e para no `curl`
- **resolvido como:** `bin/workvm-libvirt-qemu-hook.sh` é o hook da sessão (`~/.config/libvirt/hooks/qemu`). Ele chama o hostname e `bin/workvm-vid2agent-hook.sh`. Na subida, restore e reconnect, o script reaplica o `hostfwd` para a porta 80 da guest e sobe `ollama serve` se o binário existir. Na descida, mata só o Ollama que ele mesmo subiu. Não instala Ollama nem `vulkan-radeon`. Sai 0: hook com erro aborta o start e mata a guest no reconnect

## `php artisan test -p` recusa `--parallel` na VM Olie

- **problema:** `php artisan test -p` respondia `Unknown option "--parallel"`. No computador dos colegas o mesmo comando roda
- **por que é um problema:** o pre-QA pede a suíte em paralelo e para quando o runner não sobe
- **resolvido como:** o `composer install` do `olie/post-clone.sh` usa `--no-plugins`, então o plugin do Pest não grava `vendor/pest-plugins.json`. Sem esse arquivo o Pest não carrega o plugin de paralelismo e o PHPUnit rejeita a opção. O post-clone agora roda `composer pest:dump-plugins` depois do install. Nesta VM o arquivo foi gerado; `php artisan test -p` passou (19 testes, 9 processos)

## `.cursor` do Locav aparecia no Source Control

- **problema:** o overlay copia skills para `.cursor` nos clones do Locav, e essa pasta surgia como arquivo novo no Git
- **por que é um problema:** o remoto da Olie já ignora `.cursor`. O do Locav não, e uma mudança no `.gitignore` de lá não pode ser enviada. O ignore feito à mão em `.git/info/exclude` sumia num clone novo
- **resolvido como:** `workvm_sync_overlay_repo` grava `/.cursor` no exclude do clone sempre que o overlay é aplicado (`project-setup` e login)

## Pre-QA do Locav parava no checklist 'Pull request created'

- **problema:** o pre-QA pedia marcar 'Pull request created' no funil antes de mover o card para QA/CR
- **por que é um problema:** o funil Dev - Locav não tem checklist de etapa. Esse item só existe na Olie, e o handoff ficava parado
- **resolvido como:** a instrução saiu de `locav/prompts/pre-qa.md`, `validation.md` e `workflow.md`. O prompt da Olie continua marcando o item

## Locav sem o teto de RAM/vCPU da Olie

- **problema:** só a Olie tinha `config-vm.xml` (12 GiB / 9 vCPU). A Locav sobe a mesma carga (compose, Cursor, browser) e ficava no teto genérico da domain
- **por que é um problema:** a guest troca e o host não sabe o teto certo desse projeto
- **resolvido como:** `locav/config-vm.xml` com o mesmo teto. O script só lê nome, RAM e vCPU; disco, UUID e MAC da Olie não entram. Ainda não aplicado no host

## Projeto sem card não tem para quem mandar o prompt

- **problema:** o chat e o envio de prompt só existem no card, e o card clona `projeto-codigo`. Um projeto como o Opbed não cria card, então nenhuma VM sobe e o prompt do projeto não sai
- **por que é um problema:** o prompt fica só na tela; a VM que já existe com o nome do projeto não recebe
- **resolvido como:** o projeto tem chat e botão de enviar no prompt. `bin/workvm-open-project-vm.sh` só liga essa domain e publica o SSH. Não clona

## Chat do card entra na VM errada e a chave é recusada

- **problema:** o chat fazia `ssh fabricio@10.0.2.15`. Toda VM em rede user tem esse endereço, e a partir do container do site ele é a própria VM do Opbed. A chave oferecida era a do host, que o guest não autoriza
- **por que é um problema:** o prompt não chega na VM do card; a resposta é `Permission denied`
- **resolvido como:** VM com NIC `user` ganha `hostfwd` de uma porta alta no host (`192.168.122.1`) para o sshd do guest. O chat usa essa porta e a chave `workvm_ed25519`, separada da chave do host libvirt. O endereço `10.0.2.15` deixa de ser aceito como IP do card

## Apagar o card deixa a VM clone no host

- **problema:** o delete do card só tirava o card do config. A domain `projeto-codigo` continuava ligada, com disco
- **por que é um problema:** concluir o card não libera RAM nem disco no host
- **resolvido como:** `bin/workvm-drop-card-vm.sh` desliga e faz `undefine --remove-all-storage` só do clone. O nome tem de ser `modelo-código`, e um disco compartilhado com a modelo aborta. O site chama isso por SSH ao apagar o card e só então remove o card. Se o clone ainda estava sendo criado, um segundo drop roda quando o clone termina. Criar o card de novo com o mesmo nome tira essa marca, senão o clone novo era apagado no fim

## hyprlauncher morre de novo no virtio

- **problema:** Super+R abre o hyprlauncher, o GBM pede `DRM_IOCTL_MODE_CREATE_DUMB` no render node e o virtio responde EPERM. O processo leva segfault
- **por que é um problema:** a VM fica sem menu de aplicativos
- **resolvido como:** `bin/hyprlauncher-virtio.sh` compila `lib/virtio-dri-primary.c` e redireciona o open do render node para o nó primário (`/dev/dri/by-path/*-card`), onde o mesmo ioctl funciona. O `hyprland.lua` chama esse script

## Flameshot não captura no Hyprland

- **problema:** print no Wayland não abre; o compositor não entrega a tela sem o portal, e a janela do Flameshot cai fora do monitor
- **por que é um problema:** a VM fica sem screenshot
- **resolvido como:** `vm-setup` instala `flameshot`, `xdg-desktop-portal`, `xdg-desktop-portal-hyprland` e `xdg-desktop-portal-gtk`. O portal 1.22 não exporta Screenshot sem o impl de Access, que só o backend gtk traz. O `HDMI-A-5` virtual (640x480) faz o `grim` travar na captura cheia; o `hyprland.lua` desliga essa saída. A window rule fixa a janela em DP-1. PrtSc dispara `flameshot gui`. O Flameshot 14 não lê `useGrimAdapter` nem `disabledGrimWarning`; esse ini saiu

## Chat do card recebe connection refused

- **problema:** enviar o prompt fazia `ssh` para a VM do card e a porta 22 recusava a conexão
- **por que é um problema:** o turno nem começa; o `agent` não roda
- **resolvido como:** o Arch instala o OpenSSH com o `sshd` desligado. O login (`project-start`), o script do guest agent e o hook de hostname passam a ligar o `sshd` e a autorizar `lib/workvm_ed25519.pub`. O site usa `~/.ssh/workvm_ed25519`, não a chave do GitHub

## Atalhos de grupo e workspace estouram o teclado

- **problema:** cada ação de grupo ou workspace 01–99 precisava de um acorde longo, e o overlay do Hyprland só tinha os binds de exemplo
- **por que é um problema:** a VM fica sem hjkl para grupos e sem picker de workspace; o `vm-setup` copia esse `hyprland.lua`
- **resolvido como:** submaps no `.config/hypr/hyprland.lua` (grupos em SUPER+G, fechar workspace, mover janelas do workspace, picker 01–99 em SUPER+P). O pseudo de exemplo saiu do SUPER+P

## vm-setup usa hyprland do extra (não hyprland-git)

- **problema:** `setup_apps` instalava `hyprland-git` (AUR); numa VM com `hyprland` do extra (ou o contrário) o pacman conflita e o setup morre
- **por que é um problema:** bootstrap da VM para no compositor; AUR demora e quebra com `--noconfirm` no conflito
- **resolvido como:** `setup_apps` instala `hyprland` do extra. Se ainda houver `hyprland-git`, remove antes e segue com `pacman -S --needed hyprland`

## vm-setup reinicia só na primeira execução

- **problema:** depois do `vm-setup` o SDDM autologin e o Hyprland só valem no próximo boot, e o operador esquecia de reiniciar
- **por que é um problema:** a VM “pronta” ainda estava no TTY sem sessão gráfica; o próximo passo (`project-setup`) ficava confuso
- **resolvido como:** ao terminar com sucesso, se não existir `~/.config/workvm/vm-setup-booted`, grava o marker e chama `sudo reboot` (não `systemctl reboot` — polkit nega sem askpass). Reexecuções do script não reiniciam

## Super+R ainda instala fuzzel

- **problema:** o bind do menu já era `hyprlauncher`, mas o `setup_apps` ainda instalava `fuzzel` e o comentário dizia que o Super+R era ele
- **por que é um problema:** VM nova ganha o launcher que o Hyprland não abre, e o comentário mente sobre o atalho
- **resolvido como:** `setup_apps` instala `hyprlauncher` e deixa de instalar `fuzzel`. O `fuzzel` foi o substituto enquanto o hyprtoolkit quebrava no Virtio (GBM)

## Card novo não ganha VM

- **problema:** cadastrar o card no site não procura nem liga a VM `nomeDoProjeto-código`
- **por que é um problema:** o clone fica manual no host, e o card abre sem máquina
- **resolvido como:** `bin/workvm-ensure-card-vm.sh` no host liga a domain se ela existe; senão clona a VM do projeto (desligada) e dá start. O site chama isso por SSH em `fabricio@192.168.122.1` ao salvar o card

## Hostname da VM continua jarvis-vm depois do rename

- **problema:** ao clonar um card o nome da domain vira `nomeDoProjeto-dop-24`, mas o sistema continua `jarvis-vm`
- **por que é um problema:** o site só vê esse hostname e o IP; as VMs parecem iguais
- **resolvido como:** `vm-setup.sh` liga `qemu-guest-agent` e `avahi-daemon`. VM já existente roda `bin/workvm-install-guest-agent.sh` uma vez. O hook do host chama `bin/workvm-set-guest-hostname.sh` em `started`/`restore` (tenta `qemu:///system` e `qemu:///session`) e o agente roda `hostnamectl`. O Avahi publica o nome novo na rede da libvirt

## Locav não converte imagem e vídeo do card

- **problema:** o prompt da Locav só dizia onde salvar a análise; não havia skill no overlay
- **por que é um problema:** o agente não analisa a imagem nem chama o vid2agent, e na correção o texto da mídia não existe
- **resolvido como:** as mesmas skills da Olie, com destino `~/git/locav/cards/`, em `locav/overlay/` (`LocavApi` e `locav-front`). Áudio continua só na regra de não postar a análise, como na Olie

## Login do use-url-query não sobe o compose

- **problema:** depois do reboot `docker ps` vinha vazio
- **por que é um problema:** o clone tem `docker-compose.yml` (bun), mas o `project.conf` não setava `COMPOSE_DIR`, então o `project-start` pulava o Docker
- **resolvido como:** `COMPOSE_DIR` aponta para o clone; o arquivo default já é `docker-compose.yml`. Sem `WAIT_URL`: o serviço não escuta HTTP

## Setup de use-url-query aborta em CHROMIUM_URLS

- **problema:** `project-setup.sh use-url-query` morria em `lib/cursor.sh` com `CHROMIUM_URLS: unbound variable`
- **por que é um problema:** o conf da biblioteca não declara browser; com `set -u` a rule do projeto ativo não grava e o `workvm.service` não habilita
- **resolvido como:** a rule só lê o array se ele existir; o setup zera `CHROMIUM_URLS` antes do `source`, como o `project-start.sh` já fazia

## Projeto use-url-query em `use-url-query/`

- **problema:** WorkVM sem definição para o pacote `fabriciogferreira/use-url-query` (`main`)
- **por que é um problema:** sem `project.conf` o `project-setup` não clona nem abre o workspace
- **resolvido como:** pasta `use-url-query/` com clone em `use-url-query/use-url-query`; pós-clone vazio. O compose do clone entra no login via `COMPOSE_DIR`

## apply-config-vm não redefine a domain inteira

- **problema:** `virsh define` de `olie/config-vm.xml` falhava porque a domain viva tem outro UUID; o script seguia e imprimia ok com a RAM/vCPU antigas
- **por que é um problema:** o teto novo não entra, e o log mente
- **resolvido como:** com a guest `shut off`, só `setmaxmem` / `setmem` / `setvcpus`; falha de `virsh` encerra sem ok. UUID e MAC da domain ficam como estão

## Olie WorkVM: teto de 9 vCPU

- **problema:** a guest `olie` estava em 4 vCPU; o teto é o que limita o paralelismo, não uma reserva no host
- **por que é um problema:** compose, front e Cursor da Olie são a carga mais pesada e ficavam abaixo do que o host aguenta com uma VM só
- **resolvido como:** `<vcpu>9</vcpu>` em `olie/config-vm.xml`; aplicar com a VM parada via `bin/apply-config-vm.sh olie`

## Clone no primeiro boot da VM clonada, antes do DNS

- **problema:** o autologin abre o menu do `project-setup` e o `git clone` morre com `Could not resolve hostname github.com: Temporary failure in name resolution`
- **por que é um problema:** a VM nova não clona o projeto. A frase de access rights do git parece permissão de SSH; abrir o Cursor e rodar de novo só funciona porque o DHCP já subiu
- **resolvido como:** `workvm_clone_project_repos` espera o DNS de `github.com` (até 60s) antes do clone. Se já resolve, segue na hora. O fetch do login continua só avisando

## MCP Olie só em olie / locav / televisao

- **problema:** `workvm_apply_mcp` mesclava **todos** os `mcps/*.json` no login; VM de opbed/etc. ganhava `olie-flow-ai` mesmo sem `MCP=`
- **por que é um problema:** token/tools do board Olie em projeto que não usa; contexto e risco à toa
- **resolvido como:** merge só de `mcps/<MCP>.json` quando o conf declara; `MCP=olie` recusado fora de olie, locav e televisao

## Mutation testing pessoal, arquivo a arquivo

- **problema:** o tech lead apontou testes que continuam verdes se o comportamento mudar; mutation testing do Pest mostra isso, mas a Olie não adota essa prática no `api-main`
- **por que é um problema:** colocar `covers()`, PCOV ou job de CI no remoto da empresa impõe um fluxo que o time não pediu; sem um registro, cada sessão recomeça do zero
- **resolvido como:** prompt `olie/prompts/mutation-testing.md` prepara PCOV e o cache de plugins só no container, muta um `*Test.php` por colagem (`--covered-only`, sem `covers()`), e empilha o resultado em `olie/prompts/mutation-ledger.md` no meta-repo

## Checklist 'Pull request created' via toggle-funnel-checklist

- **problema:** pre-QA pedia marcar 'Pull request created' no QA/CR, mas o MCP devolvia `project_checklists` vazio
- **por que é um problema:** handoff incompleto; item fica desmarcado na UI
- **resolvido como:** HTTP `POST /api/management/toggle-funnel-checklist` com `OLIE_MANAGEMENT_TOKEN`, `project_id` e `step_checklist_id` vivos; documentado em `workflow-policy.md` e Phase 5 do `pre-qa.md`

## GitHub: pre-QA via `gh`, não MCP

- **problema:** GitHub MCP (`create_pull_request`) abria form deferral (às vezes invisível) e não setava assignee/label de forma confiável; PAT no `environment.d` + MCP `github-direct` ainda falhava sem scope `read:org`
- **por que é um problema:** handoff QA/CR incompleto; agente parado no create PR
- **resolvido como:** `github-cli` no `vm-setup.sh`; Phase 4 do `olie/prompts/pre-qa.md` (e nota no Locav) usa `gh pr create` / `gh pr edit`; removido `mcps/github.json`; auth com `gh auth login` (não PAT no environment.d para GitHub)

## Olie WorkVM: RAM 8 → 10 → 12 GiB (config versionada)

- **problema:** guest `olie` com 8 GiB já usava ~1.8 GiB de swap sob carga (compose + Cursor + browser); o XML da domain não estava no git (`olie/*` no ignore); com 10 GiB ainda restava ~0.7 GiB de swap e pouco margem para Postman/DBeaver
- **por que é um problema:** swap = lag; sem XML versionado não dá para distribuir RAM/CPU por projeto de forma repetível
- **resolvido como:** `olie/config-vm.xml` alinhado à domain real `olie` (não `olie-dop-1206`); **12 GiB** / 4 vCPU; `bin/apply-config-vm.sh` resolve domain pelo `<name>` ou pelo id do projeto e aplica só com a guest `shut off`

## Tokens Olie: MCP ≠ management HTTP

- **problema:** prompts usavam `OLIE_FLOW_AI_TOKEN` no MCP e nas requests `/api/management/...`; o PAT do MCP não tem `management:access`
- **por que é um problema:** project-execution / move de card falhavam com 403 mesmo com MCP ok
- **resolvido como:** `OLIE_FLOW_AI_MCP_TOKEN` só no MCP; `OLIE_MANAGEMENT_TOKEN` nas requests HTTP; docs em `environment.d/README.md` e `workflow-policy.md`

## URL de produção nos prompts Olie (EsOlie)

- **problema:** 'Revisão de Produção' pedia “identificar a URL” sem fixar onde testar
- **por que é um problema:** agente/local confundem `*.olie.localhost` com evidência de produção
- **resolvido como:** URL canônica **https://esolie.olie.ai/overview** em `olie/prompts/production-review.md`, `workflow-policy.md` e `workflow.md`

## Cursor/browser não abrem no login (workvm + RemainAfterExit)

- **problema:** no boot o `workvm.service` logava `opening Cursor workspace` / `done`, mas o Cursor não aparecia (sem sessão em `~/.config/Cursor/logs`); só abria depois de `project-setup` na sessão gráfica
- **por que é um problema:** a VM sobe compose e MCP, mas o workspace Olie não abre; o “start de novo” no Hyprland era no-op
- **resolvido como:** (1) `DISPLAY` deixa de ser `:0` fixo — detecta socket X11 (`:1` no Hyprland) e define `DBUS_SESSION_BUS_ADDRESS` + `ELECTRON_OZONE_PLATFORM_HINT=wayland`; (2) espera Wayland exige `hyprctl monitors` quando há hyprctl; (3) `hyprland.start` faz `systemctl --user restart workvm.service` (não `start`); (4) open Cursor/browser idempotente no restart

## Projeto Locav em `locav/`

- **problema:** WorkVM sem definição para Locav (LocavApi + LocavFront em `preview`)
- **por que é um problema:** sem `project.conf` o `project-setup` não clona, não sobe compose nem abre o workspace
- **resolvido como:** pasta `locav/` com clones em `LocavApi` + `locav-front` (nome exigido pelo mount do compose); branch `preview`; pós-clone copia `example.env`

## Prompts Locav em `locav/prompts/`

- **problema:** Locav no board OlieFlowAi sem prompts de card/workday versionados
- **por que é um problema:** o ciclo (implement → validate → pre-qa → QA/CR) existia só em `olie/prompts/`; colar prompts da Olie quebrava paths e stack
- **resolvido como:** cópia adaptada em `locav/prompts/` (Bun/Sail/Cypress); `MCP=olie` no `project.conf`; labels do funil Locav ('Em andamento', 'Corrigir', 'Revisão em Produção', …); IDs numéricos resolvidos no funil vivo (não hard-coded)

## Locav: composer/migrate no start.hook (não no post-clone)

- **problema:** compose subia sem `vendor/`; PHP entrava em FATAL e `/api/hello` estourava o wait; bootstrap era manual
- **por que é um problema:** toda VM Locav nova pedia `composer install` à mão; Cursor abria com API morta
- **resolvido como:** `locav/start.hook.sh` (`workvm_project_after_compose`) faz composer+migrate+seed+passport no primeiro boot; `project-start.sh` roda o hook **antes** do WAIT_URL

## App launcher: fuzzel (hyprlauncher ainda quebra no Virtio)

- **problema:** Super+R chamava `hyprlauncher`; na WorkVM (Virtio GPU) o hyprtoolkit/aquamarine falha EGL, cai em `kms_swrast`, não aloca GBM e segfaulta
- **por que é um problema:** menu de apps inútil no guest; bind “certo” no papel, crash na prática
- **resolvido como:** `local menu = "fuzzel"` + `fuzzel` no `setup_apps`; `hyprlauncher` continua instalado para quando a GPU do guest permitir

## Projeto Olie em `olie/` (saiu de `projects/olie`)

- **problema:** definição Olie em `projects/olie/` e clones em `olie/` — dois lugares
- **por que é um problema:** hop de caminho; pasta `projects/` duplicava o conceito de produto
- **resolvido como:** `project.conf`, compose, overlay, e2e movidos para `olie/`; `workvm_list_project_ids` / `workvm_project_dir` aceitam pasta na raiz do meta-repo; workspace paths relativos a `olie/`

## Projeto Opbed em `opbed/` (saiu de `projects/opbed`)

- **problema:** definição em `projects/opbed/` e clones já em `opbed/`
- **por que é um problema:** mesmo hop de caminho do Olie
- **resolvido como:** `project.conf`, `post-clone.sh`, workspace movidos para `opbed/`; clones `opbed-backend` / `opbed-frontend` continuam fora do meta-repo

## Projeto Televisão em `televisao/` (saiu de `projects/televisao`)

- **problema:** definição e e2e em `projects/televisao/` e clones já em `televisao/`
- **por que é um problema:** mesmo hop de caminho do Olie/Opbed
- **resolvido como:** `project.conf`, `post-clone.sh`, workspace e suítes e2e movidos para `televisao/`; clones `televisao-api` / `front` / `meet-*` continuam fora do meta-repo

## Projeto da-o-play em `da-o-play/` (saiu de `projects/` + `musicians-app/`)

- **problema:** definição em `projects/da-o-play-api/` e clone em `musicians-app/da-o-play-api/`
- **por que é um problema:** hop de caminho; pasta `musicians-app/` só existia pelo layout antigo do MCP
- **resolvido como:** pasta do produto `da-o-play/`; clone em `da-o-play/da-o-play-api/` (fora do meta-repo); `musicians-app/` removido

## Projeto boilerplate-laravel em `boilerplate-laravel/` (saiu de `projects/`)

- **problema:** definição em `projects/boilerplate-laravel/` e clone já em `boilerplate-laravel/boilerplate-laravel/`
- **por que é um problema:** mesmo hop de caminho dos outros ids
- **resolvido como:** `project.conf`, `post-clone.sh`, workspace movidos para `boilerplate-laravel/`; clone continua fora do meta-repo

## Implementation move 'Não iniciado' → 'Em progresso'

- **problema:** `implementation.md` não movia o card; o move ficava manual ou só no `workflow.md`
- **por que é um problema:** paste de implementation sozinho deixava o card em 'Não iniciado'
- **resolvido como:** § Update the Card Stage em `implementation.md` (espelha correction); procedimento HTTP/MCP compartilhado em `workflow-policy.md` (hoje: `OLIE_MANAGEMENT_TOKEN` + UUID do MCP; sem hard-code de step_id/token)

## Implementation validation separado do validation de board

- **problema:** `validation.md` exigia PRs/forms/QA/CR logo após o implementation, quando ainda não existiam
- **por que é um problema:** validação prematura falhava ou misturava handoff com review de código
- **resolvido como:** `implementation-validation.md` (só código) → `pre-qa.md` (commits/PRs/forms) → depois board `validation.md`; workflow atualizado

## Project execution ao começar a trabalhar no card

- **problema:** o board não registrava execução (implementação, correção, review colega, revisão de produção)
- **por que é um problema:** ninguém vê que você está ativo naquele step; fluxo divergia do UI
- **resolvido como:** `POST …/projects/{id}/project-executions` documentado em `workflow-policy.md`; chamado após o move (ou no início do review) em implementation, correction, colleague-review e production-review

## Prompts: falha/demora de tooling = sinal para melhorar o prompt

- **problema:** agente engolia MCP/request/timeout e seguia; o atrito não voltava para o texto do prompt
- **por que é um problema:** o prompt continua errado; o workaround vira o caminho normal
- **resolvido como:** `olie/prompts/workflow-policy.md` + `project.md`; prompts vid2agent; `check-prompts.sh` exige o contrato

## Projeto vid2agent-code em `vid2agent-code/` (saiu de `projects/`; fim de `projects/`)

- **problema:** definição em `projects/vid2agent-code/` enquanto prompts e clone já estavam em `vid2agent-code/`
- **por que é um problema:** último hop de caminho; pasta `projects/` sem ids
- **resolvido como:** `project.conf`, `post-clone.sh`, workspace movidos para `vid2agent-code/`; `projects/` removido do meta-repo

## Prompts Olie / vid2agent na pasta do produto

- **problema:** prompts de produto ficavam sob `prompts/<…>/`, longe de `olie/` e `vid2agent-code/`; pasta global com `agent.md`/`clone-repos.md` nunca usados
- **por que é um problema:** hop de caminho; artefatos espalhados; pasta morta
- **resolvido como:** `olie/prompts/` e `vid2agent-code/prompts/` no meta-repo; `prompts/` removida; `check-prompts.sh` valida essas pastas

## Análise de mídia não vai no conteúdo do projeto Olie

- **problema:** skills de imagem/vídeo postavam a análise de volta no card (`save-media-tool`)
- **por que é um problema:** tech lead pediu que análise de imagem, vídeo e áudio **não** entre no conteúdo do projeto
- **resolvido como:** skills analisam localmente e gravam em `~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md` (reuso na correção, sem reanalisar); proibido `save-media-tool` para isso (`project.md`, content-language, correction/implementation)

## Cache local de análise de mídia por card

- **problema:** sem postar no card, voltar o card para 'Em progresso' faria o agente reanalisar imagem/vídeo
- **por que é um problema:** custo de tempo/VLM e resultado inconsistente entre passes
- **resolvido como:** um `.md` por media id em `olie/cards/{código}/{mediaId}.md`, **versionado no meta-repo** (`.gitignore` libera só esses `.md` + `olie/README.md`; clones continuam fora); skill lê o arquivo se existir

## Ollama/VLM na RX 580 (host)

- **problema:** VLM do vid2agent competia (ou ocupava) a RTX 5060; a RX 580 estava no `vfio-pci` (OSX) e blacklisted no host
- **por que é um problema:** 8 GB da 5060 ficavam amarrados ao VLM; passthrough/blacklist impediam usar a 580 no Linux
- **resolvido como:** liberar 580 do vfio (`host-rx580-for-ollama.sh`), `amdgpu` + `vulkan-radeon`; drop-in Ollama com `CUDA_VISIBLE_DEVICES=` e `VK_ICD_FILENAMES` só `radeon_icd.json`. Smoke: modelo na 580, NVIDIA ~idle. OSX passthrough da 580 fica em backup `.osx-passthrough.bak`

Formato:

```
problema: o que acontecia
por que é um problema: o custo
resolvido como: o que foi feito e por que dessa forma
```

## Workspace Olie vazio: `Unable to resolve workspace folder`

- **problema:** no login o Cursor abria roots `~/.config/olie/*` vazios; hover: `Unable to resolve workspace folder`
- **por que é um problema:** os clones existem em `~/git/olie/`, mas a janela não enxergava nenhum repo do produto
- **resolvido como:** `project-start` faz `pwd -P` em `current/` antes de sourcar o `project.conf`, e `workvm_open_cursor` passa `realpath` do `.code-workspace`. Os `../../olie/...` passam a resolver a partir de `~/git/projects/olie`, não de `~/.config/workvm/current`

## Validação de card sem prompt

- **problema:** o estágio 'validação' existia no `workflow.md`, mas não havia prompt com a régua (cinco critérios + revisores)
- **por que é um problema:** cada pedido de validação improvisava o que olhar; multitenancy e advogado-do-diabo não entravam por padrão
- **resolvido como:** `olie/prompts/validation.md` (+ referência no `workflow.md`; pasta movida de `prompts/enterscience/olie/`)

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
- **resolvido como:** e2e só declara `playwright`; `olie-flow-ai` vem de `mcps/olie.json` + `OLIE_FLOW_AI_MCP_TOKEN` em `environment.d`

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

## Local reCAPTCHA (browser + e2e)

- **problema:** em `APP_ENV=local` o secret real rejeita o token fake do Playwright (`Token inválido`), e a site key de development ainda abre desafio do Google no browser do agente — comentar PHP/`getToken()` era tentador e arriscava commit
- **por que é um problema:** e2e e login no Cursor param no captcha; bypass em código suja o diff e foge do prompt
- **resolvido como:** par de teste público do Google só em env — `RECAPTCHA_SECRET` no `.env` do `api-main` (backup em `~/.config/workvm/`) e, para UI, `VITE_APP_RECAPTCHA_SITE_KEY` em `packages/management/.env.development.local` (exclude local); documentado em `olie/prompts/implementation.md` §7; proibido comentar validação

## Host-card Televisão navegável (TV-16)

- **problema:** `ensure` do Televisão subia só o compose slim (`php -S` em `~/git/televisao`); `/` e `/up` davam 404 e não havia front
- **por que é um problema:** o caso 2 do experimento (card no jarvis sem WorkVM) parecia “não está rodando” ao abrir no browser
- **resolvido como:** `compose.host.yml` + `Dockerfile.host-api` (pgsql/redis/Laravel/Next namespaced); ensure escreve DNS `api|devframe.{slug}.olie.localhost`; slim fica só para Pest/sandbox

## Pest no host-card Olie (DNS slug + reCAPTCHA)

- **problema:** suite paralela no DOP-1183 falhava 3 testes: URLs com `*.dop-1183.olie.localhost` e `SubmitPublicForm` sem `invalid_token`; re-runs seguintes caíam em massa (`testing_test_*` sem tables)
- **por que é um problema:** o ensure injeta `MANAGEMENT_URL` com slug (browser multi-card) e o secret reCAPTCHA de teste do Google (login local); `--recreate-databases` esvazia o MySQL mas o checksum do FastRefreshDatabase faz pular `migrate:fresh`
- **resolvido como:** `bin/workvm-host-card-pest` força no `exec` o env da WorkVM (`MANAGEMENT_URL=http://{subdomain}.olie.localhost`, `DB_DATABASE=testing`, secret que rejeita token fake) e apaga `storage/app/migration-checksum_*.txt` antes do Pest

## Host-card sem olie-flow-ai (colleague review)

- **problema:** no jarvis o colleague review parava em “olie-flow-ai MCP is unavailable”; na WorkVM o board carregava
- **por que é um problema:** host-card não passa pelo `project-start` — sem merge em `~/.cursor/mcp.json` nem proxy `:47331` o agente não fala com o card
- **resolvido como:** `workvm_host_card_ensure_olie_mcp` no ensure (olie/locav/televisão com `MCP=olie`): mesmo caminho da VM (`workvm_apply_mcp` + `workvm_sync_olie_mcp_proxy`)

## Host-card sem Laravel Boost MCP

- **problema:** `~/.cursor/mcp.json` no jarvis só tinha `olie-flow-ai` + playwright; Boost não aparecia
- **por que é um problema:** a VM aplica `overlay/` (mcp.json do api-main → `olie-api-main`) no login; host-card não aplicava overlay e o container do card é `hc-olie-*-app-1`
- **resolvido como:** ensure aplica overlay + merge; `bin/workvm-host-card-boost-mcp.sh` aponta Boost ao container do card ativo (`host-card-boost-container`)

## finish card fecha a janela Cursor

- **problema:** `finish card` / `destroy` limpava compose e estado, mas a janela do card ficava aberta
- **por que é um problema:** N janelas mortas no Hyprland depois de revisar vários cards
- **resolvido como:** `workvm_close_cursor_workspace` fecha só a janela cujo título tem `olie-dop-… (Workspace)` (class Cursor)

## finish card + Hyprland 0.56 não fecha o Cursor

- **problema:** `hyprctl dispatch closewindow address:…` falha no Hyprland 0.56 (config Lua); a mensagem era `falha ao fechar Cursor` e a janela ficava
- **por que é um problema:** finalize card não limpa a janela; tentar `hl.dsp.window.close()` sem `window=` fecha a ativa (ou outras)
- **resolvido como:** `hyprctl dispatch 'hl.dsp.window.close({ window = "address:…" })'` só para addresses batidos pelo título do card; sem fallback sem `window=`

## finish card não pergunta Concluído

- **problema:** `finish card` / `finalize card` perguntava se movia o board para Concluído
- **por que é um problema:** o comando é só teardown local (sandbox + janela); o funil é outro pedido
- **resolvido como:** policy Olie/Locav/Televisão — destroy sem ask/move de board

## pest-parallel / ensure “resetava” o workspace

- **problema:** ao rodar `pest-parallel.md`, a janela Cursor parecia resetar
- **por que é um problema:** o prompt manda `ensure`, que reescrevia o `.code-workspace` e abria `--new-window` de novo
- **resolvido como:** só grava o workspace se o JSON mudou; `workvm_open_cursor` não reabre se a janela do card já existe (Hyprland); pest-parallel pode pular ensure se o stack já está up

## Workspace do card apontava clone, não o worktree

- **problema:** janela host-card listava `~/git/olie/api-main`, mas o compose usa o worktree em `~/.local/share/workvm/host-cards/...`; editar o worktree pedia permissão (fora do workspace)
- **por que é um problema:** implementação no card vira “Ask every Write”; ou o agente edita o clone e o container não vê
- **resolvido como:** após o ensure hook, `workvm_host_card_bind_workspace_worktree` troca a pasta `api-main` do `.code-workspace` pelo path absoluto do worktree

## ensure host-card falha no proxy MCP (start-limit)

- **problema:** `workvm-host-card ensure` saía 1 em `workvm_sync_olie_mcp_proxy` com `start-limit-hit` / Address already in use, mesmo com `:47331` já ouvindo
- **por que é um problema:** correction/colleague param no ensure; o proxy manual ou restart repetido deixa a unit failed
- **resolvido como:** se a porta já responde → OK; senão `reset-failed` + start; fallback `nohup` do script

## finish card devolve clones para develop

- **problema:** depois do destroy, `api-main` / `olie-fronts` (e outros CLONE_REPOS) ficavam na feature do review
- **por que é um problema:** o próximo card / workspace compartilhado herdava branch e diffs errados
- **resolvido como:** `workvm_host_card_restore_clone_bases` no destroy (stash se dirty → checkout da branch do `project.conf`; pula `olie/docs`)

## Host-card Playwright MCP em Connecting…

- **problema:** Playwright ficava em Connecting… no Cursor do jarvis
- **por que é um problema:** o merge apontava `workvm-playwright-mcp.sh` → container `olie-e2e`, que a WorkVM sobe no compose e o host-card não
- **resolvido como (1º):** wrapper Chromium + npx no host (paliativo)
- **resolvido como (atual):** ensure sobe `olie-e2e` por card (`compose.e2e-host.yml`, `network_mode: host`, `E2E_*` → `*.{slug}.olie.localhost`); `workvm-host-card-playwright-mcp.sh` faz `docker exec` nesse container (pointer `host-card-e2e-container`), igual à WorkVM

## Host-card Cursor abria o explorer no Televisão

- **problema:** ensure Olie abria janela com o workspace certo, mas o explorer mostrava `televisao/` (e outros produtos) sob o meta-repo
- **por que é um problema:** o root `git` → `~/git` lista todos os projetos; só reordenar pastas não esconde os irmãos
- **resolvido como:** clones primeiro + meta-repo por último; `files.exclude` + `git.repositoryScanIgnoredFolders` + `git.ignoredRepositories` nos clones dos outros produtos (SCM ainda listava `televisao-*` sob `~/git`); limpa `treeViewState` ao reabrir
