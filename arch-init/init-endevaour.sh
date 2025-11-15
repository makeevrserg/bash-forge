is_pacman_package_installed() {
    local package="$1"
    if pacman -Qs "$package" > /dev/null; then
        echo "Package $package is installed"
        return 0
    else
        echo "Package $package is not installed"
        return 1
    fi
}

install_pacman_package() {
    local package="$1"
    sudo pacman -Syy --noconfirm "$package"
}

try_install_pacman_package() {
    local package="$1"
    if ! is_pacman_package_installed $package; then
        install_pacman_package $package
    fi
}

install_aur_package() {
    local package="$1"
    echo "Installing $package from AUR..."
    yay -S --noconfirm "$package"
}


try_install_aur_package() {
    local package="$1"
    if ! is_pacman_package_installed "$package"; then
        install_aur_package "$package"
    fi
}

try_install_docker() {
    if ! is_pacman_package_installed "docker"; then
        install_pacman_package "docker"
        sudo systemctl enable docker.service
        sudo systemctl start docker.service
        if ! getent group docker >/dev/null; then
            sudo groupadd docker
        fi
        sudo usermod -aG docker $USER
        newgrp docker
    fi
    try_install_pacman_package "docker-compose"
}

# https://github.com/amnezia-vpn/amnezia-client/issues/792
fix_dns_vnp() {
    echo "[main]
    dns=none" | sudo tee /etc/NetworkManager/NetworkManager.conf > /dev/null

    echo "nameserver 1.1.1.1
    nameserver 1.0.0.1" | sudo tee /etc/resolv.conf > /dev/null

    sudo systemctl enable systemd-resolved.service && sudo systemctl start systemd-resolved.service
    sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
}

assert_amnezia_launched() {
    if ! pgrep -x "AmneziaVPN" > /dev/null; then
        echo "To continue, launch VPN"
        exit 1
    fi
}

try_install_docker

try_install_pacman_package "gtk2"
try_install_pacman_package "libxcrypt-compat"
try_install_pacman_package "telegram-desktop"
try_install_pacman_package "vscode"
try_install_pacman_package "pigz"
try_install_pacman_package "cpupower"
try_install_pacman_package "thermald"
try_install_pacman_package "wget"
try_install_pacman_package "btop"
try_install_pacman_package "zram-generator"
try_install_aur_package "termius"
try_install_aur_package "slack-desktop"

fix_dns_vnp

assert_amnezia_launched

bash init-zram.sh
bash install-discord.sh --ignore-if-installed
bash install-filezilla.sh --ignore-if-installed
bash install-hmcl.sh --ignore-if-installed
bash install-obsidian.sh --ignore-if-installed
bash install-jbtoolbox.sh --ignore-if-installed
