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

- [ ] `qemu-desktop` `libvirt` `edk2-ovmf` `virt-manager` (+ `dnsmasq` se rede default).
- [ ] Seguir `Libvirt#Configuration` do Arch (usuário no grupo, socket, etc.).
- [ ] Firmware da guest: **UEFI (OVMF)** — não SeaBIOS.
- [ ] Preferir sessão **system** no virt-manager para OVMF não ficar cinza (wiki). Se o resto do lab usa `qemu:///session`, decidir uma domain Win11 em system **ou** garantir OVMF/user docs equivalentes — anotar aqui o URI escolhido.

### 5. Criar / preparar a guest Win11

- [ ] VM nova (ou existente): **Customize before install** → Overview → Firmware **UEFI**.
- [ ] CPU: `host-passthrough` (`virt-xml NOME --edit --cpu host-passthrough`).
- [ ] Instalar Windows com ISO em `~/Downloads/isos/`; virtio drivers ([Fedora virtio-win](https://docs.fedoraproject.org/en-US/quick-docs/creating-windows-virtual-machines-using-virtio-drivers/)) para disco/rede se for o caso.
- [ ] Desligar a VM.

### 6. Anexar a 3060 (PCI hostdev)

- [ ] Em virt-manager: Add Hardware → **PCI Host Device** → `08:00.0` e `08:00.1` (o par).
- [ ] Ou XML `hostdev` managed para os dois.
- [ ] Remover (quando for display só na 3060): QXL/spice video se conflitar; **manter** um caminho de input no host.
- [ ] Ligar: splash **OVMF** no monitor da 3060 = sucesso deste passo.

### 7. Guest Windows: driver NVIDIA

- [ ] Instalar driver GeForce na guest.
- [ ] Se Error 43 / tela preta (comum em GeForce + KVM), no XML:

```xml
<features>
  <hyperv>
    <vendor_id state='on' value='randomid'/>
  </hyperv>
  <!-- drivers NVIDIA antigos (<465) também: -->
  <kvm>
    <hidden state='on'/>
  </kvm>
</features>
```

(Hoje drivers ≥465: `vendor_id` ainda é o mais citado; `kvm hidden` só se ainda falhar.)

- [ ] Device Manager: 3060 ok, sem Code 43.

### 8. Smoke de jogos (grátis)

- [ ] **Unigine Heaven** — vê a 3060 e FPS.
- [ ] **CS2** ou **War Thunder**.
- [ ] Anotar resultado em `life.md` / fechar a tarefa de passthrough.

### 9. Depois (opcional — não bloqueia o 1º smoke)

| Tema | Quando | Wiki |
| --- | --- | --- |
| Evdev / Looking Glass | 1 teclado+mouse host↔guest | Evdev / Looking Glass |
| CPU pin + isolcpus | stutter / latência | Performance tuning |
| Virtio disk/net | IO/rede | Virtio |
| Melhorar PCIe da 3060 | Gen1×4 | Slot CPU x8/x8; ver `life.md` |
| Áudio HDMI da 3060 | crepitação | MSI interrupts na guest |
| ACS override | grupo IOMMU sujo | Só se necessário |

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

- **[Games em Máquina Virtual com GPU Passthrough \| Entendendo QEMU, KVM, Libvirt](https://youtu.be/IDnabc3DjYY)** — Fabio Akita (Akitando #137, ~68 min, 2023). Em PT; percorre o mesmo fluxo do [wiki OVMF](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF) com contexto e XML de exemplo.
  - Setup dele (≠ jarvis): host **Manjaro** na **RX 6400**; guest Win11 com **RTX 3090** isolada. Aqui: host Omarchy/Hyprland na **5060**; guest com **3060**.
  - Atalhos úteis do vídeo ↔ este runbook:

| Cap. (aprox.) | Tema | Nosso passo |
| --- | --- | --- |
| 08:26 | IOMMU + grupos + `gpu-passthrough-manager` (AUR, só GRUB) | **1–3** (no jarvis preferir wiki/manual; tool é opcional) |
| 17:57–19:51 | Virt-Manager + OVMF/UEFI | **4–5** |
| 23:06 / 38:58 | Pinagem de CPU + cgroups | **9** (depois do smoke) |
| 45:32 | SPICE/QXL (display virtual) | útil até a 3060 pintar; depois remove |
| 47:22 | Áudio Pulse/PipeWire | opcional se não usar HDMI da 3060 |
| 50:01 | PCI passthrough NVIDIA | **6** |
| 50:27 | Teclado/mouse **evdev** | **9** |
| 52:47 | Win + ISO **virtio-win** | **5** |
| 57:15 | Games / performance | **8** |
| 57:53 | Anti-cheat (ex. Elden Ring) → dual boot | aceitar limite; não é bug do VFIO |
| 01:00:24 | Monitor 2 inputs (DDC) | cabo/entrada na 3060 |
| 01:03:08 | Suspend do host com VM ligada | hook / inhibit |

  - XML completo que ele mostra: [gist akitaonrails](https://gist.github.com/akitaonrails/d4d98b03f1126c81a20eb3ea57027ad2) (adaptar IDs `08:00.*` / CPU pin do 13700K — não copiar cego).
  - Transcrição / links: [akitando 137](https://www.akitaonrails.com/2023/02/01/akitando-137-games-em-maquina-virtual-com-gpu-passthrough-entendendo-qemu-kvm-libvirt).

### Wiki / docs

- [PCI passthrough via OVMF](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [PCI passthrough via OVMF/Examples](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF/Examples)
- [QEMU/Guest graphics acceleration](https://wiki.archlinux.org/title/QEMU/Guest_graphics_acceleration) (Looking Glass)
- Estado / tarefas: `life.md` · decisão: `HISTORICO.md`
