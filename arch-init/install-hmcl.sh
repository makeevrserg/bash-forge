#!/bin/bash
set -e

DISPLAY_NAME="HMCL"
DOWNLOAD_URL="https://github.com/HMCL-dev/HMCL/releases/download/v3.7.5/HMCL-3.7.5.jar"
CATEGORIES="Game;"
APP_NAME=$(echo "$DISPLAY_NAME" | tr 'A-Z' 'a-z' | tr -d ' ')
ICON_PATH="$(pwd)/icons/ic_hmcl.png"

source ./util.sh
check_ignore_if_installed "/usr/bin/$APP_NAME" "$@" || exit 0

# Temp download location
cd /tmp

echo "Downloading HMCL..."
ARCHIVE="$APP_NAME.jar"
wget -O "$ARCHIVE" "$DOWNLOAD_URL"

# Install to /opt
INSTALL_DIR="/opt/$APP_NAME"

echo "Installing to $INSTALL_DIR..."
sudo rm -rf "$INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"

echo "Moving .jar file..."
sudo mv "$ARCHIVE" "$INSTALL_DIR/$APP_NAME.jar"

# Install icon
echo "Installing icon..."
sudo mkdir -p "$INSTALL_DIR/icons"
sudo cp "$ICON_PATH" "$INSTALL_DIR/icons/icon.png"

# Create launcher script for running java -jar
echo "Creating executable wrapper..."
sudo tee "/usr/bin/$APP_NAME" > /dev/null <<EOF
#!/bin/bash
exec java -Dhmcl.offline.auth.restricted=false -jar "$INSTALL_DIR/$APP_NAME.jar" "\$@"
EOF

sudo chmod +x "/usr/bin/$APP_NAME"

# Desktop entry
echo "Creating desktop entry..."
sudo tee "/usr/share/applications/${APP_NAME}.desktop" > /dev/null <<EOF
[Desktop Entry]
Name=$DISPLAY_NAME
Comment=$DISPLAY_NAME Launcher
Exec=/usr/bin/$APP_NAME
Icon=$INSTALL_DIR/icons/icon.png
Terminal=false
Type=Application
Categories=$CATEGORIES
EOF

sudo update-desktop-database /usr/share/applications

echo "$DISPLAY_NAME installed successfully."
