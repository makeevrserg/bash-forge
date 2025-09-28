#!/usr/bin/env bash
set -e

if ! pacman -Q zram-generator &>/dev/null; then
    echo "Installing zram-generator..."
    sudo pacman -Sy --noconfirm zram-generator
fi

sudo tee /etc/systemd/zram-generator.conf >/dev/null <<EOF
[zram0]
zram-size = ram
compression-algorithm = zstd
EOF

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Activating zram swap..."
sudo systemctl restart systemd-zram-setup@zram0.service

echo "Show"
