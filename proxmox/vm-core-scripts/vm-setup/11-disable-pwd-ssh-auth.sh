#!/bin/bash
set -e

echo "=== Disabling SSH password authentication ==="

sudo sed -i 's/^[# ]*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

if [ -f /etc/ssh/sshd_config.d/50-cloud-init.conf ]; then
    sudo sed -i 's/^[# ]*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/50-cloud-init.conf
fi
sudo service ssh reload

echo "=== SSH password authentication disabled (Proxmox Console still works) ==="