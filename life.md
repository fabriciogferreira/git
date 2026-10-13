# life.md — o que me faz ganhar tempo

Documento vivo de **tudo que importa na minha vida operacional** (máquina, host, VMs, fluxos, atritos) e decisões que empurram os objetivos abaixo.  
Não substitui `HISTORICO.md` (lá só entra problema **já resolvido**).

**Como usar:** anote atrito → “Melhorias”; ao resolver → `HISTORICO.md` + risque a melhoria; diário curto no fim.

## Objetivos

1. **Economizar tempo** — menos atrito no dia a dia (host, VMs, ferramentas, decisões repetidas).
2. **Aumentar a renda** — mais capacidade de gerar receita (trabalho, produtos, automação que escala).
3. **Acumular capital** — transformar renda em patrimônio (ativos, estoque de valor).
4. **Guardar dinheiro de forma segura** — preservar o que já existe (risco baixo, liquidez quando preciso, sem buracos óbvios).
5. **Fazer muito com pouco** — evitar gastar; só desembolsa quando for **muito** necessário. Preferir reorganizar o que já existe (ex.: RX 580 + 5060) a comprar hardware novo.

Tudo neste arquivo deve, no fim, servir a um desses objetivos. Se não servir, questionar se merece espaço.

## Tarefas

Lista viva do que falta fazer. Risque ou apague ao concluir; se gerou aprendizado duradouro, anote no diário / melhorias / `HISTORICO.md`.

Dependências: use `depends:` apontando para outra tarefa. Não comece a filha antes da mãe estar `[x]`.

- [ ] **Trocar o host de Omarchy para Arch Linux**
  - **Por quê:** Arch é mais leve que Omarchy; as WorkVMs já usam Arch — manter distros diferentes exige mais conhecimento e dobra atrito (pacotes, paths, hábitos).
  - **Objetivo:** economizar tempo (uma só “língua” host+guest) e sobrar CPU/RAM/disco para VMs e trabalho.
  - **Cuidado:** backup de `~/git`, `life.md`, hooks Ollama (`~/bin`, `~/.config/libvirt/hooks`, sudoers), `environment.d` (tokens), imagens libvirt; reaplicar Hyprland/meta-repo com cuidado.

- [ ] **Instalar a RX 580 na máquina** *(hoje está fora do PC)*
  - **Por quê:** segunda GPU no host; libera desenho “5060 = pesado / 580 = VLM”.
  - **Objetivo:** economizar tempo depois (menos disputa de VRAM) e capacidade (5060 livre para cargas maiores).
  - **Cuidado:** slot PCIe, PSU, drivers `amdgpu` no host; display continua na iGPU salvo decisão explícita.

- [ ] **Mover a LLM de análise de vídeo (Ollama/VLM) para a RX 580**
  - **depends:** Instalar a RX 580 na máquina
  - **Por quê:** a RTX 5060 (8 GB) fica livre para tarefas mais pesadas; VLM do vid2agent usa os 8 GB da 580.
  - **Objetivo:** economizar tempo / aumentar capacidade sem upgrade imediato da 5060 (**muito com pouco**).
  - **Cuidado:** Ollama/ROCm ou backend AMD estável; validar `VIDEO_LLM_*` e hook da VM; 580 é mais lenta que 5060 — aceitar trade-off de velocidade do VLM.

- [ ] **Descobrir qual outra tarefa atribuir à RTX 5060**
  - **depends:** Mover a LLM de análise de vídeo (Ollama/VLM) para a RX 580 *(pesquisa pode começar antes; decisão de uso permanente depois da 5060 estar livre)*
  - **Por quê:** 5060 com CUDA/VRAM sobrando sem papel claro = desperdício; precisa de uma carga que pague o silício (treino leve, LLM maior, encode, etc.).
  - **Objetivo:** muito com pouco + aumentar capacidade/renda sem comprar outra GPU.
  - **Entrega:** 1–3 candidatos ranqueados (valor × esforço × VRAM) e escolha padrão documentada aqui.

