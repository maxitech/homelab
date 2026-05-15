#!/bin/bash
set -e

DEFAULT_USER="ubuntu"
CURRENT_USER="${SUDO_USER:-$USER}"

echo "=== Checking if default user '$DEFAULT_USER' exists ==="

if [ "$CURRENT_USER" = "$DEFAULT_USER" ]; then
    echo "!!! ERROR: You are currently logged in as '$DEFAULT_USER'."
    echo "!!! Cannot disable the user you are logged in with."
    exit 1
fi

if id "$DEFAULT_USER" >/dev/null 2>&1; then
    echo "=== Disabling default user '$DEFAULT_USER' ==="
    sudo usermod --lock "$DEFAULT_USER"
    sudo usermod --expiredate 1 "$DEFAULT_USER"
    echo "=== User '$DEFAULT_USER' has been disabled ==="
else
    echo "=== User '$DEFAULT_USER' does not exist, skipping ==="
fi