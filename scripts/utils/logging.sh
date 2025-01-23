#!/bin/bash

# ANSI color codes
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export GRAY='\033[0;37m'
export NC='\033[0m'
export BOLD='\033[1m'

# Logging levels
declare -A LOG_LEVELS
LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
    [FATAL]=4
)

# Default log level
CURRENT_LOG_LEVEL=${LOG_LEVELS[INFO]}
LOG_FILE=""

# Check if 'yq' is installed
if ! command -v yq &> /dev/null; then
    echo -e "${RED}Error: 'yq' is required but not installed. Please install it and try again.${NC}"
    exit 1
fi

init_logging() {
    local settings_file="config/settings.yaml"
    if [[ ! -f "$settings_file" ]]; then
        echo -e "${RED}Error: Settings file not found at $settings_file${NC}"
        exit 1
    fi

    LOG_FILE=$(yq '.system.log_file' "$settings_file" 2>/dev/null)
    if [[ -z "$LOG_FILE" ]]; then
        echo -e "${RED}Error: Failed to read log file path from settings file.${NC}"
        exit 1
    fi

    # Read log level with a default of "INFO"
    local log_level
    log_level=$(yq '.system.log_level' "$settings_file" 2>/dev/null)
    
    # Validate log level
    if [[ -z "$log_level" ]] || [[ ! "${!LOG_LEVELS[@]}" =~ $log_level ]]; then
        log_level="INFO"
        echo -e "${YELLOW}Warning: Invalid or missing log level in settings file. Defaulting to INFO.${NC}"
    fi

    CURRENT_LOG_LEVEL=${LOG_LEVELS[$log_level]}

    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    if ! sudo mkdir -p "$log_dir"; then
        echo -e "${RED}Error: Failed to create log directory '$log_dir'.${NC}"
        exit 1
    fi

    if ! sudo chmod 755 "$log_dir"; then
        echo -e "${RED}Error: Failed to set permissions for log directory '$log_dir'.${NC}"
        exit 1
    fi

    if ! sudo touch "$LOG_FILE"; then
        echo -e "${RED}Error: Failed to create log file '$LOG_FILE'.${NC}"
        exit 1
    fi

    if ! sudo chmod 644 "$LOG_FILE"; then
        echo -e "${RED}Error: Failed to set permissions for log file '$LOG_FILE'.${NC}"
        exit 1
    fi

    # Now that everything is set up, we can use the logging functions
    log_info "Logging initialized - Level: $log_level, File: $LOG_FILE"
}

log() {
    local level=$1
    local message=$2
    
    if [[ ${LOG_LEVELS[$level]} -ge $CURRENT_LOG_LEVEL ]]; then
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local script_name
        script_name=$(basename "${BASH_SOURCE[2]:-${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}}")
        local line_number=${BASH_LINENO[0]:-"?"}
        local function_name="${FUNCNAME[1]:-main}"
        
        local color
        case $level in
            "DEBUG") color="$GRAY" ;;
            "INFO") color="$GREEN" ;;
            "WARN") color="$YELLOW" ;;
            "ERROR") color="$RED" ;;
            "FATAL") color="$RED$BOLD" ;;
            *) color="$NC" ;;
        esac

        local text_entry="[$timestamp] $level [$script_name:$function_name:$line_number]: $message"
        
        echo -e "${color}${text_entry}${NC}"
        if [[ -n "$LOG_FILE" ]]; then
            echo "$text_entry" | sudo tee -a "$LOG_FILE" >/dev/null
        fi
    fi
}

log_debug() { log "DEBUG" "$1"; }
log_info() { log "INFO" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }
log_fatal() { log "FATAL" "$1"; }

set_log_level() {
    local new_level=$1
    if [[ -n "${LOG_LEVELS[$new_level]}" ]]; then
        local old_level
        for level in "${!LOG_LEVELS[@]}"; do
            if [[ ${LOG_LEVELS[$level]} -eq $CURRENT_LOG_LEVEL ]]; then
                old_level=$level
                break
            fi
        done
        CURRENT_LOG_LEVEL=${LOG_LEVELS[$new_level]}
        log_info "Log level changed from $old_level to $new_level"
    else
        log_error "Invalid log level: $new_level"
    fi
}

get_log_file() {
    echo "${LOG_FILE}"
}