- [ ] **Ajustar prompt(s) de revisão Olie: não reclamar de PR inexistente nem de falta em `en.json`**
  - **Por quê:** revisão gasta tempo em falsos positivos — PR ainda não aberto (fase errada) e chaves EN preenchidas depois sob demanda (já há nota em `colleague-review.md` sobre `en.json`/`pt-br.json`; reforçar e alinhar os outros prompts).
  - **Objetivo:** economizar tempo nas revisões.
  - **Onde:** `prompts/enterscience/olie/` (`colleague-review.md`, e qualquer outro que ainda flagre PR / `en.json`).
  - **Entrega:** regra explícita “não falhar revisão só por PR não criado” + “não falhar só por chave ausente em `en.json` se existir em `pt-br.json`”; agente para de insistir nisso.

- [ ] **Começar a criar conteúdo no YouTube** *(renda a longo prazo)*
  - **Por quê:** renda de emprego/freelance é linear; canal pode virar ativo que gera sem trocar hora↔hora.
  - **Objetivo:** aumentar a renda + acumular capital (audiência/arquivo como ativo) — horizonte longo, não atalho.
  - **Muito com pouco:** usar o que já tem (PC, conhecimento, gravador de tela); não comprar setup caro no dia 1.
  - **Entrega inicial:** nicho + 1º vídeo publicado (mesmo que simples) + ritmo mínimo sustentável documentado aqui.

- [ ] **Venda de livros por link de parceiro (afiliado)** *(renda)*
  - **Por quê:** comissão sem estoque, sem frete, sem produto próprio — encaixa em conteúdo (YouTube/posts) com baixo custo.
  - **Objetivo:** aumentar a renda; **muito com pouco** (só cadastro + links, sem inventário).
  - **Sinergia:** pode depender / alimentar o canal YouTube (indicação no vídeo/descrição).
  - **Entrega inicial:** programa(s) escolhido(s) + 1 link parceiro no ar em algum conteúdo + regra simples de quais livros indicar.

- [ ] **Venda de cursos** *(renda — depois de estabelecido no YouTube)*
  - **depends:** Começar a criar conteúdo no YouTube *(só depois de canal estabelecido: audiência + ritmo + prova de demanda; não criar curso no dia 1)*
  - **Por quê:** curso próprio tem margem maior que afiliado; YouTube valida tema e traz tráfego sem ads caros.
  - **Objetivo:** aumentar a renda + acumular capital (produto digital reutilizável).
  - **Muito com pouco:** gravar com o setup que já serve o canal; não investir em plataforma cara antes de ter lista/interessados.
  - **Entrega (quando desbloquear):** 1 oferta mínima (tema validado pelo canal) + página/checkout simples + 1 venda ou waitlist real.

- [ ] **Otimizar uso de recursos das WorkVMs** *(ex.: retirar plano de fundo)*
  - **Por quê:** wallpaper, efeitos e extras do desktop comem RAM/CPU/GPU da guest; com 32 GB no host e várias VMs, cada MiB conta.
  - **Objetivo:** economizar tempo (VMs mais leves) + **muito com pouco** (mais VMs/estabilidade sem comprar RAM).
  - **Ideias iniciais:** fundo sólido / sem wallpaper; desligar blur/animações pesadas do Hyprland na guest; revisar autostart (apps que sobem sem precisar).
  - **Entrega:** mudanças no overlay/`.config` da VM (meta-repo) + checklist curto “VM leve” documentado aqui ou no HISTORICO.

