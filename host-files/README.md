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
