# Passthrough RTX 3060 → Windows 11 (OVMF / VFIO)

Runbook do **que fazer** neste host. Base: [PCI passthrough via OVMF](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF) (Arch Wiki). Não substitui o wiki; filtra o caminho para o jarvis.

**Problema que resolve:** jogar na VM Win11 com GPU dedicada. GeForce não tem vGPU — é **1 placa → 1 VM**.

## Alvo deste host

| Papel | Peça | PCI | IDs |
| --- | --- | --- | --- |
| **Host** (Hyprland) | RTX 5060 8 GB | `01:00.0` + áudio `01:00.1` | `10de:2d05` / `10de:22eb` |
| **Guest Win11** | RTX 3060 12 GB | `08:00.0` + áudio `08:00.1` | `10de:2504` / `10de:228e` |
| Reserva display | iGPU UHD 770 | `00:02.0` | — |

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

- [ ] Se não estiver: parâmetro de boot **`intel_iommu=on`** (e opcional `iommu=pt`). Em Omarchy/systemd-boot ou GRUB — onde o host já define cmdline. Reboot.

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

- [ ] IDs deste host: `10de:2504,10de:228e`.

**Opção A — modprobe (preferida se funcionar):**

```bash
# /etc/modprobe.d/vfio.conf
options vfio-pci ids=10de:2504,10de:228e
softdep nvidia pre: vfio-pci
```

**Opção B — initramfs (mais forte):** além do `options`/`ids`, carregar cedo `vfio_pci` `vfio` `vfio_iommu_type1` no mkinitcpio/`MODULES`, regenerar initramfs. Se o framebuffer “congela” no prompt de disco cifrado, incluir drivers da GPU do **host** (5060) no initramfs — ver aviso kernel 6.0+ no wiki.

- [ ] Reboot.
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

- [PCI passthrough via OVMF](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [PCI passthrough via OVMF/Examples](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF/Examples)
- [QEMU/Guest graphics acceleration](https://wiki.archlinux.org/title/QEMU/Guest_graphics_acceleration) (Looking Glass)
- Estado / tarefas: `life.md` · decisão: `HISTORICO.md`