- [ ] **Descobrir utilidade para os 2 SSDs sobrando**
  - **Por quê:** disco parado = capital ocioso; NVMe livre pode acelerar VMs, libvirt images, Docker, backups locais sem comprar outro drive.
  - **Objetivo:** **muito com pouco** + economizar tempo (I/O menos gargalo).
  - **Inventário conhecido:** Samsung 980 PRO 1 TB; Samsung 970 EVO Plus 250 GB *(confirmar quais 2 estão sobrando vs boot)*.
  - **Candidatos a avaliar:** pool de imagens `~/.local/share/images` / libvirt; scratch Docker; cache de builds; backup/rsync local; separar OS host vs dados.
  - **Entrega:** papel de cada SSD sobrando + layout de montagem/slots M.2 documentado na seção Hardware.

- [ ] **Empreendimento de ventoinhas** *(renda / produto)*
  - **Diferenciais:** filtragem excelente de produtos + poder **ouvir o som da ventoinha** como se já tivesse comprado (amostra de áudio confiável por modelo).
  - **Por quê:** compra de fan hoje é chute (dB de marketing ≠ ruído real); quem filtra bem + prova sonora reduz devolução e gera confiança.
  - **Objetivo:** aumentar a renda + acumular capital (catálogo/marca); **muito com pouco** no início (curadoria + áudio antes de estoque grande).
  - **depends (bloqueio a validar):** dúvida “equalizar som dos ouvintes” — se for inviável, o diferencial de áudio enfraquece.
  - **Entrega inicial:** 1 página/MVP com N modelos filtrados + áudio por modelo + critério de filtro escrito; só depois escala.

- [ ] **Conseguir outro emprego** *(renda)*
  - **depends:** dúvida **“Como trabalhar ao mesmo tempo nas duas empresas sem ficar confuso?”** respondida e regras de isolamento aplicadas
  - **Por quê:** segunda fonte de renda só é sustentável se o contexto não se misturar (senão o custo é erro, burnout ou conflito).
  - **Objetivo:** aumentar a renda; só depois do sistema de dois empregos estiver claro.
  - **Entrega:** oferta aceita + rotina da segunda empresa encaixada no isolamento já documentado em Dúvidas respondidas.

- [ ] **Aprender inglês** *(renda / visibilidade / possibilidade)*
  - **Por quê:** abre inúmeras portas — vagas remotas, docs/PRs, YouTube, cursos, networking, clientes fora do BR.
  - **Objetivo:** aumentar a renda + visibilidade; multiplica o retorno das outras tarefas (emprego, canal, cursos, afiliados).
  - **Muito com pouco:** input diário grátis/barato (input compreensível, speaking com o que já tem); não depender de curso caro no dia 1.
  - **Entrega inicial:** meta de nível + hábito mínimo semanal (ex.: X min/dia) documentado aqui; depois milestones (leitura técnica fluente → calls → conteúdo).

- [ ] **Estudar matemática** *(eficiência / raciocínio)*
  - **Por quê:** melhora muito o raciocínio — decisões, debug, arquitetura e aprendizado em geral ficam mais baratos em tempo.
  - **Objetivo:** economizar tempo (pensar melhor) + indiretamente renda (melhor entrega técnica).
  - **Muito com pouco:** livro/PDF/Khan/exercícios; rotina curta e constante > curso caro abandonado.
  - **Entrega inicial:** trilha escolhida (ex.: bases → discreta/álgebra conforme necessidade) + hábito mínimo semanal documentado aqui.

- [ ] **Estudar programação** *(eficiência / tempo)*
  - **Por quê:** chegar à solução mais rápido — menos retrabalho, menos “travado”, entrega melhor no mesmo relógio.
  - **Objetivo:** economizar tempo; também rende (emprego, produtos, YouTube/cursos).
  - **Muito com pouco:** prática no trabalho real + projetos pequenos; evitar curso eterno sem código.
  - **Entrega inicial:** foco da vez (ex.: aprofundar stack atual vs. buraco específico) + hábito mínimo semanal documentado aqui.

- [ ] **Levar tênis de academia + talco de tênis para a casa da mãe**
  - **Por quê:** hoje preciso ir na casa do pai para vestir o tênis — deslocamento extra toda vez.
  - **Objetivo:** economizar tempo (um kit no lugar certo).
  - **Entrega:** tênis e talco na casa da mãe, prontos para usar sem desvio.

