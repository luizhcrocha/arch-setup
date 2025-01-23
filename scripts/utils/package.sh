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
	local packages=()

	log_info "Reading packages for type: $package_type"

	if [[ $package_type == "pacman" ]]; then
		# Read pacman packages
		while IFS= read -r pkg; do
			if [[ -n "$pkg" ]]; then
				pkg=$(echo "$pkg" | tr -d '"' | tr -d "'")
				log_debug "Adding package: $pkg"
				packages+=("$pkg")
			fi
		done < <(yq -r ".base_packages.pacman[]" config/packages.yaml)

		if [[ ${#packages[@]} -eq 0 ]]; then
			log_warn "No pacman packages found"
			return
		fi

		log_info "Installing ${#packages[@]} pacman packages..."
		log_debug "Packages to install: ${packages[*]}"
		sudo pacman -Sy --needed --noconfirm "${packages[@]}"

	elif [[ $package_type == "aur" ]]; then
		local simple_packages=()
		local interactive_packages=()

	# Read simple AUR packages
	while IFS= read -r pkg; do
		if [[ -n "$pkg" ]] && [[ "$pkg" != "null" ]]; then
			pkg=$(echo "$pkg" | tr -d '"' | tr -d "'")
			log_debug "Adding simple package: $pkg"
			simple_packages+=("$pkg")
		fi
	done < <(yq -r ".base_packages.aur.simple[]" config/packages.yaml)

	# Read interactive AUR packages
	while IFS= read -r name; do
		if [[ -n "$name" ]] && [[ "$name" != "null" ]]; then
			name=$(echo "$name" | tr -d '"' | tr -d "'")
			log_debug "Adding interactive package: $name"
			interactive_packages+=("$name")
		fi
	done < <(yq -r ".base_packages.aur.interactive[].name" config/packages.yaml)

	# Install simple packages in batch
	if [[ ${#simple_packages[@]} -gt 0 ]]; then
		log_info "Installing ${#simple_packages[@]} simple AUR packages..."
		log_debug "Simple packages to install: ${simple_packages[*]}"
		paru -S --needed --noconfirm "${simple_packages[@]}"
	fi

	# Install interactive packages one by one
	if [[ ${#interactive_packages[@]} -gt 0 ]]; then
		log_info "Installing ${#interactive_packages[@]} interactive AUR packages..."
		for pkg in "${interactive_packages[@]}"; do
			local desc
			desc=$(yq -r ".base_packages.aur.interactive[] | select(.name == \"$pkg\") | .description" config/packages.yaml)
			log_info "Installing $pkg - $desc"
			if ! paru -S --needed "$pkg"; then
				log_error "Failed to install package: $pkg"
				handle_error
			fi
		done
	fi
	fi
}

handle_curl() {
	local action=$1
	local url pipe_to env_vars

	url=$(yq ".url" <<<"$action")
	pipe_to=$(yq ".pipe_to" <<<"$action")

    # Build environment variables string
    local env_string=""
    while IFS= read -r env; do
	    [[ -z "$env" ]] && continue
	    local key value
	    key=$(yq ".key" <<<"$env")
	    value=$(yq ".value" <<<"$env")
	    env_string+="$key=$value "
    done < <(yq -o=json ".env | to_entries[]" <<<"$action")

    # Execute curl command with proper piping
    if [[ -n "$pipe_to" ]]; then
	    if [[ -n "$env_string" ]]; then
		    eval "$env_string curl -fsSL \"$url\" | $pipe_to"
	    else
		    curl -fsSL "$url" | eval "$pipe_to"
	    fi
    else
	    if [[ -n "$env_string" ]]; then
		    eval "$env_string curl -fsSL \"$url\""
	    else
		    curl -fsSL "$url"
	    fi
    fi
}

handle_command() {
    local action=$1
    local cmd args_array=()

    cmd=$(yq -r ".cmd" <<<"$action")

    # Build args array and expand environment variables
    while IFS= read -r arg; do
        [[ -z "$arg" ]] && continue
        # Expand environment variables in the argument
        arg=$(eval echo "$arg")
        args_array+=("$arg")
    done < <(yq -r ".args[]" <<<"$action")

    # Execute command with args
    log_info "Executing command: $cmd ${args_array[*]}"
    "$cmd" "${args_array[@]}"
}

handle_git_config() {
    local action=$1

    # Extract settings directly from the action
    while IFS= read -r setting; do
        [[ -z "$setting" ]] && continue

        # Extract key and value using yq
        local key value
        key=$(yq -r '.key' <<<"$setting")
        value=$(yq -r '.value // ""' <<<"$setting")

        log_info "Setting: $setting"
        log_info "Key: $key / Value: $value"

        # Skip if key is empty or null
        [[ -z "$key" || "$key" == "null" ]] && continue

        # Set Git config (preserve newlines)
        git config --global "$key" "$value"
        log_info "Set git config: $key = $value"
    done < <(yq -o=json '.settings[]' <<<"$action" | jq -c .)
}

handle_symlinks() {
    local action=$1
    log_info "Creating symlinks..."

    # Get the number of links
    local link_count
    link_count=$(yq -r ".[\"post_install_actions\"][\"$package\"][$i].links | length" config/packages.yaml)

    for ((j=0; j<link_count; j++)); do
        local source target sudo_required
        source=$(yq -r ".[\"post_install_actions\"][\"$package\"][$i].links[$j].source" config/packages.yaml)
        target=$(yq -r ".[\"post_install_actions\"][\"$package\"][$i].links[$j].target" config/packages.yaml)
        sudo_required=$(yq -r ".[\"post_install_actions\"][\"$package\"][$i].links[$j].sudo" config/packages.yaml)

        if [[ "$source" == "null" || "$target" == "null" ]]; then
            log_error "Invalid symlink configuration"
            continue
        fi

        # Check if the symlink already exists and points to the correct target
        if [[ -L "$target" ]] && [[ "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
            log_info "Symlink $target already exists and points to $source, skipping."
            continue
        fi

        # Create parent directory if it doesn't exist
        if [[ "$sudo_required" == "true" ]]; then
            sudo mkdir -p "$(dirname "$target")"
        else
            mkdir -p "$(dirname "$target")"
        fi

        # Create the symlink
        if [[ "$sudo_required" == "true" ]]; then
            log_info "Creating symlink with sudo: $source -> $target"
            if ! sudo ln -sf "$source" "$target"; then
                log_error "Failed to create symlink: $source -> $target"
                handle_error
            fi
        else
            log_info "Creating symlink: $source -> $target"
            if ! ln -sf "$source" "$target"; then
                log_error "Failed to create symlink: $source -> $target"
                handle_error
            fi
        fi
        
        log_info "Created symlink: $source -> $target"
    done
}

handle_systemd() {
    local action=$1

    # Convert YAML action to JSON for reliable parsing
    local action_json
    action_json=$(echo "$action" | yq -o=json)

    # Extract service actions
    local service_actions
    service_actions=$(echo "$action_json" | jq -c '.actions[]')

    # Process each service action
    while IFS= read -r service_action; do
        [[ -z "$service_action" ]] && continue

        # Extract service name and operations
        local service operations
        service=$(echo "$service_action" | jq -r '.service')
        operations=$(echo "$service_action" | jq -r '.operations[]')

        [[ -z "$service" || "$service" == "null" ]] && continue

        # Process operations
        while IFS= read -r operation; do
            [[ -z "$operation" || "$operation" == "null" ]] && continue

            # Check service status
            if [[ "$operation" == "enable" && $(systemctl is-enabled "$service" 2>/dev/null) == "enabled" ]]; then
                log_info "Service $service already enabled, skipping."
                continue
            elif [[ "$operation" == "start" && $(systemctl is-active "$service" 2>/dev/null) == "active" ]]; then
                log_info "Service $service already running, skipping."
                continue
            fi

            # Execute the operation
            log_info "Executing systemctl $operation $service"
            sudo systemctl "$operation" "$service" || handle_error
        done <<<"$operations"
    done <<<"$service_actions"
}

handle_directories() {
    local action=$1

    while IFS= read -r path_entry; do
        [[ -z "$path_entry" ]] && continue
        local path mode
        path=$(yq -r ".path" <<<"$path_entry")
        mode=$(yq -r ".mode" <<<"$path_entry")

        if [[ -n "$path" && "$path" != "null" ]]; then
            path="${path/#\~/$HOME}"

            log_info "Creating directory: $path"
            if ! mkdir -p "$path"; then
                log_error "Failed to create directory: $path"
                handle_error
            fi

            if [[ -n "$mode" && "$mode" != "null" ]]; then
                log_info "Setting mode $mode for: $path"
                if ! chmod "$mode" "$path"; then
                    log_error "Failed to set mode for: $path"
                    handle_error
                fi
            fi
        fi
    done < <(yq -r '.paths[]' <<<"$action")
}
handle_gpg_import() {
    local action=$1
    local url
    # Use -r flag with yq to get raw output without quotes
    url=$(yq -r ".url" <<<"$action")
    
    if [[ -n "$url" && "$url" != "null" ]]; then
        log_info "Importing GPG key from: $url"
        if ! curl -fsSL "$url" | gpg --import -; then
            log_error "Failed to import GPG key from $url"
            handle_error
        fi
    else
        log_error "No URL specified for gpg_import action"
        handle_error
    fi
}
handle_package() {
    local name method
    name=$(yq -r ".[\"post_install_actions\"][\"$package\"][$i].name" config/packages.yaml)
    method=$(yq -r ".[\"post_install_actions\"][\"$package\"][$i].method" config/packages.yaml)
    
    if [[ "$name" != "null" && "$method" != "null" ]]; then
        log_info "Installing package $name using $method"
        case "$method" in
            "paru")
                if ! paru -S --needed --noconfirm "$name"; then
                    log_error "Failed to install package $name"
                    handle_error
                fi
                ;;
            *)
                log_error "Unknown installation method: $method"
                handle_error
                ;;
        esac
    else
        log_error "Invalid package action configuration"
        handle_error
    fi
}

run_post_install_actions() {
    local package=$1
    log_info "Running post-install actions for \"$package\"..."

    # Get all actions for the package - quote the package name in the query
    local actions
    actions=$(yq ".[\"post_install_actions\"][\"$package\"]" config/packages.yaml)
    if [[ "$actions" == "null" ]]; then
        log_warn "No post-install actions found for $package"
        return
    fi

    # Count number of actions
    local action_count
    action_count=$(yq ".[\"post_install_actions\"][\"$package\"] | length" config/packages.yaml)

    # Process each action
    for ((i=0; i<action_count; i++)); do
        local action_type
        action_type=$(yq -r ".[\"post_install_actions\"][\"$package\"][$i].type" config/packages.yaml)
        if [[ "$action_type" == "null" ]]; then
            log_error "Invalid action type at index $i"
            continue
        fi

        # Get the full action object
        local action
        action=$(yq ".[\"post_install_actions\"][\"$package\"][$i]" config/packages.yaml)
        log_info "Executing action type: $action_type"
	log_info "Action: $action"

        case "$action_type" in
            "systemd")
                handle_systemd "$action"
                ;;
            "gpg_import")
                handle_gpg_import "$action"
                ;;
            "package")
                handle_package
                ;;
            "symlinks")
                handle_symlinks "$action"
                ;;
            "directories")
                handle_directories "$action"
                ;;
            "curl")
                handle_curl "$action"
                ;;
            "command")
                handle_command "$action"
                ;;
            "git_config")
                handle_git_config "$action"
                ;;
            *)
                log_error "Unknown action type: $action_type"
                handle_error
                ;;
        esac

        local description
        description=$(yq -r ".[\"post_install_actions\"][\"$package\"][$i].description" config/packages.yaml)
        [[ "$description" != "null" ]] && log_info "$description"
    done
}

handle_error() {
	if [[ $(yq -r '.install.ignore_errors' config/settings.yaml) != "true" ]]; then
		exit 1
	fi
	log_warn "Continuing despite error (ignore_errors is true)"
}
