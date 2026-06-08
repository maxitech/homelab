#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Starting full VM preparation ==="
echo

echo "=== Running 00-system-update.sh ==="
bash "$SCRIPT_DIR/00-system-update.sh"
echo

echo "=== Running 10-disable-default-user.sh ==="
bash "$SCRIPT_DIR/10-disable-default-user.sh"
echo

# -------------------------------
# Optional SSH password auth disable
# -------------------------------
echo -n "Disable SSH password authentication? (y/n): "
read DISABLE_SSH_PW < /dev/tty

if [[ "$DISABLE_SSH_PW" =~ ^[Yy]$ ]]; then
    echo
    echo "=== Running 11-disable-pwd-ssh-auth.sh ==="
    bash "$SCRIPT_DIR/11-disable-pwd-ssh-auth.sh"
    SSH_PW_DISABLED=true
else
    echo
    echo "SSH password authentication NOT disabled."
    SSH_PW_DISABLED=false
fi

echo


# -------------------------------
# Optional Docker installation
# -------------------------------
echo -n "Install Docker? (y/n): "
read INSTALL_DOCKER < /dev/tty

if [[ "$INSTALL_DOCKER" =~ ^[Yy]$ ]]; then
    echo
    echo "=== Running 20-install-docker.sh ==="
    bash "$SCRIPT_DIR/20-install-docker.sh"
    DOCKER_INSTALLED=true
else
    echo
    echo "Docker installation skipped."
    DOCKER_INSTALLED=false
fi

echo
echo "=== VM preparation completed ==="

if [[ "$DOCKER_INSTALLED" = true ]]; then
    echo "=== IMPORTANT: A reboot is required for Docker group changes to take effect ==="
    echo "=== After reboot, run: 30-test-docker.sh ==="
    echo

    echo -n "Reboot now? (y/n): "
    read REBOOT_CHOICE < /dev/tty

    if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
        echo "Rebooting system..."
        sudo reboot
    else
        echo "Reboot skipped. Please reboot manually before testing Docker."
    fi
else
    echo "No Docker installed — reboot not required."
fi