## Dúvidas

Perguntas abertas. Quando tiver resposta confiável → mover para **Dúvidas respondidas** (não deixar a resposta só na cabeça).

- **Como trabalhar ao mesmo tempo nas duas empresas sem ficar confuso?** *(renda / operação)*
  - Contexto: dois empregadores/clientes; risco de misturar contexto, branch, credencial, VM, horário e compromisso mental.
  - Resposta desejada: regra simples de isolamento (1 VM ou workspace por empresa, calendário, “modo” de troca) que economize tempo e evite erro caro.

- **É possível equalizar o som para os ouvintes no empreendimento de ventoinhas?** *(renda / produto)*
  - Problema: cada pessoa ouve em fone/caixa/volume/ambiente diferente — o “som da ventoinha como se tivesse comprado” pode enganar se não houver equalização ou referência comum.
  - Resposta desejada: sim/não/parcial + método (calibração, perfil de fone, amostra A/B com referência conhecida, LUFS, aviso de limite) e se o MVP ainda vale sem equalização perfeita.

## Dúvidas respondidas

### Até quantos MHz minhas memórias RAM podem trabalhar? *(sem overclock — preservar vida útil)*

**Premissa:** sem OC, sem XMP “empurrando” voltagem/frequência além do JEDEC do módulo. Objetivo: não reduzir vida útil à toa.

**Resposta curta:** sem overclock, o teto seguro é a velocidade **JEDEC** do pente/board — no seu caso, até **DDR5-5600** (5600 MT/s) na config que a MSI lista como JEDEC 1R. **Não** subir para 5800/6000/6400.

| Cenário | O que fazer |
| --- | --- |
| Sem OC (recomendado para vida útil) | Deixar memória em **JEDEC / Auto** na BIOS; **XMP desligado** se o XMP for o que sobe clock/voltagem além do JEDEC |
| Teto JEDEC na PRO Z690-A | até **5600 MT/s** (1R, spec MSI); com mais DIMMs/ranks pode estabilizar mais baixo (ex. 4800) — isso é normal, não force |
| Kit marcado 5600 | Rodar a **5600 JEDEC** (ou o que o SPD entregar sem XMP) está ok; é a faixa “oficial”, não OC |
| Acima de 5600 | É OC → fora do objetivo de preservar vida útil |

**Prático:** na BIOS, confirme frequência ~**5600** (ou a JEDEC que o SPD escolher) e que **XMP/EXPO está off** se quiser zero OC. Não use os presets 6400+ da placa.

---

## Hardware (host jarvis)

Configuração física usada para decidir: VMs, Ollama/VRAM, display na iGPU vs dGPU, upgrades.

### CPU
| | |
| --- | --- |
| Modelo | **Intel Core i7-13700K** |
| Importante | **16 núcleos / 24 threads** (8P+8E) — headroom para Hyprland + várias WorkVMs + Docker |

### Cooler
| | |
| --- | --- |
| Modelo | **Arctic Liquid Freezer III Pro 360** (AIO 360 mm) |
| Importante | Refrigeração do 13700K sob carga (VMs + compile); headroom térmico sem OC agressivo |

### Armazenamento (NVMe)
| Modelo | Capacidade | Notas |
| --- | --- | --- |
| **Samsung 980 PRO** | **1 TB** | PCIe 4.0 — bom para sistema / imagens de VM quentes |
| **Samsung 970 EVO Plus** | **250 GB** | PCIe 3.0/4.0 conforme slot — bom para scratch, cache ou papel secundário |

Board tem **4× M.2** (ver placa-mãe). Mapear qual SSD está em qual slot e qual é boot vs sobra.

