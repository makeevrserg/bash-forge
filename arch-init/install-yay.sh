#!/usr/bin/env bash

set -e

if command -v yay >/dev/null 2>&1; then
    echo "Skipping: yay is already installed"
    exit 0
fi

echo "Installing: yay"

sudo pacman -Sy --needed --noconfirm git base-devel

# --- Clone yay from AUR ---
if [[ ! -d "/tmp/yay" ]]; then
    git clone https://aur.archlinux.org/yay.git /tmp/yay
fi

cd /tmp/yay
makepkg -si --noconfirm

echo "Installed: yay"
