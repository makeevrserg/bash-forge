#!/usr/bin/env bash

IGNORE=false

check_ignore_if_installed() {
    local APP_PATH="$1"
    shift
    local ARGS=("$@")

    if $IGNORE && [[ -f "$APP_PATH" ]]; then
        echo "Skipping: $(basename "$APP_PATH") is already installed."
        return 1
    else
        echo "Warning: $(basename "$APP_PATH") is not installed."
    fi

    return 0
}

is_jbtoolbox_installed() {
    shift
    local ARGS=("$@")


    if [[ -d "$HOME/.local/share/JetBrains/Toolbox" ]]; then
        echo "Skipping: JBToolbox is already installed."
        return 1
    else
        echo "Warning: JBToolbox  is not installed."
    fi    
    return 0
}

# Populate global IGNORE variable
ARGS=("$@")
for arg in "${ARGS[@]}"; do
    if [[ "$arg" == "--ignore-if-installed" ]]; then
        IGNORE=true
    fi
done
