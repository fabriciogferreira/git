# life.md — o que me faz ganhar tempo

Documento vivo de **tudo que importa na minha vida operacional** (máquina, host, VMs, fluxos, atritos) e decisões que empurram os objetivos abaixo.  
Não substitui `HISTORICO.md` (lá: narrativa do problema resolvido, se precisar).

**Como usar**
- **Estado atual** (hardware, papéis, URLs): o que está assim **agora** e **por quê** — isso fica no documento.
- **Tarefas:** só o que ainda falta. Ao concluir → **apagar** a tarefa e **atualizar o estado** (não deixar checkbox `[x]`).
- Atrito aberto → Melhorias / Dúvidas; diário curto se ajudar.

## Objetivos

1. **Economizar tempo** — menos atrito no dia a dia (host, VMs, ferramentas, decisões repetidas).
2. **Aumentar a renda** — mais capacidade de gerar receita (trabalho, produtos, automação que escala).
3. **Acumular capital** — transformar renda em patrimônio (ativos, estoque de valor).
4. **Guardar dinheiro de forma segura** — preservar o que já existe (risco baixo, liquidez quando preciso, sem buracos óbvios).
5. **Fazer muito com pouco** — evitar gastar; só desembolsa quando for **muito** necessário. Preferir reorganizar o que já existe (ex.: RX 580 + 5060) a comprar hardware novo.

Tudo neste arquivo deve, no fim, servir a um desses objetivos. Se não servir, questionar se merece espaço.

## Tarefas

Só o que **ainda falta**. Ao concluir: apague daqui e atualize o **estado** (Hardware / papéis).  
Dependências: `depends:` — não comece a filha antes da mãe estar feita.

- [ ] **Trocar o host de Omarchy para Arch Linux**
  - **Por quê:** Arch é mais leve que Omarchy; as WorkVMs já usam Arch — manter distros diferentes exige mais conhecimento e dobra atrito (pacotes, paths, hábitos).
  - **Objetivo:** economizar tempo (uma só “língua” host+guest) e sobrar CPU/RAM/disco para VMs e trabalho.
  - **Cuidado:** backup de `~/git`, `life.md`, hooks Ollama (`~/bin`, `~/.config/libvirt/hooks`, sudoers), `environment.d` (tokens), imagens libvirt; reaplicar Hyprland/meta-repo com cuidado.

- [ ] **Descobrir qual outra tarefa atribuir à RTX 5060**
  - **Por quê:** VLM já saiu da 5060 (está na RX 580); a 5060 está livre sem papel fixo — precisa de carga que pague o silício.
  - **Objetivo:** muito com pouco + aumentar capacidade/renda sem comprar outra GPU.
  - **Entrega:** 1–3 candidatos + atualizar o estado da 5060 neste arquivo.

- [ ] **Ajustar prompt(s) de revisão Olie: não reclamar de PR inexistente**
  - **Por quê:** revisão gasta tempo em falso positivo — PR ainda não aberto (fase errada).
  - **Objetivo:** economizar tempo nas revisões.
  - **Onde:** `olie/prompts/` (ex.: `colleague-review.md`, `validation.md`).
  - **Já feito:** não mexer / não falhar por `en.json` (resolvido depois; só `pt-br.json`) — ver `project.md` e prompts aplicáveis.
  - **Entrega:** regra explícita “não falhar revisão só por PR não criado”; agente para de insistir nisso.

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

- [ ] **Otimizar eficiência das WorkVMs** *(roadmap ponto a ponto — ver §1)*
  - **Por quê:** 32 GB no host; VM mal dimensionada ou I/O/CPU emulado desperdiça tempo e impede 2ª VM útil.
  - **Objetivo:** economizar tempo + **muito com pouco**.
  - **Como:** um item do roadmap por vez; ao concluir → marcar lá, atualizar estado, não acumular `[x]` eterno nesta lista.
  - **Entrega:** roadmap §1 zerado (ou só itens “depois / se doer” restantes).

- [x] **Remover `projects/` do meta-repo (migrar cada id para a pasta do produto)**
  - **Por quê:** árvore dupla — `projects/<id>/` e clones em `olie/` / etc.
  - **Ganho:** um lugar por projeto; menos hop de caminho.
  - **Feito:** olie, opbed, televisao, da-o-play, boilerplate-laravel, vid2agent-code na raiz; `projects/` removido; discovery em `lib/git.sh` na raiz do meta-repo.
  - **Após migrar nesta VM:** `./project-setup.sh <id>` de novo (atualiza `~/.config/workvm/current`).

