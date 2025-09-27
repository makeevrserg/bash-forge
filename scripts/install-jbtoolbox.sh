#!/bin/bash
set -e

cd /tmp

# Download JetBrains Toolbox
wget -O jetbrains-toolbox.tar.gz "https://download-cdn.jetbrains.com/toolbox/jetbrains-toolbox-2.9.0.56191.tar.gz"

# Extract
tar -xvzf jetbrains-toolbox.tar.gz

# Enter extracted dir and launch
cd jetbrains-toolbox-* && ./jetbrains-toolbox &
