# Passthrough RTX 3060 → Windows 11 (OVMF / VFIO)

Runbook do **que fazer** neste host. Base: [PCI passthrough via OVMF](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF) (Arch Wiki). Não substitui o wiki; filtra o caminho para o jarvis.

**Problema que resolve:** jogar na VM Win11 com GPU dedicada. GeForce não tem vGPU — é **1 placa → 1 VM**.

## Alvo deste host

| Papel | Peça | PCI | IDs |
| --- | --- | --- | --- |
| **Host** (Hyprland) | RTX 5060 8 GB | `01:00.0` + áudio `01:00.1` | `10de:2d05` / `10de:22eb` · IOMMU **grupo 16** (só o par) |
| **Guest Win11** | RTX 3060 12 GB | `08:00.0` + áudio `08:00.1` | `10de:2504` / `10de:228e` · IOMMU **grupo 21** (só o par) |
| Reserva display | iGPU UHD 770 | `00:02.0` | — |

**Feito (2026-11-13):**
- IOMMU: `intel_iommu=on iommu=pt`; **23** grupos; 3060 = grupo 21.
- VFIO: `10de:2504`/`10de:228e` → `vfio-pci`; `nvidia-smi` só **5060**. Pacotes qemu/libvirt/OVMF/virt-manager já no host.

- Board: **MSI PRO Z690-A** · CPU: **i7-13700K** (VT-x + VT-d).
- ISO: `~/Downloads/isos/Windows11_Client_x64_pt-br_*.iso`.
- Smoke na guest (grátis): **Unigine Heaven** → **CS2** ou **War Thunder**.
- Link da 3060 hoje: **Gen1 ×4** (nativo 4.0 ×16) — passthrough funciona; FPS pode sofrer. Melhorar slot é passo **depois** do primeiro boot com driver.

**Não passar:** `01:00.*` (5060) enquanto for o vídeo do host. **Não** bindar root port/bridge no vfio.

Fonte da verdade do estado: `life.md` (GPUs). Decisão: `HISTORICO.md`.

---

## Checklist (ordem)

Marque ao concluir. Cada passo tem o comando / critério de “ok”.

### 0. Pré-requisitos (leitura rápida)

- [ ] Monitor (ou cabo) na **3060** — sem tela nela a guest não mostra imagem; Spice/VNC não substitui desempenho.
- [ ] Teclado/mouse **de reserva no host** (ou plano Looking Glass / evdev depois).
- [ ] BIOS: **VT-d** / “Intel Virtualization for Directed I/O” **ligado** (não confundir só com VT-x).
- [ ] Nada crítico rodando na 3060 no host (ex.: Ollama usando as duas) antes de isolar.

### 1. IOMMU no kernel

- [ ] Confirmar no dmesg:

```bash
sudo dmesg | grep -iE 'IOMMU|DMAR|VT-d'
```

Esperado: linhas `DMAR` / IOMMU ativo.

- [ ] Se não estiver (0 grupos / sem `intel_iommu` no cmdline): drop-in Limine neste host:

```bash
sudo cp ~/git/host-files/limine-entry-tool.d/iommu.conf /etc/limine-entry-tool.d/
sudo limine-update
sudo reboot
```

Depois do reboot: `ls /sys/kernel/iommu_groups | wc -l` deve ser **> 0** e `cat /proc/cmdline` deve ter `intel_iommu=on iommu=pt`.

### 2. Grupos IOMMU (isolamento)

- [ ] Rodar (script do wiki):

```bash
#!/bin/bash
shopt -s nullglob
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
  echo "IOMMU Group ${g##*/}:"
  for d in $g/devices/*; do
    echo -e "\t$(lspci -nns ${d##*/})"
  done
done
```

- [ ] Anotar o **grupo** que contém `08:00.0` e `08:00.1`.
- [ ] Ideal: **só** VGA+áudio da 3060 nesse grupo. Se vier root port + outras placas, ou muda o slot PCIe, ou (último recurso) ACS override — ver wiki § ACS; evitar no primeiro smoke.
- [ ] Confirmar reset:

```bash
ls /sys/bus/pci/devices/0000:08:00.0/reset
ls /sys/bus/pci/devices/0000:08:00.1/reset
```

### 3. Isolar a 3060 com `vfio-pci` (cedo no boot)

**Atenção:** depois do reboot, a 3060 **some do host** (só vfio) até desfazer. Display do host deve continuar na **5060**.

