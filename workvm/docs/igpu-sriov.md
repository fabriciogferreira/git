# SR-IOV na iGPU (Intel UHD 770 / i7-13700K)

Guia do que é necessário no **host** para passar fatias da iGPU (VFs) às work VMs Arch + Hyprland, e quantas VMs fazem sentido com o hardware atual.

## Contexto

- **CPU / iGPU:** Intel Core i7-13700K — UHD Graphics 770 (32 EUs), PF `0000:00:02.0` `[8086:a780]`
- **Host:** Omarchy/Arch, Limine, 32 GB RAM, GPUs discretas + 1 iGPU
- **Hypervisor:** QEMU/KVM via libvirt (`virsh` / Virt-Manager)
- **Guest típico:** Arch + Hyprland, Laravel em Docker (~3 repos, ~4 containers), Cursor/Chrome sob demanda
- **VM de teste:** `teste-sr-iov`
- **Uso de GUI:** no máximo 2 Cursors abertos ao mesmo tempo; Chrome/DBeaver/Postman só quando necessário

A lentidão gráfica atual das VMs (VirtIO/SPICE/software) é esperada. SR-IOV melhora compositor, Cursor e Chrome; **não** acelera Laravel/Docker.

## Capacidade prática (32 GB)

| Limite | Número |
| --- | --- |
| VFs da UHD 770 | até **7** (teto de hardware / driver) |
| VMs com desktop fluido ao mesmo tempo | **2–3** |
| VMs de projeto no ar (2 com GUI, resto leve) | **3–4** confortável; **5** no limite |

Reserva ~6–8 GB para o host. Cada VM ativa com Cursor+Chrome pode ir a ~6–10 GB; idle com Docker ~3–5 GB. Com 32 GB, o gargalo costuma ser **RAM**, não o número de VFs.

### Papel das GPUs

| GPU | Uso sugerido |
| --- | --- |
| **iGPU (SR-IOV)** | Work VMs (Hyprland / Cursor / Chrome) — 1 VF por VM com GUI |
| **GPU dedicada 1** | Passthrough opcional para 1 VM “pesada”, ou host |
| **GPU dedicada 2** | Host / encode / outra VM |

## Pré-requisitos no host

1. **BIOS/UEFI**
   - Intel VT-x e **VT-d** (IOMMU) habilitados
   - Above 4G Decoding / Resizable BAR conforme a placa (às vezes necessário)
