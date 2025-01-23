#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging first to get colors
source scripts/utils/logging.sh

# Trap errors
trap 'error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

error_handler() {
    local exit_code=$1
    local line_no=$2
    local bash_lineno=$3
    local last_command=$4
    local func_stack=$5
    echo -e "${RED}Error occurred in install script${NC}"
    echo "Exit code: $exit_code"
    echo "Line number: $line_no"
    echo "Command: $last_command"
    echo "Function stack:$func_stack"
    exit "$exit_code"
}

check_dependencies() {
    local deps=(git base-devel go-yq github-cli)
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    if ((${#missing_deps[@]} > 0)); then
        echo -e "${GREEN}Installing missing dependencies: ${missing_deps[*]}${NC}"
        sudo pacman -Sy --needed --noconfirm "${missing_deps[@]}"
    fi
}
setup_repository() {
    # Check if we're running from the cloned repository
    if [[ ! -f "${SCRIPT_DIR}/scripts/utils/logging.sh" ]]; then
        echo -e "${GREEN}Setting up installation environment...${NC}"
        
        check_dependencies

        echo -e "${GREEN}Checking GitHub authentication status...${NC}"
        if ! gh auth status &>/dev/null; then
            echo -e "${GREEN}Authenticating with GitHub...${NC}"
            gh auth login
        else
            echo -e "${GREEN}Already authenticated with GitHub${NC}"
        fi

        echo -e "${GREEN}Cloning setup repository...${NC}"
        git clone https://github.com/luizhcrocha/arch-setup.git
        cd arch-setup || exit 1

        echo -e "${GREEN}Making scripts executable...${NC}"
        chmod +x install.sh scripts/utils/*.sh

        echo -e "${GREEN}Restarting installation from cloned repository...${NC}"
        exec ./install.sh
        exit 0
    fi
}

verify_environment() {
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}Error: This script should not be run as root${NC}"
        exit 1
    fi

    # Verify required directories exist
    local required_dirs=(
        "scripts/utils"
        "config"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            echo -e "${RED}Error: Required directory '$dir' not found${NC}"
            exit 1
        fi
    done

    # Verify required files exist
    local required_files=(
        "scripts/utils/logging.sh"
        "scripts/utils/package.sh"
        "config/packages.yaml"
        "config/settings.yaml"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo -e "${RED}Error: Required file '$file' not found${NC}"
            exit 1
        fi
    done
}

setup_keyrings() {
    echo -e "${GREEN}Setting up keyrings...${NC}"
    sudo mkdir -p /usr/share/keyrings
    curl -sS https://keys.openpgp.org/vks/v1/by-fingerprint/F4FDB18A9937358364B276E9E25D679AF73C6D2F | gpg --import -
}

process_post_install() {
    echo -e "${GREEN}Processing post-installation actions...${NC}"
    local packages
    
    # Get all packages with post-install actions
    log_info "Reading post-install actions from config"
    mapfile -t packages < <(yq -r '.post_install_actions | keys | .[]' config/packages.yaml)
    
    log_info "Found ${#packages[@]} packages with post-install actions"
    
    # Debug: Print all packages found
    echo "Packages to process:"
    printf '%s\n' "${packages[@]}"
    
    for package in "${packages[@]}"; do
        if [[ -n $package ]]; then
            log_info "Starting post-install actions for package: $package"
            echo -e "${GREEN}Running post-install actions for $package${NC}"
            run_post_install_actions "$package"
            log_info "Completed post-install actions for package: $package"
        fi
    done
    
    log_info "All post-installation actions completed"
    
    # Debug: Print confirmation we reached the end
    echo "Post-installation processing completed"
}
install_dotfiles() {
    echo -e "${GREEN}Installing dotfiles...${NC}"
    if curl -sSf https://raw.githubusercontent.com/mylinuxforwork/dotfiles/main/setup-arch.sh > /tmp/setup-dotfiles.sh; then
        bash /tmp/setup-dotfiles.sh
        rm /tmp/setup-dotfiles.sh
    else
        echo -e "${YELLOW}Warning: Failed to download dotfiles setup script${NC}"
    fi
}

main() {
    echo -e "${GREEN}Starting Arch Linux setup...${NC}"
    
    echo "Step 1: Setup repository"
    setup_repository
    verify_environment

    echo "Step 2: Source scripts and init logging"
    source scripts/utils/logging.sh
    source scripts/utils/package.sh
    init_logging
    log_info "Starting installation process"

    echo "Step 3: Setup keyrings"
    setup_keyrings
    
    echo "Step 4: Install AUR helper"
    install_aur_helper

    echo "Step 5: Install pacman packages"
    log_info "Installing pacman packages"
    install_packages "pacman"

    echo "Step 6: Install AUR packages"
    log_info "Installing AUR packages"
    install_packages "aur"

    echo "Step 7: Process post-installation actions"
    log_info "Starting post-installation actions"
    process_post_install
    log_info "Completed post-installation actions"

    echo "Step 8: Install dotfiles"
    log_info "Starting dotfiles installation"
    install_dotfiles
    log_info "Completed dotfiles installation"

    log_info "Installation completed successfully!"
    echo -e "${GREEN}Installation completed successfully!${NC}"
    echo -e "${YELLOW}Note: You may need to log out and back in for some changes to take effect.${NC}"
}

# Run main function
main "$@"
