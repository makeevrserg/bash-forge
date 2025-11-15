#!/bin/bash
set -e

DISPLAY_NAME="FileZilla"
DOWNLOAD_URL="https://filezilla-project.org/nightlies/2025-11-15/x86_64-linux-gnu/FileZilla3.tar.xz"
ICON_SUBPATH="FileZilla3/share/icons/hicolor/480x480/apps/filezilla.png"
CATEGORIES="Network;FileTransfer;"
EXEC_SUBPATH="FileZilla3/bin/filezilla"
APP_NAME=$(echo "$DISPLAY_NAME" | tr 'A-Z' 'a-z' | tr -d ' ')

# Temp download location
cd /tmp

# Download latest Discord tar.gz
echo "Downloading..."
ARCHIVE="$APP_NAME.tar"
wget -O "$ARCHIVE" "$DOWNLOAD_URL"

# Extract
echo "Extracting..."
EXTRACTED_APP_FOLDER=extracted_app_$APP_NAME
rm -rf $EXTRACTED_APP_FOLDER
mkdir $EXTRACTED_APP_FOLDER
tar -xf "$ARCHIVE" -C $EXTRACTED_APP_FOLDER

# Install to /opt

INSTALL_DIR="/opt/$APP_NAME"

echo "Installing to $INSTALL_DIR..."
sudo rm -rf "$INSTALL_DIR"
EXTRACTED_DIR=$EXTRACTED_APP_FOLDER
sudo mv "$EXTRACTED_DIR" "$INSTALL_DIR"

echo "Creating symlink..."
sudo rm -rf "/usr/bin/$APP_NAME"
sudo ln -sf "$INSTALL_DIR/$EXEC_SUBPATH" "/usr/bin/$APP_NAME"

# Install desktop entry
echo "Creating desktop entry..."
sudo tee "/usr/share/applications/${APP_NAME}.desktop" > /dev/null <<EOF
[Desktop Entry]
Name=$DISPLAY_NAME
Comment=$DISPLAY_NAME Application
Exec=/usr/bin/$APP_NAME
Icon=$INSTALL_DIR/$ICON_SUBPATH
Terminal=false
Type=Application
Categories=$CATEGORIES
EOF

sudo update-desktop-database /usr/share/applications

echo "$DISPLAY_NAME installed."