- [ ] IDs deste host: `10de:2504,10de:228e` (grupo 21).
- [ ] Omarchy early-loada `nvidia*` no initramfs — por isso **modprobe + mkinitcpio** juntos (VFIO antes do nvidia). Arquivos em `host-files/`:

```bash
sudo cp ~/git/host-files/modprobe.d/vfio.conf /etc/modprobe.d/
sudo cp ~/git/host-files/mkinitcpio.conf.d/00-vfio.conf /etc/mkinitcpio.conf.d/
sudo mkinitcpio -P
sudo reboot
```

- [ ] Verificar:

```bash
lspci -nnk -d 10de:2504
lspci -nnk -d 10de:228e
# Kernel driver in use: vfio-pci
```

```bash
nvidia-smi -L
# só a 5060 deve aparecer
```

### 4. Pacotes e libvirt (sistema)

**Já no jarvis:** `qemu-desktop` `libvirt` `edk2-ovmf` `virt-manager` `dnsmasq`.

- [ ] `libvirtd` / socket ok; usuário no grupo certo (`Libvirt#Configuration`).
- [ ] Preferir sessão **QEMU/KVM** (system) no Virt-Manager se OVMF ficar cinza na user session.
- [ ] Rede: `default` (NAT) basta pro smoke; Bridge só se precisar de IP “como máquina física”.

### 5. Criar / preparar a guest Win11

(Alinhado ao fluxo do Akita + wiki; chipset/TPM que o video enfatiza.)

- [ ] Nova VM → ISO `~/Downloads/isos/Windows11_*.iso` → **Customize before install**.
- [ ] Overview: chipset **Q35**, firmware **UEFI / OVMF** (com Secure Boot se a lista do OVMF tiver; Win11 gosta).
- [ ] Add Hardware → **TPM**: emulado, modelo **TIS**, versão **2.0**.
- [ ] CPU: `host-passthrough` (ajuste fino de pin/cgroups = passo 9).
- [ ] Disco: bus **VirtIO**; baixar ISO [virtio-win](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/) e anexar como **CD-ROM SATA** (junto com a ISO do Windows em SATA). No instalador: **Load driver** → pasta `amd64` do virtio (vioscsi / viostor) até o disco aparecer.
- [ ] Deixar **Display SPICE + Video QXL/Virtio** só na instalação (streaming na janela do Virt-Manager).
- [ ] Instalar Windows → Device Manager: instalar resto dos virtio do CD → reboot guest → **desligar**.

### 6. Anexar a 3060 (PCI hostdev)

- [ ] Add Hardware → **PCI Host Device** → `08:00.0` **e** `08:00.1` (sem o áudio a guest pode falhar o boot — Akita/wiki).
- [ ] Cabo no monitor na **3060** (segunda entrada HDMI/DP). Sem tela física, SPICE não substitui o jogo.
- [ ] Ligar: splash **OVMF** / Windows no monitor da 3060 = sucesso deste passo.
- [ ] Depois dos drivers NVIDIA (passo 7): remover SPICE/QXL pelo XML se o Virt-Manager recusar — guest passa a usar só a 3060.

### 7. Guest Windows: driver NVIDIA

- [ ] Instalar GeForce (site NVIDIA / GeForce Experience).
- [ ] Se Error 43 / tela preta, no XML:

```xml
<features>
  <hyperv>
    <vendor_id state='on' value='randomid'/>
  </hyperv>
  <!-- drivers NVIDIA antigos (<465): -->
  <kvm>
    <hidden state='on'/>
  </kvm>
</features>
```

- [ ] Device Manager: 3060 ok, sem Code 43.

### 8. Smoke de jogos (grátis)

- [ ] **Unigine Heaven** — vê a 3060 e FPS.
- [ ] **CS2** ou **War Thunder**.
- [ ] **Anti-cheat:** vários jogos online (ex. Elden Ring Easy Anti-Cheat, Valorant) detectam VM e bloqueiam — não é falha do passthrough. Offline / dual-boot nativo se precisar (Akita).
- [ ] Anotar resultado em `life.md` / fechar a tarefa.

### 9a. CPU pin + isolamento host (cgroups) — dinâmico

Base: [wiki OVMF § Isolating pinned CPUs / systemd](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Dynamically_isolating_CPUs) + Akita cap. ~23–39 (pin + hook).  
**Não copie** `AllowedCPUs=0,1,6,7` do exemplo de 12 threads — em outro PC (ou neste 13700K) os números mudam.

