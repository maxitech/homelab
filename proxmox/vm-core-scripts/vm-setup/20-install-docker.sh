#!/bin/bash
set -e

echo "=== Starting Docker installation ==="

# Determine the user who invoked sudo (or fallback to $USER)
TARGET_USER="${SUDO_USER:-$USER}"
echo "=== Detected target user: $TARGET_USER ==="

echo "=== Removing conflicting packages (if any) ==="
sudo apt remove -y $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc 2>/dev/null | cut -f1) || true

echo "=== Updating apt package index ==="
sudo apt update -y

echo "=== Installing required packages ==="
sudo apt install -y ca-certificates curl gnupg

echo "=== Setting up Docker GPG key ==="
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "=== Adding Docker repository ==="
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

echo "=== Updating apt package index ==="
sudo apt update -y

echo "=== Installing Docker Engine, CLI, containerd, buildx, compose ==="
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== Enabling and starting Docker service ==="
sudo systemctl enable docker
sudo systemctl start docker

echo "=== Adding user '$TARGET_USER' to docker group ==="
sudo usermod -aG docker "$TARGET_USER"

echo "=== Docker installation completed ==="