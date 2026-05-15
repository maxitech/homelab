#!/bin/bash
set -e

echo "=== Starting system update and upgrade ==="

sudo apt update -y
sudo apt upgrade -y

echo "=== System update completed successfully ==="