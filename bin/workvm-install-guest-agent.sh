#!/usr/bin/env bash
# VMs already cloned never re-run vm-setup, so they stay without qemu-guest-agent.
# Run once inside each existing guest. vm-setup.sh calls this for a new VM.
# Also enables sshd: Arch leaves it disabled, and the card chat gets connection refused.
set -euo pipefail

sudo pacman -S --needed --noconfirm qemu-guest-agent avahi
# The packaged unit is static (empty [Install]); enable would fail the script.
sudo systemctl add-wants multi-user.target qemu-guest-agent.service
sudo systemctl start qemu-guest-agent.service
sudo systemctl enable --now avahi-daemon.service

if [ -f /usr/lib/systemd/system/sshd.service ]; then
    sudo systemctl enable --now sshd.service
fi
