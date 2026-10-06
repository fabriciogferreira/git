# SR-IOV na iGPU (Intel UHD 770 / i7-13700K)

Guia do que é necessário no **host** para passar fatias da iGPU (VFs) às work VMs Arch + Hyprland, e quantas VMs fazem sentido com o hardware atual.

## Contexto

- **CPU / iGPU:** Intel Core i7-13700K — UHD Graphics 770 (32 EUs)
- **Host:** 32 GB RAM, 2 GPUs discretas + 1 iGPU
- **Guest típico:** Arch + Hyprland, Laravel em Docker (~3 repos, ~4 containers), Cursor/Chrome sob demanda
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
2. **Hypervisor** com PCI passthrough (Proxmox, libvirt/QEMU/KVM, etc.)
3. **Kernel + driver i915 com SR-IOV**
   - No desktop Raptor Lake o suporte SR-IOV da iGPU **não** vem completo no i915 vanilla na maioria dos kernels
   - Caminho usual: módulo DKMS da comunidade, p.ex. [strongtz/i915-sriov-dkms](https://github.com/strongtz/i915-sriov-dkms) ou forks atualizados ([Valantin/i915-sriov-dkms](https://github.com/Valantin/i915-sriov-dkms))
4. **IOMMU ativo** na cmdline do host, por exemplo:
   ```text
   intel_iommu=on iommu=pt i915.enable_guc=3 i915.max_vfs=7
   ```
5. **Criar as VFs** após o boot (até 7), exemplo (ajuste o BDF se não for `00:02.0`):
   ```bash
   echo 4 | sudo tee /sys/bus/pci/devices/0000:00:02.0/sriov_numvfs
   ```
   Persistência comum: `sysfsutils` + `/etc/sysfs.conf`, ou udev/systemd.
6. Confirmar no host:
   ```bash
   dmesg | grep -i 'i915\|sriov'
   lspci -nn | grep -i vga
   ```
   Esperado: PF em modo SR-IOV e VFs (`00:02.1`, `00:02.2`, …).

## Guest (cada work VM)

1. QEMU/Proxmox: CPU type **host** (recomendado)
2. Passar **uma VF** da iGPU para a VM (PCI passthrough), não o PF (`00:02.0`)
3. Guest Linux com driver i915 compatível com VF (mesmo ecossistema DKMS/GuC costuma ser necessário no guest)
4. Display: preferir a saída da VF (evita depender só de SPICE/VirtIO-GPU para o compositor)
5. Stack da work VM: `arch-vm-setup.sh` + `arch-project-setup.sh` (já existentes neste meta-repo)

## Checklist resumido

- [ ] VT-d / IOMMU no BIOS
- [ ] Host com cmdline `intel_iommu=on` + params i915 SR-IOV
- [ ] DKMS i915-sriov instalado e carregando sem erro
- [ ] `sriov_numvfs` = número desejado (ex.: 4), ≤ 7
- [ ] `lspci` mostra as VFs
- [ ] Cada VM de projeto recebe **1 VF**
- [ ] No máximo 2 VMs com Cursor/Chrome abertos (32 GB)
- [ ] GPUs discretas não conflitam com o PF da iGPU no host

## Referências

- Intel: [Graphics Virtualization Technologies Support](https://www.intel.com/content/www/us/en/support/articles/000093216/graphics/processor-graphics.html) (13th gen = SR-IOV)
- DKMS: [strongtz/i915-sriov-dkms](https://github.com/strongtz/i915-sriov-dkms)
- Relatos em desktop 13th gen / Proxmox: threads Level1Techs e issues dos repositórios DKMS

## Fora de escopo deste doc

- Configuração exata por versão de Proxmox/libvirt (UI e XML mudam)
- ROM/GOP da VF em guests Windows
- Tuning fino de hugepages / CPU pinning

Quando o host estiver com as VFs estáveis, o próximo passo é amarrar 1 VF na definição da work VM e validar Hyprland + Chrome + Cursor sem o caminho só-software.