#### O que fazer em **qualquer** máquina

1. Ver topologia:
   ```bash
   lscpu -e
   lstopo          # pacote hwloc
   cat /sys/devices/cpu_core/cpus /sys/devices/cpu_atom/cpus 2>/dev/null   # Intel hybrid
   ```
2. Gerar o plano (script versionado — rediscovery):
   ```bash
   # default: 2 P-cores pro host; resto dos P → guest; E-cores ficam no host
   HOST_P_CORES=2 ~/git/host-files/bin/cpu-pin-plan
   HOST_P_CORES=2 ~/git/host-files/bin/cpu-pin-plan --xml
   HOST_P_CORES=2 ~/git/host-files/bin/cpu-pin-plan --write /tmp/cpu-pin.env
   ```
3. Colar o XML (`vcpu` / `cputune` / `cpu host-passthrough` + topology) na domain Win11 (`virsh edit NOME`).
4. Instalar hook + lib (sudo):
   ```bash
   sudo mkdir -p /etc/libvirt/hooks/qemu.d /usr/local/lib/workvm
   sudo cp ~/git/host-files/bin/cpu-pin-lib.sh /usr/local/lib/workvm/
   sudo cp ~/git/host-files/libvirt/hooks/qemu /etc/libvirt/hooks/qemu
   sudo cp ~/git/host-files/libvirt/hooks/qemu.d/cpu-pinning.sh /etc/libvirt/hooks/qemu.d/
   sudo chmod +x /etc/libvirt/hooks/qemu /etc/libvirt/hooks/qemu.d/cpu-pinning.sh
   # opcional: fixar o plano gerado (senão o hook recalcula com HOST_P_CORES=2)
   sudo cp /tmp/cpu-pin.env /etc/libvirt/hooks/cpu-pin.env
   # opcional: só uma VM — no env: PIN_GUEST_NAME=nome-da-domain
   sudo systemctl restart libvirtd
   ```
5. Ligar a guest → no host, carga pesada deve ficar em `HOST_ALLOWED`; threads do guest saturam `GUEST_CPUS`. Desligar guest → host volta a `ALL_CPUS`.

Hook usa `prepare` / `release` (wiki). Precisa **systemd ≥ 244** e **cgroups v2**.

#### Exemplo jarvis — domain `win11` (escolhido 2026-11-13)

| Papel | CPUs | Uso |
| --- | --- | --- |
| Host P | `0-1` | `emulatorpin` |
| Host P | `2`, `3` | `iothreadpin` 1 e 2 |
| Host E | `16-23` | cgroup (`HOST_ALLOWED`) — não vão pra guest |
| Guest P | `4-15` | 12× `vcpupin` · topology **6 cores × 2 threads** |

Domain completa (copiar): `host-files/libvirt/domains/win11.xml`  
Snippet só de CPU: `host-files/libvirt/domains/win11.cpu-pin.snippet.xml`  
Env do hook: `host-files/libvirt/hooks/cpu-pin.env.example` → `/etc/libvirt/hooks/cpu-pin.env`

**Corrigir se ainda estiver assim:** `<vcpu …>6</vcpu>` com doze linhas de `vcpupin` — o certo é **`<vcpu placement='static'>12</vcpu>`** (+ `<iothreads>2</iothreads>` se usar os dois `iothreadpin`). Sem isso a topology 6×2 não fecha.

Trocar de PC: `cpu-pin-plan` de novo → novos números → atualizar snippet/env/domain; não depender deste quadro.

#### Política padrão do script

- Intel hybrid: E-cores **sempre no host** (fundo / IO); guest leva P-cores menos `HOST_P_CORES`.
- Sem hybrid: trata todos como P; primeiros `HOST_P_CORES` cores físicos pro host, resto guest.
- AMD com dois L3 (Akita): o script não escolhe L3 automaticamente — use `lstopo`, defina `HOST_ALLOWED`/`GUEST_CPUS` no `cpu-pin.env` gerado/ajustado à mão.

### 9b. Outros opcionais (depois do smoke)

