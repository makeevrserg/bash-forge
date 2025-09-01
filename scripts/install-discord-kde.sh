#!/bin/bash
set -e

# Temp download location
cd /tmp

# Download latest Discord tar.gz
wget -O discord.tar.gz "https://discord.com/api/download?platform=linux&format=tar.gz"

# Extract
tar -xvzf discord.tar.gz

# Install to /opt
sudo rm -rf /opt/discord
sudo mv Discord /opt/discord

# Symlink binary
sudo ln -sf /opt/discord/Discord /usr/bin/discord

# Install desktop entry
sudo tee /usr/share/applications/discord.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Discord
Comment=Chat for Communities and Friends
Exec=/usr/bin/discord
Icon=/opt/discord/discord.png
Terminal=false
Type=Application
Categories=Network;InstantMessaging;
EOF

# Update desktop database (helps KDE pick it up immediately)
sudo update-desktop-database /usr/share/applications