- [ ] **Descobrir utilidade para os 2 SSDs sobrando**
  - **Por quê:** disco parado = capital ocioso; NVMe livre pode acelerar VMs, libvirt images, Docker, backups locais sem comprar outro drive.
  - **Objetivo:** **muito com pouco** + economizar tempo (I/O menos gargalo).
  - **Já definido:** MoveSpeed no **M2_1** = OS do dia a dia (máx. velocidade + mín. latência).
  - **Sobrando a mapear:** Samsung 980 PRO 1 TB; Samsung 970 EVO Plus 250 GB *(slots + papel)*.
  - **Candidatos:** imagens libvirt / `~/.local/share/images`; scratch Docker; cache de builds; backup local.
  - **Entrega:** atualizar a tabela de armazenamento (slot + papel + por quê) para os dois Samsung.

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

### SSDs no M2_1 (CPU) são mais rápidos que nos outros slots?

**Resposta curta:** no **pico sequencial**, M2_1 (CPU, PCIe 4.0 x4) e M2_2 / M2_4 (chipset, também PCIe 4.0 x4) têm a **mesma** largura teórica (~PCIe 4.0 x4). O SSD (ex. MoveSpeed 7450/6500) é o que limita o topo, não o fato de ser “no CPU” por si só.

**Onde M2_1 ganha de verdade:**
- **Latência** um pouco melhor (sem hop chipset → DMI → CPU).
- **Menos disputa:** M.2 no chipset compartilha o DMI e o chipset com USB, SATA, rede e outros M.2 — sob carga pesada (VMs + Docker + downloads) o slot do CPU **sustenta** melhor.
- **M2_3** na PRO Z690-A é **PCIe 3.0 x4** (ou SATA) → esse sim é claramente mais lento que M2_1/2/4 em NVMe.

**Prático:** boot + imagens de VM quentes / scratch intenso → preferir **M2_1** (e o SSD mais rápido). Arquivo frio / backup → M2_2/4 ok; evitar M2_3 para NVMe “rápido”.

---

## Hardware (host jarvis)

Inventário + **estado atual** (o que faz o quê e por quê).

### Estado atual — GPUs

| Peça | Onde | Papel agora | Por quê |
| --- | --- | --- | --- |
| **iGPU Intel** | CPU | **Display** do host (Hyprland) | Não gasta VRAM das dGPUs no desktop |
| **RX 580** (8 GB) | slot PCIe **2** (`06:00.0`, `amdgpu`) | **Ollama / VLM** para a WorkVM **vid2agent-code** (API + `10.0.2.2:11434`) | É a GPU **mais fraca**; serve LLM de vídeo e deixa a 5060 livre. Vulkan só RADV (`VK_ICD_FILENAMES=…/radeon_icd.json`, `CUDA_VISIBLE_DEVICES=`). Passthrough OSX dessa placa **off** (backup `*.osx-passthrough.bak`) |
| **RTX 5060** (8 GB) | slot PCIe principal (`01:00.0`) | **Livre** para serviços/cargas mais pesadas (ainda sem papel fixo — ver tarefa) | Mais capaz que a 580; não deve correr o VLM “de rotina” |

Scripts de referência no host: `~/bin/host-rx580-for-ollama.sh`, `~/bin/ollama-amd-rx580.conf`.

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

### Armazenamento (NVMe) — estado atual

| Modelo | Slot | Papel agora | Por quê |
| --- | --- | --- | --- |
| **MoveSpeed** (NVMe M.2, ~7450 / 6500 MB/s) | **M2_1** (CPU) | **Sistema operacional do dia a dia** (boot/host) | Precisa de **velocidade máxima** e **menor latência**; M2_1 é direto no CPU |
| **Samsung 980 PRO** 1 TB | *(mapear)* | *(definir — ver tarefa SSDs)* | PCIe 4.0 |
| **Samsung 970 EVO Plus** 250 GB | *(mapear)* | *(definir — ver tarefa SSDs)* | Secundário / scratch |

Board: **4× M.2** (tabela abaixo). MoveSpeed no M2_1 é decisão consciente, não “qualquer SSD no slot rápido”.

### Memória — estado atual

| | |
| --- | --- |
| Instalada | **32 GB** (4×8 GiB) Kingston **KF556C40-8**, DDR5, 1R, 4 slots |
| Velocidade agora | **5600 MT/s** (antes ~4000 MT/s com 4 DIMMs em Auto) |
| Tensão agora | **1,25 V** (perfil do kit 5600 CL40) |
| Por quê 5600 | Memória mais rápida → host/VMs/compile/Cursor respondem melhor → **trabalho feito mais rápido** (objetivo economizar tempo) |
| Capacidade | **32 GB** — limite prático de VMs simultâneas + Chrome/Cursor; upgrade sobe esse teto |
| Placa (máx.) | até **192 GB** (4 slots) |
| Teto MSI sem OC de marketing | até **DDR5-5600** JEDEC 1R; acima (5800+) = OC. Não subir além de 5600. |