### Memória
| | |
| --- | --- |
| Instalada | **32 GB DDR5-5600** |
| Importante | **32 GB RAM** — limite prático de VMs simultâneas + Chrome/Cursor; upgrade sobe esse teto |
| Placa (máx.) | até **192 GB** (4 slots) |
| Máx. sem overclock (JEDEC, MSI) | até **DDR5-5600** em config 1R (POR/JEDEC); com mais DIMMs/ranks a placa pode baixar (ex. 4800). Perfis **XMP** = OC de memória. Kit atual 5600 casa com o teto JEDEC 1R da board. |

### GPU — NVIDIA (compute / VLM)
| | |
| --- | --- |
| Modelo | **GeForce RTX 5060 Shadow 2X OC** |
| Importante | **8 GB VRAM** — teto para Ollama/VLM; display do host fica na **iGPU** para não disputar VRAM |

### GPU — AMD (secundária)
| | |
| --- | --- |
| Modelo | **Radeon RX 580** |
| Importante | **8 GB** — GPU extra no sistema (não é a do Ollama; Ollama usa a 5060) |

### Placa-mãe
| | |
| --- | --- |
| Modelo | **MSI PRO Z690-A** |
| Chipset | Intel Z690, socket 1700 |

**Expansion Slot**
- 3× PCIe x16:
  - `PCI_E1` (CPU): até **PCIe 5.0 x16**
  - `PCI_E3` e `PCI_E4` (Z690): até **PCIe 3.0 x4** e **3.0 x1**
- 1× PCIe 3.0 x1 (Z690)

**M.2 (Key M) — 4 slots**
| Slot | Origem | Link | Notas |
| --- | --- | --- | --- |
| M2_1 | CPU | PCIe 4.0 x4 | 2242 / 2260 / 2280 / 22110 |
| M2_2 | Z690 | PCIe 4.0 x4 | 2242 / 2260 / 2280 |
| M2_3 | Z690 | PCIe 3.0 x4 **ou** SATA 6 Gb/s | 2242 / 2260 / 2280 |
| M2_4 | Z690 | PCIe 4.0 x4 **ou** SATA 6 Gb/s | 2242 / 2260 / 2280 |

### Implicações rápidas (tempo / setup)
- **8 GB VRAM (5060):** VLM grande aperta; preferir quantização / `qwen2.5vl:3b` se 7b estourar; não deixar desktop na 5060.
- **32 GB RAM:** 1–2 WorkVMs pesadas + host ok; muitas VMs ligadas = swap/dor.
- **24 threads:** bom para compose/build paralelo nas guests.
- **RX 580:** candidata a display secundário ou passthrough futuro — não misturar com o papel da 5060 (Ollama) sem desenho explícito.

---

## 1. Máquinas e papéis

| Onde | Papel |
| --- | --- |
| **Host** (`jarvis`) | Desktop Hyprland, libvirt `qemu:///session`, Ollama (VLM), Cursor às vezes, browser |
| **WorkVM** (uma por card/projeto) | Clone(s) + Docker + Cursor multi-root (`~/git` + repos) + browser |
| **Meta-repo** `~/git` | Provisiona VM, projeto ativo, overlays, prompts, skills locais |

Projetos definidos em `projects/<id>/` hoje: `olie`, `vid2agent-code`, `televisao`, `opbed`, `boilerplate-laravel`, `da-o-play-api`, …

VMs libvirt (nomes típicos): `olie-dop-*`, `olie-os-*`, `vid2agent-code`, `opbed`, `telvesiao`, `da-o-play`, …

---

## 2. Manhã / ligar o dia

### Host
1. Login gráfico Omarchy (Hyprland).
2. Monitor na **iGPU** (placa-mãe); RTX 5060 livre para Ollama (compute).
3. VMs sobem sob demanda (`virsh` / virt-manager), não “um app só”.
4. Ollama **não** sobe no boot do host (`systemctl disable ollama`). Deve subir com a VM `vid2agent-code` via hook.

