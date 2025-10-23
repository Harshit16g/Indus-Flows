#!/bin/bash
# Copyright 2025 PhonePe Limited
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# Enhanced upload with array-based execution to prevent command injection
upload_to_api() {
    log_section "Uploading to Indus Appstore"
    
    # Build curl command as array to prevent command injection
    local curl_cmd=(
        curl
        -X POST
        -H "Authorization: O-Bearer $INPUT_API_TOKEN"
        -H "Content-Type: multipart/form-data"
        -F "file=@$UPLOAD_FILE_PATH"
        -F "releaseNotes=$INPUT_RELEASE_NOTES"
        -w "%{http_code}"
        -o response.txt
    )
    
    # Add keystore files for AAB if needed
    if [[ "$INPUT_FILE_TYPE" == "aab" && -n "$INPUT_KEYSTORE_SOURCE" && "$INPUT_KEYSTORE_SOURCE" != "none" && -f "$KEYSTORE_FILE_PATH" ]]; then
        log_info "Including keystore for AAB upload..."
        curl_cmd+=(
            -F "file=@$KEYSTORE_FILE_PATH"
            -F "keystorePassword=$INPUT_KEYSTORE_PASSWORD"
            -F "keystoreAlias=$INPUT_KEY_ALIAS"
            -F "keyPassword=$INPUT_KEY_PASSWORD"
        )
    fi
    
    # Add API URL
    curl_cmd+=("$API_URL")
    
    # Execute upload
    log_info "Uploading $INPUT_FILE_TYPE to $API_URL..."
    local http_status
    http_status=$("${curl_cmd[@]}" 2>&1 | tail -n1)
    
    # Check status code
    if [[ $http_status -ge 200 && $http_status -lt 300 ]]; then
        log_success "Successfully uploaded $INPUT_FILE_TYPE to Indus Appstore!"
        return 0
    else
        log_error "Failed to upload $INPUT_FILE_TYPE. HTTP status: $http_status"
        if [[ -f response.txt ]]; then
            log_debug "Response: $(cat response.txt)"
        fi
        return 1
    fi
}

# Cleanup function
cleanup_response() {
    # shellcheck disable=SC2317  # This function is called via trap
    secure_remove "response.txt"
}

trap cleanup_response EXIT

# Main execution
if upload_to_api; then
    exit 0
else
    exit 1
fi