### Placa-mãe
| | |
| --- | --- |
| Modelo | **MSI PRO Z690-A** |
| Chipset | Intel Z690, socket 1700 |

**Expansion Slot**
- 3× PCIe x16:
  - `PCI_E1` (CPU): até **PCIe 5.0 x16** — hoje **RTX 5060**
  - `PCI_E3` e `PCI_E4` (Z690): até **PCIe 3.0 x4** e **3.0 x1** — hoje **RX 580** no slot 2
- 1× PCIe 3.0 x1 (Z690)

**M.2 (Key M) — 4 slots**
| Slot | Origem | Link | Notas |
| --- | --- | --- | --- |
| M2_1 | CPU | PCIe 4.0 x4 | Preferir boot / I/O quente |
| M2_2 | Z690 | PCIe 4.0 x4 | 2242 / 2260 / 2280 |
| M2_3 | Z690 | PCIe 3.0 x4 **ou** SATA 6 Gb/s | Mais lento em NVMe |
| M2_4 | Z690 | PCIe 4.0 x4 **ou** SATA 6 Gb/s | 2242 / 2260 / 2280 |

### Implicações rápidas
- **32 GB RAM:** 1–2 WorkVMs pesadas + host ok; muitas VMs = swap/dor. Por isso cada VM leva só a RAM que o projeto precisa (ver §1).
- **24 threads:** bom para compose/build paralelo nas guests; vCPU também **por projeto**, não “máximo igual em todas”.
- **VLM na 580:** mais lento que na 5060 — trade-off consciente (**muito com pouco**).

---

## 1. Máquinas e papéis

| Onde | Papel |
| --- | --- |
| **Host** (`jarvis`) | Desktop Hyprland, libvirt `qemu:///session`, Ollama (VLM), Cursor às vezes, browser |
| **WorkVM** (uma por card/projeto) | Clone(s) + Docker + Cursor multi-root (`~/git` + repos) + browser |
| **Meta-repo** `~/git` | Provisiona VM, projeto ativo, overlays, prompts, skills locais |

Projetos na raiz do meta-repo: `olie/`, `opbed/`, `televisao/`, `da-o-play/`, `boilerplate-laravel/`, `vid2agent-code/`, `use-url-query/`.

VMs libvirt (nomes típicos): `olie-dop-*`, `olie-os-*`, `vid2agent-code`, `opbed`, `telvesiao`, `da-o-play`, …

### WorkVMs: recursos por projeto (não clone genérico)

VMs **diferentes** devem ter **configurações diferentes** (vCPU e RAM no libvirt). Motivo: cada uma é um **projeto diferente**, com carga diferente (compose, browsers, Cursor, builds).

**Fonte da config da VM:** cada projeto tem um **`.xml` na própria pasta do projeto** — domain libvirt individual daquela WorkVM (vCPU, RAM, disco, rede, etc.). Não reutilizar um XML genérico para todos.

| Regra | Por quê |
| --- | --- |
| Um **`.xml` por projeto** (na pasta do projeto) | Config individual versionável/reaplicável; bate com “projeto ≠ recursos iguais” |
| Dimensionar **vCPU e RAM** nesse XML | Projeto leve não precisa do mesmo teto que Olie/Docker pesado; projeto pesado não pode ficar faminto |
| Evitar “todas as VMs iguais” (ex. 8 vCPU / 16 GB) | Com **32 GB** no host, clones idênticos gastam RAM ociosa e impedem 2ª VM útil |
| Definir / atualizar via esse XML (`virsh define` / virt-manager) | O meta-repo / pasta do projeto guarda o desejado; o libvirt no host aplica |

Objetivo: **economizar tempo** (VM certa responde sem swap) + **muito com pouco** (cabem mais VMs úteis no mesmo host).

**Valores documentados** (medido sob carga real):

| Projeto | XML | RAM | vCPU | Nota |
| --- | --- | --- | --- | --- |
| `olie` | `olie/config-vm.xml` | **12 GiB** | **9** | Domain **`olie`**; teto de vCPU (não reserva); 12 GiB para folga com Postman/DBeaver |
| `locav` | `locav/config-vm.xml` | **12 GiB** | **9** | Mesmo teto da Olie; ainda não aplicado no host |

Aplicar no host (VM **parada**): `~/git/bin/apply-config-vm.sh [projeto]`. Só mexe em RAM/vCPU se a domain já existe e está `shut off`. Conferir com a **mesma** URI que o script usou (Olie costuma ser `qemu:///system`): `virsh -c qemu:///system dumpxml olie | grep memory`.

*Nota:* o `.xml` fica na pasta do projeto no meta-repo (mesmo princípio: um arquivo por projeto, ao lado do resto da definição).

### WorkVMs: eficiência — roadmap (ponto a ponto)

