#!/bin/bash
set -e

cd /tmp

VERSION="2.9.0.56191"
# Download JetBrains Toolbox
wget -O jetbrains-toolbox.tar.gz "https://download-cdn.jetbrains.com/toolbox/jetbrains-toolbox-$VERSION.tar.gz"

# Extract
tar -xvzf jetbrains-toolbox.tar.gz

# Enter extracted dir and launch
cd jetbrains-toolbox-$VERSION/bin && ./jetbrains-toolbox &
