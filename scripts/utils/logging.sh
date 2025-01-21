#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging levels
declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)
CURRENT_LOG_LEVEL=${LOG_LEVELS[INFO]}

log() {
    local level=$1
    local message=$2
    local log_file
    
    log_file=$(yq '.system.log_file' config/settings.yaml)
    
    if [[ ${LOG_LEVELS[$level]} -ge $CURRENT_LOG_LEVEL ]]; then
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        case $level in
            "DEBUG") local color="$NC";;
            "INFO") local color="$GREEN";;
            "WARN") local color="$YELLOW";;
            "ERROR") local color="$RED";;
        esac
        
        # Console output
        echo -e "${color}[${timestamp}] ${level}: ${message}${NC}"
        
        # File output (without colors)
        echo "[${timestamp}] ${level}: ${message}" >> "$log_file"
    fi
}

log_debug() { log "DEBUG" "$1"; }
log_info() { log "INFO" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }

# Initialize log file
init_logging() {
    local log_file
    log_file=$(yq '.system.log_file' config/settings.yaml)
    mkdir -p "$(dirname "$log_file")"
    touch "$log_file"
    log_info "Logging initialized"
}
