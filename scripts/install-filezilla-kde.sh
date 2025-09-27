#!/bin/bash
set -e

# Temp download location
cd /tmp

# Download specific FileZilla version (update version here if needed)
wget -O filezilla.tar.xz "https://dl2.cdn.filezilla-project.org/client/FileZilla_3.69.3_x86_64-linux-gnu.tar.xz?h=MVbEbbuGn9AF1JKPPO9QOA&x=1759008853"

# Extract
tar -xf filezilla.tar.xz

# Install to /opt
sudo rm -rf /opt/filezilla
sudo mv FileZilla3 /opt/filezilla

# Symlink binary
sudo ln -sf /opt/filezilla/bin/filezilla /usr/bin/filezilla

# Install desktop entry
sudo tee /usr/share/applications/filezilla.desktop > /dev/null <<EOF
[Desktop Entry]
Name=FileZilla
Comment=FTP, FTPS and SFTP client
Exec=/usr/bin/filezilla
Icon=/opt/filezilla/share/icons/hicolor/480x480/apps/filezilla.png
Terminal=false
Type=Application
Categories=Network;FileTransfer;
EOF

# Update desktop database
sudo update-desktop-database /usr/share/applications

echo "FileZilla installed."