### WorkVM (quando abre um card)
1. Ligar a VM do card (ex.: `olie-dop-1412`, `vid2agent-code`).
2. Autologin SDDM → Hyprland → `workvm.service` → `project-start.sh`:
   - fetch meta-repo / clones
   - Docker compose do projeto
   - merge MCP → `~/.cursor/mcp.json`
   - patch local de `.cursor` nos clones
   - abre Cursor (workspace) + Chromium nas URLs do `project.conf`
3. Agente vê projeto ativo em `.cursor/rules/workvm-project.mdc`.

### Checklist rápido “estou pronto?”
```bash
# host
virsh -c qemu:///session list
systemctl is-active ollama          # só precisa se for vid2agent / VLM
ss -ltnp | rg '11434|18080'         # Ollama + API vid2agent

# guest (na VM)
curl -sS -m 3 -o /dev/null -w '%{http_code}\n' http://localhost
docker compose ps                   # no COMPOSE_DIR do projeto
```

---

## 3. O que uso o dia inteiro

### Ferramentas
| Ferramenta | Para quê |
| --- | --- |
| **Cursor** (Agent / Ask) | Código, prompts, skills, MCP |
| **Kitty / terminal** | git, virsh, docker, curl, setup |
| **Hyprland** | Janelas host e guest |
| **Docker Compose** | App Laravel / stacks do projeto |
| **libvirt + QEMU session** | Isolar ambiente por card/VM |
| **Chromium** | App local, às vezes board |
| **gh / git** | PRs e meta-repo |
| **Ollama** (host) | VLM para vid2agent (`qwen2.5vl`) |
| **MCP OlieFlowAi** | Conteúdo de DOP/OS (mídia, save-media) |
| **spice / wayland-vdagent** | Clipboard host ↔ guest |

### Artefatos que o agente / eu consultamos
| Path | Uso |
| --- | --- |
| `~/git/.cursor/rules/*` | Como a VM e o meta-repo funcionam |
| `~/git/prompts/**` | Prompts para colar no agente |
| `projects/<id>/overlay/**/cursor` | Rules/skills locais (não vão pro remoto da empresa) |
| `projects/<id>/project.conf` | Clones, compose, URLs |
| `HISTORICO.md` | Decisões já tomadas |
| Host: `~/.local/share/doc/ollama-workvm.md` | Ollama sob demanda (hoje **fora do git**) |
| Host: `~/.local/share/doc/vid2agent-api.md` | API `:18080` (hoje **fora do git**) |
| Host: `~/bin/setup-ollama-workvm.sh` | Sudoers + bind Ollama |
| Host: `~/.config/libvirt/hooks/qemu` | VM up → Ollama + hostfwd |

### Fluxos de produto recorrentes
1. **Card Olie (DOP/OS)**  
   Abrir VM do card → Cursor no workspace olie → MCP media → skill `olie-project-image-analysis` (screenshots) e/ou `olie-project-video-conversion` (vídeo → markdown via vid2agent).
2. **vid2agent-code**  
   VM sobe → Ollama no host → app Docker → `POST /api/conversions` → markdown. Outras VMs chamam `http://10.0.2.2:18080/api/conversions`.
3. **Meta-repo**  
   Melhorar bootstrap, overlays, prompts; commit/push para as VMs darem `git pull`.

---

## 4. Rede e URLs que importam

| De | Para | URL |
| --- | --- | --- |
| Guest → host Ollama | VLM | `http://10.0.2.2:11434` (`…/v1` no `.env`) |
| Guest → API vid2agent | conversão | `http://10.0.2.2:18080/api/conversions` |
| Host → API vid2agent | smoke | `http://127.0.0.1:18080/api/conversions` |
| Guest → app local | nginx | `http://localhost` (porta do compose) |

Rede típica da guest: SLIRP (`interface type=user`). Host visto como `10.0.2.2`.  
API vid2agent: QEMU `hostfwd` `127.0.0.1:18080` → guest `:80` (reaplicado no hook).