Fazer **um item por vez**, na ordem. Ao concluir: marcar `[x]`, anotar o que mudou (e onde), seguir o próximo. Não priorizar pinning/hugepages no início.

**Já feito**
- [x] Sem wallpaper na guest — removidos `swaybg`, `wallpaper.jpg`, autostart; logo/fundo padrão Hyprland off (overlay `.config/hypr`).

**Agora (maior ganho / baixo risco)**
- [ ] **RAM e vCPU por projeto** — um `.xml` na pasta de cada projeto (config individual da VM); inventariar, ajustar (leve vs pesado), `virsh define`; documentar valores quando estabilizar.
- [ ] **Uma VM pesada por vez** quando o host estiver apertado — hábito, não XML; parar a que não está em uso.
- [ ] **Guest mais leve** — desligar blur/animações pesadas do Hyprland; revisar autostart (apps que sobem sem precisar); refletir no overlay `.config/`.
- [ ] **virtio em disco e rede** — conferir/ajustar no libvirt (evitar IDE/SATA/e1000 emulado).
- [ ] **CPU host-passthrough** (ou host-model) — guest usa instruções do 13700K; builds mais rápidos.

**Em seguida (I/O e RAM)**
- [ ] **Imagens libvirt no NVMe dedicado** — 980 PRO 1 TB em M2_2 ou M2_4; mover `~/.local/share/libvirt/images` (ou path atual); depende da tarefa dos SSDs.
- [ ] **Opções de disco** — testar `cache`/`io` (ex. writeback + threads/native); anotar o que ficou estável.
- [ ] **Memballoon** — ligar para o host recuperar RAM ociosa da guest.
- [ ] **Scratch no 970 EVO 250 GB** — Docker cache / builds / downloads (se a tarefa dos SSDs confirmar esse papel).

**Depois / só se doer**
- [ ] **Virtio-GPU / gráfico** — se a guest estiver pesada no desktop.
- [ ] **CPU pinning** (P-cores vs E-cores) — só com duas cargas pesadas brigando; senão o scheduler basta.
- [ ] Hugepages / isolcpus — fora do caminho feliz; alto custo de manutenção.

**Fora de escopo deste roadmap:** OC de CPU/RAM “para a VM ficar mais rápida”.

---

## 2. Manhã / ligar o dia

### Host
1. Login gráfico Omarchy (Hyprland).
2. Monitor na **iGPU**; **RX 580** = Ollama/VLM (vid2agent); **RTX 5060** = cargas pesadas (papel ainda em aberto).
3. VMs sobem sob demanda (`virsh` / virt-manager), não “um app só”.
4. Ollama **não** sobe no boot do host; sobe/para com a VM `vid2agent-code` (hook).

### WorkVM (quando abre um card)
1. Ligar a VM do card (ex.: `olie-dop-1412`, `vid2agent-code`).
2. Autologin SDDM → Hyprland → `workvm.service` → `project-start.sh`:
   - fetch meta-repo / clones
   - Docker compose do projeto
   - merge MCP → `~/.cursor/mcp.json`
   - patch local de `.cursor` nos clones
   - no login, não abre Cursor nem browser; a instalação do projeto abre os dois
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
| `~/git/olie/prompts/` | Prompts do projeto Olie |
| `~/git/vid2agent-code/prompts/` | Prompts do vid2agent-code |
| `<projeto>/overlay/**/cursor` | Rules/skills locais (não vão pro remoto da empresa) |
| `<projeto>/project.conf` | Clones, compose, URLs |
| `HISTORICO.md` | Decisões já tomadas |
| Host: `~/.local/share/doc/ollama-workvm.md` | Ollama sob demanda (hoje **fora do git**) |
| Host: `~/.local/share/doc/vid2agent-api.md` | API `:18080` (hoje **fora do git**) |
| Host: `~/bin/setup-ollama-workvm.sh` | Sudoers + bind Ollama |
| Host: `~/.config/libvirt/hooks/qemu` | VM up → Ollama + hostfwd |

### Fluxos de produto recorrentes
1. **Card Olie (DOP/OS)**  
   Abrir VM do card → Cursor no workspace olie → MCP media → skill `olie-project-image-analysis` / `olie-project-video-conversion`. Salvar em `~/git/olie/cards/{código}/{mediaId}.md`, **versionar no meta-repo** (commit/push); na correção, **reusar** (não reanalisar). Tech lead: **não** enviar análise no conteúdo do projeto.
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
| Prompt guest Ollama | `vid2agent-code/prompts/host-ollama-ready.md` |
| Prompt API para Olie | `vid2agent-code/prompts/guest-api-ready-for-olie.md` |
| Skill imagens | `olie/overlay/**/olie-project-image-analysis` |
| Skill vídeo | `olie/overlay/**/olie-project-video-conversion` |
