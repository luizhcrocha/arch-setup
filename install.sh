#!/bin/bash

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Detect if script is being run via curl
if [[ ! -f "scripts/utils/logging.sh" ]]; then
    echo -e "${GREEN}Installing dependencies...${NC}"
    sudo pacman -Sy --needed --noconfirm git base-devel yq github-cli

    echo -e "${GREEN}Authenticating with GitHub...${NC}"
    gh auth login

    echo -e "${GREEN}Cloning setup repository...${NC}"
    git clone https://github.com/luizhcrocha/arch-setup.git
    cd arch-setup

    echo -e "${GREEN}Making scripts executable...${NC}"
    chmod +x install.sh scripts/utils/*.sh

    echo -e "${GREEN}Restarting installation from cloned repository...${NC}"
    exec ./install.sh
    exit 0
fi

# Source utility scripts
source scripts/utils/logging.sh
source scripts/utils/package.sh

# Initialize logging
init_logging

main() {
    log_info "Starting Arch Linux setup..."

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi

    # Install AUR helper
    install_aur_helper

    # Install pacman packages
    log_info "Installing pacman packages..."
    install_packages "pacman"

    # Install AUR packages
    log_info "Installing AUR packages..."
    install_packages "aur"

    # Run post-installation actions
    log_info "Running post-installation actions..."

    # Get all packages with post-install actions
    packages=$(yq '.post_install_actions | keys | .[]' config/packages.yaml)

    while IFS= read -r package; do
        if [[ -n $package ]]; then
            log_info "Processing post-install actions for $package"
            run_post_install_actions "$package"
        fi
    done <<<"$packages"

    log_info "Installation completed successfully!"
}

# Run main function
main "$@"
