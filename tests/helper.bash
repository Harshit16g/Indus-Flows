#!/bin/bash
# Test helper functions

# Load the library to test
load_lib() {
    local lib="$1"
    source "$BATS_TEST_DIRNAME/../scripts/utils/${lib}.sh"
}

# Mock external commands
mock_command() {
    local cmd="$1"
    local output="$2"
    
    eval "$cmd() { echo '$output'; }"
}

# Setup test environment
setup_test_env() {
    export GITHUB_WORKSPACE="$BATS_TEST_DIRNAME/fixtures"
    export TEMP_DIR="$BATS_TEST_DIRNAME/tmp"
    mkdir -p "$TEMP_DIR"
}

# Cleanup test environment
teardown_test_env() {
    rm -rf "$BATS_TEST_DIRNAME/tmp"
}
