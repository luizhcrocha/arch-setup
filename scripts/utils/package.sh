#!/bin/bash

source scripts/utils/logging.sh

install_aur_helper() {
    if ! command -v paru &>/dev/null; then
        log_info "Installing paru AUR helper..."

        local temp_dir
        temp_dir=$(yq '.system.temp_dir' config/settings.yaml)
        mkdir -p "$temp_dir"
        cd "$temp_dir" || exit 1

        git clone https://aur.archlinux.org/paru-bin.git
        cd paru-bin || exit 1
        makepkg -si --noconfirm

        if command -v paru &>/dev/null; then
            log_info "paru installed successfully"
        else
            log_error "Failed to install paru"
            exit 1
        fi
    else
        log_info "paru is already installed"
    fi
}

install_packages() {
    local package_type=$1
    local packages

    # Read packages from YAML
    if [[ $package_type == "pacman" ]]; then
        packages=$(yq '.base_packages.pacman[]' config/packages.yaml | tr -d '"')
        echo $packages
        log_info "Installing pacman packages..."
        sudo pacman -Sy --needed --noconfirm $packages
    elif [[ $package_type == "aur" ]]; then
        packages=$(yq '.base_packages.aur[]' config/packages.yaml | tr -d '"')
        log_info "Installing AUR packages..."
        paru -Sy --needed --noconfirm $packages
        bash <(curl -s https://raw.githubusercontent.com/mylinuxforwork/dotfiles/main/setup-arch.sh)
    fi
}

run_post_install_actions() {
    local package=$1
    local actions

    log_info "Running post-install actions for $package..."

    # Get all commands for the package
    actions=$(yq ".post_install_actions.$package[].command" config/packages.yaml)

    while IFS= read -r command; do
        if [[ -n $command ]]; then
            log_debug "Executing: $command"

            # Check if command is interactive
            if yq ".post_install_actions.$package[].interactive" config/packages.yaml | grep -q "true"; then
                log_info "This command requires user interaction:"
                echo "$command"
            else
                eval "$command"
                if [[ $? -eq 0 ]]; then
                    log_info "Command executed successfully"
                else
                    log_error "Command failed: $command"
                    if [[ $(yq '.install.ignore_errors' config/settings.yaml) != "true" ]]; then
                        exit 1
                    fi
                fi
            fi
        fi
    done <<<"$actions"
}
