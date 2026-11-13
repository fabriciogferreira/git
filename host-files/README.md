# host-files

Snippets do host jarvis para copiar em `/etc` com sudo. Fonte da verdade do fluxo: `../host-gpu-passthrough.md`.

## IOMMU (já aplicado)

```bash
sudo cp ~/git/host-files/limine-entry-tool.d/iommu.conf /etc/limine-entry-tool.d/
sudo limine-update
sudo reboot
```

## VFIO — isolar RTX 3060 (passo 3)

Depois do reboot a 3060 some do host (`nvidia-smi` só lista a 5060). Display deve continuar na 5060.

```bash
sudo cp ~/git/host-files/modprobe.d/vfio.conf /etc/modprobe.d/
sudo cp ~/git/host-files/mkinitcpio.conf.d/00-vfio.conf /etc/mkinitcpio.conf.d/
sudo mkinitcpio -P
sudo reboot
```

Verificar:

```bash
lspci -nnk -d 10de:2504   # Kernel driver in use: vfio-pci
lspci -nnk -d 10de:228e
nvidia-smi -L             # só GeForce RTX 5060
```

## CPU pin + cgroups (passo 9a) — **recalcular em PC novo**

```bash
HOST_P_CORES=2 ~/git/host-files/bin/cpu-pin-plan
HOST_P_CORES=2 ~/git/host-files/bin/cpu-pin-plan --xml
HOST_P_CORES=2 ~/git/host-files/bin/cpu-pin-plan --write /tmp/cpu-pin.env

sudo mkdir -p /etc/libvirt/hooks/qemu.d /usr/local/lib/workvm
sudo cp ~/git/host-files/bin/cpu-pin-lib.sh /usr/local/lib/workvm/
sudo cp ~/git/host-files/libvirt/hooks/qemu /etc/libvirt/hooks/qemu
sudo cp ~/git/host-files/libvirt/hooks/qemu.d/cpu-pinning.sh /etc/libvirt/hooks/qemu.d/
sudo chmod +x /etc/libvirt/hooks/qemu /etc/libvirt/hooks/qemu.d/cpu-pinning.sh
sudo cp /tmp/cpu-pin.env /etc/libvirt/hooks/cpu-pin.env   # opcional mas recomendado
sudo systemctl restart libvirtd
```

Detalhe e exemplo 13700K: `../host-gpu-passthrough.md` § 9a.
