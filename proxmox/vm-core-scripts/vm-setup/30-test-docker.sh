#!/bin/bash
set -e

echo "=== Checking Docker service status ==="
sudo systemctl status docker --no-pager

echo "=== Running Docker hello-world test ==="
docker run hello-world

echo "=== Docker test completed successfully ==="