| Tema | Nota prática (Akita / wiki) |
| --- | --- |
| **Evdev** | Um teclado+mouse: `/dev/input/by-id/*event*`; `cat` no device enquanto mexe; toggle **Ctrl esq+dir**. |
| **cpupower** | `performance` enquanto joga. |
| **ddcutil** | Trocar input do monitor (`detect` / `setvcp 60 …`). |
| **Suspend do host** | Desligar suspend enquanto a Win11 estiver up. |
| **Áudio** | PipeWire ↔ pulse do QEMU; HDMI da 3060 = guest. |
| **PCIe 3060 Gen1×4** | Melhorar slot; ver `life.md`. |
| **Huge pages / iothreads / USB hub** | Wiki OVMF § performance. |

---


## Desfazer isolamento (host volta a ver a 3060)

1. Remover `ids=` / softdep / módulos vfio do early load.
2. Regenerar initramfs se usou.
3. Reboot; `nvidia-smi` deve listar as duas.
4. Tirar hostdevs da domain se não for mais passar.

Script bind/unbind dinâmico do wiki (§ Isolating) é alternativa a “sempre vfio no boot” se quiser a 3060 no host fora dos jogos.

---

## Referências

### Vídeo (orientação)

- **[Games em Máquina Virtual com GPU Passthrough \| Entendendo QEMU, KVM, Libvirt](https://youtu.be/IDnabc3DjYY)** — Fabio Akita (Akitando #137, ~68 min, 2023). Em PT. **Não é passo a passo único** (palavras dele); é aula de conceitos + demo. Checklist acima = o que fazer no jarvis; o vídeo explica o *porquê*.
  - Setup dele (≠ jarvis): host **Manjaro** + **RX 6400**; guest Win11 + **RTX 3090** em VFIO. Aqui: host **Omarchy/Hyprland** + **5060**; guest + **3060**. Ele usa `gpu-passthrough-manager` (AUR, GRUB); nós usamos Limine + `host-files/`.
  - Post + links + gist XML: [akitando 137](https://www.akitaonrails.com/2023/02/01/akitando-137-games-em-maquina-virtual-com-gpu-passthrough-entendendo-qemu-kvm-libvirt) · [gist XML](https://gist.github.com/akitaonrails/d4d98b03f1126c81a20eb3ea57027ad2) (adaptar IDs/`cpuset` do 13700K — **não** copiar cego).
  - Transcrição completa ficou no chat do agente (2026-11-13); extrato útil já absorvido nos passos 5–9 deste arquivo.

| Cap. (aprox.) | Tema no vídeo | Nosso passo |
| --- | --- | --- |
| 00:44 | Setup físico / por que VFIO ≠ dual boot | contexto |
| 08:26 | IOMMU, grupos, VFIO stub | **1–3** (feito) |
| 13:46 | Redes virtuais (NAT vs bridge) | **4** |
| 17:57–19:51 | Virt-Manager, Q35, OVMF, TPM 2.0 | **5** |
| 23:06 / 33:01 / 38:58 | QEMU vs KVM vs libvirt; pin + cgroups | **9** |
| 45:32 | SPICE / QXL (instalação) → remover depois | **5–6** |
| 47:22 | Áudio Pulse/PipeWire | **9** |
| 50:01 | PCI NVIDIA + áudio do mesmo grupo | **6** |
| 50:27 | Evdev (Ctrl×2) | **9** |
| 52:47 | virtio-win ISO + Load driver | **5** |
| 57:15 | Games | **8** |
| 57:53 | Anti-cheat → dual boot / offline | **8** |
| 01:00:24 | `ddcutil` input do monitor | **9** |
| 01:03:08 | Suspend do host + `virsh start` wrapper | **9** |

**Ideias que ele enfatiza e o checklist já cobre:** IOMMU = endereço virtual pro guest falar com o device sem a CPU host no meio; VFIO = “plugue” até a VM ligar; instalar Win com SPICE e **só então** cravar a GPU; virtio = guest *sabe* que é VM (paravirt); pinagem = mesmo L3 + host fora desses cores só enquanto a guest roda; monitor com 2 inputs = host na 5060, guest na 3060.

### Wiki / docs

- [PCI passthrough via OVMF](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [PCI passthrough via OVMF/Examples](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF/Examples)
- [GPU passthrough (Gentoo)](https://wiki.gentoo.org/wiki/GPU_passthrough_with_libvirt_qemu_kvm) (Akita recomenda como complemento)
- [QEMU/Guest graphics acceleration](https://wiki.archlinux.org/title/QEMU/Guest_graphics_acceleration) (Looking Glass)
- Estado / tarefas: `life.md` · decisão: `HISTORICO.md`