Env esperado na guest vid2agent (resumo):
```env
VIDEO_LLM_ENABLED=true
VIDEO_LLM_BASE_URL=http://10.0.2.2:11434/v1
VIDEO_LLM_MODEL=qwen2.5vl:3b
VIDEO_LLM_API_KEY=ollama
VIDEO_LLM_TIMEOUT=300
```
(Modelo 7b pode existir no host; 3b foi o fallback estável no pull.)

---

## 5. Fim do dia / desligar

1. Parar VMs que não precisa (`virsh shutdown …`).
2. Com `vid2agent-code` down, o hook deve **parar Ollama** e liberar VRAM.
3. Não é necessário deixar Ollama no boot do host.
4. Meta-repo: se mudou overlay/prompt/script → commit + push para as outras VMs puxarem amanhã.

---

## 6. Melhorias (backlog vivo)

Marque `[x]` quando feito; detalhe o “como” em `HISTORICO.md`.

### Infra host / VM
- [ ] **Versionar no git** setup do host Ollama + API: script, doc do hook, sudoers (template), hostfwd — hoje só em `~/bin` e `~/.local/share/doc`.
- [ ] **Garantir `/etc/sudoers.d/ollama-workvm`** após setup/reinstall; sem NOPASSWD o hook falha sem TTY e a VM sobe sem Ollama (já doeu).
- [ ] **Smoke no login/host**: se `vid2agent-code` está running e Ollama inactive → alertar (notify / log).
- [ ] Revisar se hook cobre todos os caminhos reais (`started` / `restore` / `reconnect`) e se o log `~/.local/state/workvm-hooks/qemu.log` é olhado quando falha.
- [ ] Documentar no README do meta-repo o link para este arquivo e para docs de host quando forem versionados.

### Produtividade agente
- [ ] Um único “prompt de início de card” que: puxa meta-repo, confere overlay/skills, confere API/Ollama se for vídeo.
- [ ] Skill de vídeo na VM Olie: garantir sync do overlay após `git pull` (hoje fácil ficar desatualizado até reaplicar overlay).
- [ ] Padronizar nomes de container (`vid2agent-code-php-fpm` vs `boilerplate-laravel-php-fpm`) nos prompts.

### Produto / fluxo Olie ↔ vid2agent
- [ ] Critério de pronto da conversão de vídeo (tempo, qualidade do markdown, retry).
- [ ] Idempotência e markers já existem nas skills — validar no dia a dia se agentes pulam certo.
- [ ] Se `qwen2.5vl:7b` estabilizar no pull, documentar modelo preferido vs 3b.

### Meta-repo
- [ ] Entrada em `layout.mdc` para `docs/` (este arquivo).
- [ ] Evitar docs úteis só no host live (regra: se outra VM precisa, está no git).

---

## 7. Diário curto (preencher)

### 2026-10-12
- Host: monitor → iGPU; Ollama sob demanda; modelo `qwen2.5vl:3b` (+ 7b depois no host).
- API vid2agent exposta em `:18080`; skill `olie-project-video-conversion` commitada.
- Dor: Ollama não subiu com a VM → faltava sudoers NOPASSWD para o hook.

### 2026-10-13
- (preencher) …

---

## 8. Referências rápidas

| Tema | Onde |
| --- | --- |
| Mapa do meta-repo | `.cursor/rules/layout.mdc` |
| Como a VM opera | `.cursor/rules/meta-repo.mdc` |
| Problemas resolvidos | `HISTORICO.md` |
| Prompt guest Ollama | `prompts/vid2agent-code/host-ollama-ready.md` |
| Prompt API para Olie | `prompts/vid2agent-code/guest-api-ready-for-olie.md` |
| Skill imagens | `projects/olie/overlay/**/olie-project-image-analysis` |
| Skill vídeo | `projects/olie/overlay/**/olie-project-video-conversion` |
