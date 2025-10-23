#!/bin/bash
# Copyright 2025 PhonePe Limited
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

set -e

# Color codes for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Global constants
export WORKSPACE_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
export TEMP_DIR="${WORKSPACE_DIR}/.indus-temp"
export KEYSTORE_FILE_PATH="${WORKSPACE_DIR}/signing-keystore.jks"

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_debug() {
    if [[ "${ACTIONS_STEP_DEBUG:-false}" == "true" || "${INPUT_VERBOSE:-false}" == "true" ]]; then
        echo -e "${PURPLE} DEBUG: $1${NC}"
    fi
}

log_section() {
    echo -e "\n${CYAN}🔹 $1${NC}"
    printf '=%.0s' {1..50}
    echo
}

setup_temp_dir() {
    log_debug "Setting up temporary directory: $TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    chmod 700 "$TEMP_DIR"
}

cleanup_temp_dir() {
    if [[ -d "$TEMP_DIR" ]]; then
        log_debug "Cleaning up temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

validate_env_var() {
    local var_name="$1"
    local var_value="${!var_name}"
    local required="${2:-true}"
    
    if [[ "$required" == "true" && -z "$var_value" ]]; then
        log_error "Required environment variable $var_name is not set"
        return 1
    fi
    
    log_debug "Environment variable $var_name is set"
    return 0
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

retry_command() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    local command=("$@")
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Attempt $attempt/$max_attempts: ${command[*]}"
        
        if "${command[@]}"; then
            log_debug "Command succeeded on attempt $attempt"
            return 0
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Command failed after $max_attempts attempts"
            return 1
        fi
        
        log_warning "Command failed, retrying in ${delay}s..."
        sleep "$delay"
        delay=$((delay * 2))  # Exponential backoff
        ((attempt++))
    done
}

secure_copy() {
    local src="$1"
    local dest="$2"
    
    if [[ ! -f "$src" ]]; then
        log_error "Source file does not exist: $src"
        return 1
    fi
    
    cp "$src" "$dest"
    chmod 600 "$dest"
    log_debug "Securely copied $src to $dest"
}

secure_remove() {
    local file="$1"
    
    if [[ -f "$file" ]]; then
        # Overwrite with random data before deletion (on systems that support it)
        if command_exists shred; then
            shred -vfz -n 3 "$file" 2>/dev/null || rm -f "$file"
        else
            rm -f "$file"
        fi
        log_debug "Securely removed $file"
    fi
}

validate_file_path() {
    local path="$1"
    local name="$2"
    
    if [[ -z "$path" ]]; then
        log_error "$name path is empty"
        return 1
    fi
    
    # Check for suspicious patterns
    if [[ "$path" =~ \.\./|\$\{|\$\( ]]; then
        log_error "$name path contains suspicious patterns: $path"
        return 1
    fi
    
    log_debug "File path validation passed for $name: $path"
    return 0
}

validate_url() {
    local url="$1"
    local name="$2"
    
    if [[ -z "$url" ]]; then
        log_error "$name URL is empty"
        return 1
    fi
    
    # Basic URL validation
    if [[ ! "$url" =~ ^https?:// ]]; then
        log_error "$name URL must start with http:// or https://: $url"
        return 1
    fi
    
    log_debug "URL validation passed for $name: $url"
    return 0
}

get_file_size() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "0"
        return 1
    fi
    
    # Cross-platform file size detection
    if command_exists stat; then
        if stat -f%z "$file" 2>/dev/null; then
            return 0  # macOS/BSD
        elif stat -c%s "$file" 2>/dev/null; then
            return 0  # Linux/GNU
        fi
    fi
    
    # Fallback using wc
    wc -c < "$file" 2>/dev/null || echo "0"
}

format_file_size() {
    local bytes="$1"
    
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$((bytes / 1024))KB"
    elif [[ $bytes -lt 1073741824 ]]; then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

# Measure execution time
measure_time() {
    local start_time
    start_time=$(date +%s)
    "$@"
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_debug "Operation completed in ${duration}s"
    return 0
}



# Export functions for use in other scripts
export -f log_info log_success log_warning log_error log_debug log_section
export -f setup_temp_dir cleanup_temp_dir validate_env_var command_exists
export -f retry_command secure_copy secure_remove validate_file_path validate_url
export -f get_file_size format_file_size measure_time
