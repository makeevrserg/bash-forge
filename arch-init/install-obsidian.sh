#!/bin/bash
set -e

DISPLAY_NAME="Obsidian"
DOWNLOAD_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v1.10.3/Obsidian-1.10.3.AppImage"
CATEGORIES="Utility;TextEditor;Office;"
APP_NAME=$(echo "$DISPLAY_NAME" | tr 'A-Z' 'a-z' | tr -d ' ')
ICON_PATH="$(pwd)/icons/ic_obsidian.png"

source ./util.sh
check_ignore_if_installed "/usr/bin/$APP_NAME" "$@" || exit 0

# Temp download location
cd /tmp

echo "Downloading Obsidian AppImage..."
ARCHIVE="$APP_NAME.AppImage"
wget -O "$ARCHIVE" "$DOWNLOAD_URL"

# Install to /opt
INSTALL_DIR="/opt/$APP_NAME"

echo "Installing to $INSTALL_DIR..."
sudo rm -rf "$INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"

echo "Moving AppImage..."
sudo mv "$ARCHIVE" "$INSTALL_DIR/$APP_NAME"
sudo chmod +x "$INSTALL_DIR/$APP_NAME"

# Install icon
echo "Installing icon..."
sudo mkdir -p "$INSTALL_DIR/icons"
sudo cp "$ICON_PATH" "$INSTALL_DIR/icons/icon.png"

# Create symlink
echo "Creating symlink..."
sudo rm -f "/usr/bin/$APP_NAME"
sudo ln -sf "$INSTALL_DIR/$APP_NAME" "/usr/bin/$APP_NAME"

# Desktop entry
echo "Creating desktop entry..."
sudo tee "/usr/share/applications/${APP_NAME}.desktop" > /dev/null <<EOF
[Desktop Entry]
Name=$DISPLAY_NAME
Comment=$DISPLAY_NAME Application
Exec=/usr/bin/$APP_NAME
Icon=$INSTALL_DIR/icons/icon.png
Terminal=false
Type=Application
Categories=$CATEGORIES
EOF

sudo update-desktop-database /usr/share/applications

echo "$DISPLAY_NAME installed successfully."