2. **Hypervisor:** QEMU/KVM + libvirt (PCI `hostdev` / Virt-Manager → PCI Host Device)
3. **Kernel + driver i915 com SR-IOV**
   - No desktop Raptor Lake o suporte SR-IOV da iGPU **não** vem completo no i915 vanilla na maioria dos kernels
   - Caminho usual: módulo DKMS da comunidade, p.ex. [strongtz/i915-sriov-dkms](https://github.com/strongtz/i915-sriov-dkms) ou forks atualizados ([Valantin/i915-sriov-dkms](https://github.com/Valantin/i915-sriov-dkms))
4. **IOMMU + params i915** na cmdline do host

   Neste host Omarchy o IOMMU já está em `/etc/limine-entry-tool.d/vfio-osx.conf`:

   ```text
   iommu=pt intel_iommu=on …
   ```

   Params i915 SR-IOV (versionados neste repo):

   - Fonte: [`workvm/host/limine-entry-tool.d/i915-sriov.conf`](../host/limine-entry-tool.d/i915-sriov.conf)
   - Instalar:

     ```bash
     sudo cp workvm/host/limine-entry-tool.d/i915-sriov.conf /etc/limine-entry-tool.d/
     sudo limine-update
     ```

   - Resultado esperado na cmdline (junto com o IOMMU):

     ```text
     intel_iommu=on iommu=pt i915.enable_guc=3 i915.max_vfs=7 module_blacklist=xe
     ```

   Importante: rode `limine-update` **depois** do DKMS (o script já faz isso), para o UKI/initramfs embutir o i915 patched. Sem isso o boot carrega o i915 vanilla (`max_vfs` ignorado).

5. **Criar as VFs** após o boot (até 7), exemplo (PF `00:02.0`):

   ```bash
   echo 4 | sudo tee /sys/bus/pci/devices/0000:00:02.0/sriov_numvfs
   ```

   Persistência: unit systemd versionada em
   [`workvm/host/systemd/workvm-igpu-sriov.service`](../host/systemd/workvm-igpu-sriov.service).

   Setup automatizado do host (drop-in Limine + DKMS + unit):

   ```bash
   sudo ./workvm/bin/host-igpu-sriov-setup.sh
   # depois: reboot, e se necessário:
   sudo systemctl start workvm-igpu-sriov.service
   ```

6. Confirmar no host:

   ```bash
   dmesg | grep -i 'i915\|sriov'
   lspci -nn | grep -iE 'vga|display'
   cat /sys/bus/pci/devices/0000:00:02.0/sriov_numvfs
   ```

   Esperado: PF em modo SR-IOV e VFs (`00:02.1`, `00:02.2`, …); `sriov_numvfs` = 4 (ou o valor escolhido).

## Guest (QEMU/KVM — ex.: `teste-sr-iov`)

1. CPU type **host** (recomendado)
2. Passar **uma VF** da iGPU (`hostdev` PCI), nunca o PF (`00:02.0`)
3. Guest Linux com driver i915 compatível com VF — no guest:

   ```bash
   sudo ./workvm/bin/guest-igpu-sriov-setup.sh
   # reboot da VM
   lspci -nnk -s 07:00.0   # Kernel driver in use: i915
   ```

   Drop-in Limine: [`workvm/guest/limine-entry-tool.d/i915-sriov-guest.conf`](../guest/limine-entry-tool.d/i915-sriov-guest.conf)
   (`i915.enable_guc=3 module_blacklist=xe` — sem `max_vfs`).
4. Display / fluidez: SPICE+Virtio não fica fluido como o host.

   **Looking Glass + kvmfr** (preferível a `/dev/shm`; evita DMA map failure com a VF):

   ```bash
   # host
   sudo ./workvm/bin/host-looking-glass-kvmfr-setup.sh
   ./workvm/bin/vm-looking-glass-kvmfr-attach.sh teste-sr-iov
   virsh -c qemu:///session start teste-sr-iov
   looking-glass-client -f /dev/kvmfr0

   # VM (sessão gráfica) — host LG no Linux ainda é experimental
   ./workvm/bin/guest-looking-glass-setup.sh
   looking-glass-host
   ```

   Não use `vm-looking-glass-attach.sh` (IVSHMEM em `/dev/shm`) — derruba a VM com a VF.
   Sunshine/Moonlight ficou como alternativa opcional (mais passos de UI).
5. Stack da work VM: scripts em `workvm/` (`*-setup.sh` do meta-repo)

Exemplo libvirt **session** (`qemu:///session`, como `teste-sr-iov`):

1. CPU já em `host-passthrough` (ok).
2. No host, bindar VFs em `vfio-pci` (session não consegue `managed=yes`):

   ```bash
   sudo ./workvm/bin/host-igpu-vfio-bind.sh
   ```

3. Anexar **1 VF** com `managed='no'`:

   ```bash
   virt-xml teste-sr-iov --add-device --host-device pci_0000_00_02_1
   # depois editar managed='no' se o virt-xml gravar yes
   virsh -c qemu:///session start teste-sr-iov
   ```

Nunca passe o PF (`00:02.0`).

## Checklist resumido

- [x] VT-d / IOMMU no BIOS (cmdline já tem `intel_iommu=on iommu=pt`)
- [x] Drop-in Limine `i915-sriov.conf` instalado + `limine-update` **após** DKMS + reboot
- [x] DKMS i915-sriov instalado e carregando (módulo `2026.09.16-sriov` em memória)
- [x] `sriov_numvfs` = 4 (unit `workvm-igpu-sriov.service`)
- [x] `lspci` mostra as VFs (`00:02.1`–`00:02.4`)
- [x] VM `teste-sr-iov` recebe **1 VF** (`00:02.1`, hostdev managed=no; VFs em vfio-pci)
- [ ] No máximo 2 VMs com Cursor/Chrome abertos (32 GB)
- [ ] GPUs discretas não conflitam com o PF da iGPU no host
- [x] Guest: DKMS i915-sriov + `lspci` mostra a Intel VF com `Kernel driver in use: i915`

## Referências

- Intel: [Graphics Virtualization Technologies Support](https://www.intel.com/content/www/us/en/support/articles/000093216/graphics/processor-graphics.html) (13th gen = SR-IOV)
- DKMS: [strongtz/i915-sriov-dkms](https://github.com/strongtz/i915-sriov-dkms)
- Relatos em desktop 13th gen / Proxmox/libvirt: threads Level1Techs e issues dos repositórios DKMS

## Fora de escopo deste doc

- ROM/GOP da VF em guests Windows
- Tuning fino de hugepages / CPU pinning

Quando o host estiver com as VFs estáveis, o próximo passo é amarrar 1 VF em `teste-sr-iov` e validar Hyprland + Chrome + Cursor sem o caminho só-software.
