#!/usr/bin/env bats

load ../helper

setup() {
    setup_test_env
    load_lib "common"
    load_lib "validation"
}

teardown() {
    teardown_test_env
}

@test "validate_operation_mode accepts 'deploy_only'" {
    export INPUT_OPERATION_MODE="deploy_only"
    run validate_operation_mode
    [ "$status" -eq 0 ]
}

@test "validate_operation_mode rejects invalid mode" {
    export INPUT_OPERATION_MODE="invalid_mode"
    run validate_operation_mode
    [ "$status" -eq 1 ]
}

@test "validate_file_type accepts 'apk'" {
    export INPUT_FILE_TYPE="apk"
    run validate_file_type
    [ "$status" -eq 0 ]
}

@test "validate_file_type accepts 'aab'" {
    export INPUT_FILE_TYPE="aab"
    export INPUT_KEYSTORE_SOURCE="base64"
    run validate_file_type
    [ "$status" -eq 0 ]
}

@test "validate_file_type rejects 'aab' without keystore" {
    export INPUT_FILE_TYPE="aab"
    export INPUT_KEYSTORE_SOURCE="none"
    run validate_file_type
    [ "$status" -eq 1 ]
}

@test "validate_api_token accepts valid token" {
    export INPUT_API_TOKEN="12345678901234567890"
    run validate_api_token
    [ "$status" -eq 0 ]
}

@test "validate_api_token rejects short token" {
    export INPUT_API_TOKEN="short"
    run validate_api_token
    [ "$status" -eq 1 ]
}

@test "validate_package_info with valid package name" {
    export INPUT_PACKAGE_NAME="com.example.app"
    export INPUT_AUTO_DETECT_PACKAGE="false"
    run validate_package_info
    [ "$status" -eq 0 ]
}

@test "validate_package_info with invalid package name" {
    export INPUT_PACKAGE_NAME="invalid"
    export INPUT_AUTO_DETECT_PACKAGE="false"
    run validate_package_info
    [ "$status" -eq 1 ]
}

@test "validate_package_info with auto-detect enabled" {
    export INPUT_AUTO_DETECT_PACKAGE="true"
    run validate_package_info
    [ "$status" -eq 0 ]
}
