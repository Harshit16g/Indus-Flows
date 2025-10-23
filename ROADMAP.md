# 🗺️ Development Roadmap - Indus-Flows

**Repository:** Harshit16g/Indus-Flows  
**Current Status:** B+ (85/100)  
**Target Status:** A+ (95/100)  
**Timeline:** 3 Months  
**Last Updated:** October 23, 2025

---

## 📋 Executive Summary

This roadmap provides a phased approach to address all issues and improvements identified in the comprehensive repository analysis. The plan is organized into **4 sprints** over 3 months, prioritizing critical security fixes and testing infrastructure before moving to enhancements.

**Expected Outcomes:**
- 🔒 All critical security issues resolved
- ✅ 80%+ test coverage
- 📈 Code quality score: A+ (95/100)
- 🚀 Production-ready with confidence

---

## 🎯 Goals by Phase

| Phase | Duration | Focus | Score Improvement |
|-------|----------|-------|-------------------|
| Sprint 1 | Week 1 | Critical Fixes & CI/CD | 85 → 87 (+2) |
| Sprint 2 | Week 2-3 | Testing Infrastructure | 87 → 90 (+3) |
| Sprint 3 | Week 4-5 | Reliability & Features | 90 → 93 (+3) |
| Sprint 4 | Week 6-12 | Polish & Enhancement | 93 → 95 (+2) |

---

## 📅 Sprint 1: Critical Fixes & CI/CD (Week 1)

**Goal:** Address critical security issues and establish automated quality checks  
**Duration:** 5-7 days  
**Effort:** ~12 hours  
**Score Target:** 87/100

### 🔴 Priority 1: Security Fix (Day 1)

#### Task 1.1: Fix Command Injection Vulnerability
**File:** `scripts/core/upload-to-store.sh`  
**Effort:** 1 hour  
**Assignee:** Security-focused developer

**Current Code (Line 14-24):**
```bash
CURL_CMD="curl -X POST -H \"Authorization: O-Bearer...\" ..."
RESPONSE=$(eval ${CURL_CMD})
```

**Fixed Code:**
```bash
#!/bin/bash
# Enhanced upload with array-based execution

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

upload_to_api() {
    log_section "Uploading to Indus Appstore"
    
    # Build curl command as array
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
    secure_remove "response.txt"
}

trap cleanup_response EXIT

# Main execution
if upload_to_api; then
    exit 0
else
    exit 1
fi
```

**Validation:**
- [ ] Test with APK upload
- [ ] Test with AAB upload (with keystore)
- [ ] Test with special characters in release notes
- [ ] Run security scan (CodeQL)

---

#### Task 1.2: Fix ShellCheck Warnings
**Files:** Multiple (see checklist below)  
**Effort:** 3 hours  
**Assignee:** Any developer

**Changes Required:**

1. **Quote GITHUB_ENV variables** (9 occurrences)
```bash
# Before
echo "VAR=$VALUE" >> $GITHUB_ENV

# After
echo "VAR=$VALUE" >> "$GITHUB_ENV"
```

**Files to fix:**
- [ ] `scripts/core/detect-package-name.sh:35`
- [ ] `scripts/core/prepare-upload.sh:17,27,30,34,39`
- [ ] `scripts/core/upload-to-store.sh:24` (already fixed above)

2. **Fix variable declarations** (2 occurrences)
```bash
# Before (scripts/utils/common.sh)
local start_time=$(date +%s)

# After
local start_time
start_time=$(date +%s)
```

**Files to fix:**
- [ ] `scripts/utils/common.sh:212` - start_time
- [ ] `scripts/utils/common.sh:214` - end_time

3. **Fix useless echo** (1 occurrence)
```bash
# Before (scripts/utils/common.sh:48)
echo "$(printf '=%.0s' {1..50})"

# After
printf '=%.0s' {1..50}
echo
```

**Validation:**
- [ ] Run: `shellcheck scripts/**/*.sh`
- [ ] Ensure 0 errors, 0 warnings
- [ ] Test all scripts still work

---

### 🔧 Priority 2: CI/CD Setup (Day 2)

#### Task 1.3: Create CI/CD Workflow
**File:** `.github/workflows/ci.yml` (new)  
**Effort:** 2 hours  
**Assignee:** DevOps/Any developer

**Create `.github/workflows/ci.yml`:**
```yaml
name: CI

on:
  push:
    branches: [main, dev]
  pull_request:
    branches: [main, dev]

jobs:
  shellcheck:
    name: ShellCheck Analysis
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run ShellCheck
        run: |
          shellcheck --version
          shellcheck scripts/**/*.sh

  syntax-check:
    name: Bash Syntax Check
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Check script syntax
        run: |
          for script in scripts/**/*.sh; do
            echo "Checking: $script"
            bash -n "$script"
          done

  test-action:
    name: Test Action
    runs-on: ubuntu-latest
    needs: [shellcheck, syntax-check]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Test with mock APK
        uses: ./
        with:
          file_path: tests/fixtures/test.apk
          file_type: apk
          package_name: com.test.app
          api_token: ${{ secrets.TEST_API_TOKEN }}
        continue-on-error: true

  documentation:
    name: Check Documentation
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Check for broken links in markdown
        run: |
          # Basic link check
          grep -r "](.*)" *.md || true

      - name: Verify required files
        run: |
          test -f README.md
          test -f CONTRIBUTING.md
          test -f SECURITY.md
          test -f LICENSE
```

**Validation:**
- [ ] Push to branch and verify workflow runs
- [ ] Check all jobs pass
- [ ] Fix any issues found

---

#### Task 1.4: Add Response Cleanup
**File:** `scripts/core/upload-to-store.sh`  
**Effort:** 15 minutes  
**Assignee:** Any developer

**Already included in Task 1.1** - No additional work needed.

---

### 📦 Deliverables - Sprint 1

- [ ] ✅ Command injection fixed and tested
- [ ] ✅ All ShellCheck warnings resolved
- [ ] ✅ CI/CD workflow running successfully
- [ ] ✅ Security scan passing
- [ ] 📄 Sprint 1 completion report

**Expected Score:** 87/100 (+2 from baseline)

---

## 📅 Sprint 2: Testing Infrastructure (Week 2-3)

**Goal:** Establish comprehensive testing framework  
**Duration:** 10-14 days  
**Effort:** ~24 hours  
**Score Target:** 90/100

### 🧪 Priority 1: Test Framework Setup (Day 1-2)

#### Task 2.1: Install Testing Framework
**Effort:** 2 hours  
**Assignee:** Testing lead

**Create `tests/setup.sh`:**
```bash
#!/bin/bash
# Test framework setup script

set -e

echo "Installing test dependencies..."

# Install bats-core
if ! command -v bats &> /dev/null; then
    npm install -g bats
    echo "✅ bats-core installed"
fi

# Install shellmock for mocking
if [[ ! -d tests/lib/shellmock ]]; then
    mkdir -p tests/lib
    git clone https://github.com/capitalone/bash_shell_mock.git tests/lib/shellmock
    echo "✅ shellmock installed"
fi

echo "Test framework setup complete!"
```

**Create `tests/helper.bash`:**
```bash
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
```

---

#### Task 2.2: Write Unit Tests for Validation
**Effort:** 6 hours  
**Assignee:** Developer

**Create `tests/unit/test_validation.bats`:**
```bash
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
```

**Additional test files to create:**
- [ ] `tests/unit/test_common.bats` (15 tests)
- [ ] `tests/unit/test_keystore.bats` (10 tests)
- [ ] `tests/unit/test_package_detection.bats` (8 tests)

**Total Unit Tests Target:** 50+ tests

---

#### Task 2.3: Write Integration Tests
**Effort:** 8 hours  
**Assignee:** Developer

**Create `tests/integration/test_keystore_setup.bats`:**
```bash
#!/usr/bin/env bats

load ../helper

setup() {
    setup_test_env
    load_lib "common"
    load_lib "keystore"
}

teardown() {
    teardown_test_env
}

@test "setup keystore from base64" {
    export INPUT_KEYSTORE_SOURCE="base64"
    export INPUT_KEYSTORE_BASE64="$(base64 < tests/fixtures/test-keystore.jks)"
    export INPUT_KEYSTORE_PASSWORD="testpass"
    export INPUT_KEY_ALIAS="testalias"
    export INPUT_KEY_PASSWORD="keypass"
    export INPUT_KEYSTORE_VALIDATION="false"
    
    run setup_keystore
    [ "$status" -eq 0 ]
    [ -f "$KEYSTORE_FILE_PATH" ]
}

@test "setup keystore from file" {
    export INPUT_KEYSTORE_SOURCE="file"
    export INPUT_KEYSTORE_PATH="tests/fixtures/test-keystore.jks"
    export INPUT_KEYSTORE_PASSWORD="testpass"
    export INPUT_KEY_ALIAS="testalias"
    export INPUT_KEY_PASSWORD="keypass"
    export INPUT_KEYSTORE_VALIDATION="false"
    
    run setup_keystore
    [ "$status" -eq 0 ]
    [ -f "$KEYSTORE_FILE_PATH" ]
}

@test "cleanup removes keystore" {
    # Setup keystore first
    export KEYSTORE_FILE_PATH="$TEMP_DIR/test-keystore.jks"
    echo "test" > "$KEYSTORE_FILE_PATH"
    
    run cleanup_keystore
    [ "$status" -eq 0 ]
    [ ! -f "$KEYSTORE_FILE_PATH" ]
}
```

**Additional integration test files:**
- [ ] `tests/integration/test_apk_flow.bats` (3 tests)
- [ ] `tests/integration/test_aab_flow.bats` (3 tests)
- [ ] `tests/integration/test_error_scenarios.bats` (4 tests)

**Total Integration Tests Target:** 10+ tests

---

#### Task 2.4: Create Test Fixtures
**Effort:** 2 hours  
**Assignee:** Developer

**Create test fixtures:**
```bash
tests/
├── fixtures/
│   ├── test.apk (dummy APK)
│   ├── test.aab (dummy AAB)
│   ├── test-keystore.jks (test keystore)
│   ├── build.gradle (sample)
│   ├── build.gradle.kts (sample)
│   └── AndroidManifest.xml (sample)
├── helper.bash
├── setup.sh
└── unit/
    └── test_*.bats
```

**Generate fixtures:**
```bash
# Create dummy APK
echo "PK" > tests/fixtures/test.apk

# Create dummy AAB
echo "PK" > tests/fixtures/test.aab

# Create test keystore
keytool -genkey -v -keystore tests/fixtures/test-keystore.jks \
    -alias testalias -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass testpass -keypass keypass -dname "CN=Test"

# Create sample gradle files
cat > tests/fixtures/build.gradle << 'EOF'
android {
    defaultConfig {
        applicationId "com.test.app"
    }
}
EOF

cat > tests/fixtures/build.gradle.kts << 'EOF'
android {
    defaultConfig {
        applicationId = "com.test.app"
    }
}
EOF
```

---

#### Task 2.5: Update CI to Run Tests
**File:** `.github/workflows/ci.yml`  
**Effort:** 1 hour  
**Assignee:** DevOps

**Add to CI workflow:**
```yaml
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    needs: [shellcheck, syntax-check]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup test environment
        run: |
          npm install -g bats
          bash tests/setup.sh

      - name: Run unit tests
        run: |
          bats tests/unit/*.bats

      - name: Run integration tests
        run: |
          bats tests/integration/*.bats

      - name: Generate coverage report
        run: |
          # Calculate coverage
          TOTAL_FUNCTIONS=$(grep -r "^[a-zA-Z_]*() {" scripts/ | wc -l)
          TESTED_FUNCTIONS=$(grep -r "@test" tests/ | wc -l)
          COVERAGE=$((TESTED_FUNCTIONS * 100 / TOTAL_FUNCTIONS))
          echo "Test Coverage: $COVERAGE%"
          
          # Fail if coverage < 70%
          if [ $COVERAGE -lt 70 ]; then
            echo "❌ Coverage is below 70%"
            exit 1
          fi
```

---

### 📦 Deliverables - Sprint 2

- [ ] ✅ Test framework installed and configured
- [ ] ✅ 50+ unit tests written and passing
- [ ] ✅ 10+ integration tests written and passing
- [ ] ✅ Test fixtures created
- [ ] ✅ CI running tests automatically
- [ ] ✅ Coverage reporting enabled
- [ ] 📄 Sprint 2 completion report

**Expected Score:** 90/100 (+3 from Sprint 1)

---

## 📅 Sprint 3: Reliability & Features (Week 4-5)

**Goal:** Improve reliability and address high-priority issues  
**Duration:** 10-14 days  
**Effort:** ~16 hours  
**Score Target:** 93/100

### 🔄 Priority 1: Upload Retry Mechanism (Day 1)

#### Task 3.1: Implement Retry Logic
**File:** `scripts/core/upload-to-store.sh`  
**Effort:** 2 hours  
**Assignee:** Developer

**Add retry function:**
```bash
upload_with_retry() {
    local max_attempts=3
    local attempt=1
    local delay=5
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Upload attempt $attempt of $max_attempts..."
        
        if upload_to_api; then
            log_success "Upload successful on attempt $attempt"
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_warning "Upload failed, retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
        fi
        
        ((attempt++))
    done
    
    log_error "Upload failed after $max_attempts attempts"
    return 1
}

# Main execution with retry
if upload_with_retry; then
    exit 0
else
    exit 1
fi
```

**Add configuration input to `action.yml`:**
```yaml
inputs:
  upload_retry_attempts:
    description: 'Number of retry attempts for upload failures'
    required: false
    default: '3'
  upload_retry_delay:
    description: 'Initial delay between retries in seconds'
    required: false
    default: '5'
```

**Tests:**
- [ ] Test successful upload on first attempt
- [ ] Test retry on network failure
- [ ] Test exponential backoff
- [ ] Test max retries exceeded

---

### 🔍 Priority 2: Improved Package Detection (Day 2-3)

#### Task 3.2: Enhanced Package Name Detection
**File:** `scripts/core/detect-package-name.sh`  
**Effort:** 4 hours  
**Assignee:** Developer

**Rewrite with multi-module support:**
```bash
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

PACKAGE_NAME="$INPUT_PACKAGE_NAME"

detect_from_gradle() {
    local gradle_file="$1"
    local package_name=""
    
    if [[ -f "$gradle_file" ]]; then
        if [[ "$gradle_file" == *.kts ]]; then
            # Kotlin DSL
            package_name=$(grep -o 'applicationId = ".*"' "$gradle_file" | sed -E 's/applicationId = "(.*)"/\1/' | head -1)
        else
            # Groovy DSL
            package_name=$(grep -o "applicationId ['\"].*['\"]" "$gradle_file" | sed -E "s/applicationId ['\"]([^'\"]*)['\"].*/\1/" | head -1)
        fi
    fi
    
    echo "$package_name"
}

detect_from_manifest() {
    local manifest_file="$1"
    local package_name=""
    
    if [[ -f "$manifest_file" ]]; then
        # Try xmllint first
        if command_exists xmllint; then
            package_name=$(xmllint --xpath 'string(//manifest/@package)' "$manifest_file" 2>/dev/null)
        fi
        
        # Fallback to grep
        if [[ -z "$package_name" ]]; then
            package_name=$(grep -o 'package="[^"]*"' "$manifest_file" | sed 's/package="\([^"]*\)"/\1/' | head -1)
        fi
    fi
    
    echo "$package_name"
}

auto_detect_package() {
    log_section "Auto-detecting package name"
    
    # Strategy 1: Search all build.gradle files
    log_debug "Searching for build.gradle files..."
    while IFS= read -r gradle_file; do
        local detected
        detected=$(detect_from_gradle "$gradle_file")
        if [[ -n "$detected" ]]; then
            log_info "Found package name in $gradle_file: $detected"
            echo "$detected"
            return 0
        fi
    done < <(find . -name "build.gradle*" -type f 2>/dev/null)
    
    # Strategy 2: Search AndroidManifest.xml files
    log_debug "Searching for AndroidManifest.xml files..."
    while IFS= read -r manifest_file; do
        local detected
        detected=$(detect_from_manifest "$manifest_file")
        if [[ -n "$detected" ]]; then
            log_info "Found package name in $manifest_file: $detected"
            echo "$detected"
            return 0
        fi
    done < <(find . -name "AndroidManifest.xml" -type f 2>/dev/null)
    
    # Strategy 3: Extract from APK/AAB if provided
    if [[ -f "$INPUT_FILE_PATH" ]]; then
        log_debug "Attempting to extract package name from $INPUT_FILE_PATH..."
        local detected
        if command_exists aapt; then
            detected=$(aapt dump badging "$INPUT_FILE_PATH" 2>/dev/null | grep -o "package: name='[^']*'" | sed "s/package: name='\([^']*\)'/\1/")
            if [[ -n "$detected" ]]; then
                log_info "Extracted package name from file: $detected"
                echo "$detected"
                return 0
            fi
        fi
    fi
    
    return 1
}

# Main logic
if [[ -z "$PACKAGE_NAME" && "$INPUT_AUTO_DETECT_PACKAGE" == "true" ]]; then
    if DETECTED_PACKAGE=$(auto_detect_package); then
        PACKAGE_NAME="$DETECTED_PACKAGE"
    else
        log_error "Could not auto-detect package name"
        exit 1
    fi
fi

if [[ -z "$PACKAGE_NAME" ]]; then
    log_error "Package name is required"
    exit 1
fi

echo "PACKAGE_NAME=$PACKAGE_NAME" >> "$GITHUB_ENV"
log_success "Package name set to: $PACKAGE_NAME"
```

**Tests:**
- [ ] Test with standard app/ directory
- [ ] Test with multi-module project
- [ ] Test with Kotlin DSL
- [ ] Test with Groovy DSL
- [ ] Test with manifest fallback
- [ ] Test with APK extraction

---

### 🛡️ Priority 3: API Endpoint Validation (Day 4)

#### Task 3.3: Add API Health Check
**File:** `scripts/core/prepare-upload.sh`  
**Effort:** 2 hours  
**Assignee:** Developer

**Add validation:**
```bash
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

validate_api_endpoint() {
    local api_url="$1"
    
    log_debug "Validating API endpoint: $api_url"
    
    # Check URL format
    if [[ ! "$api_url" =~ ^https?:// ]]; then
        log_error "Invalid API URL format: $api_url"
        return 1
    fi
    
    # Optional: Ping endpoint (can be disabled)
    if [[ "${INPUT_VALIDATE_API_ENDPOINT:-true}" == "true" ]]; then
        local base_url
        base_url=$(echo "$api_url" | sed -E 's|(/[^/]*)?$||')
        
        log_debug "Checking API availability: $base_url"
        if ! curl -s -f -m 10 "$base_url/health" > /dev/null 2>&1; then
            log_warning "API health check failed, proceeding anyway..."
        else
            log_success "API endpoint is reachable"
        fi
    fi
    
    return 0
}

# Prepare upload
log_section "Preparing file for upload"

UPLOAD_FILE_PATH="${INPUT_FILE_PATH}"
echo "UPLOAD_FILE_PATH=${UPLOAD_FILE_PATH}" >> "$GITHUB_ENV"

if [[ ! -f "${UPLOAD_FILE_PATH}" ]]; then
    log_error "File not found at ${UPLOAD_FILE_PATH}"
    exit 1
fi

# Construct API URL
BASE_URL="${INPUT_API_BASE_URL:-https://developer-api.indusappstore.com/devtools}"

case "$INPUT_FILE_TYPE" in
    "aab")
        API_URL="${BASE_URL}/aab/upgrade/$PACKAGE_NAME"
        ;;
    "apks")
        API_URL="${BASE_URL}/apks/upgrade/$PACKAGE_NAME"
        ;;
    *)
        API_URL="${BASE_URL}/apk/upgrade/$PACKAGE_NAME"
        ;;
esac

# Validate API endpoint
if ! validate_api_endpoint "$API_URL"; then
    exit 1
fi

echo "API_URL=${API_URL}" >> "$GITHUB_ENV"
log_success "Upload preparation complete"
log_info "File: ${UPLOAD_FILE_PATH}"
log_info "API URL: ${API_URL}"
```

**Add to `action.yml`:**
```yaml
inputs:
  api_base_url:
    description: 'Indus Appstore API base URL'
    required: false
    default: 'https://developer-api.indusappstore.com/devtools'
  validate_api_endpoint:
    description: 'Validate API endpoint before upload'
    required: false
    default: 'true'
```

---

### 📏 Priority 4: File Size Validation (Day 5)

#### Task 3.4: Add File Size Checks
**File:** `scripts/utils/validation.sh`  
**Effort:** 1 hour  
**Assignee:** Developer

**Add validation function:**
```bash
validate_file_size() {
    local file_path="$INPUT_FILE_PATH"
    local max_size_mb="${INPUT_MAX_FILE_SIZE_MB:-150}"
    
    if [[ ! -f "$file_path" ]]; then
        log_error "File not found: $file_path"
        return 1
    fi
    
    local file_size
    file_size=$(get_file_size "$file_path")
    local max_size=$((max_size_mb * 1024 * 1024))
    
    log_info "File size: $(format_file_size "$file_size")"
    log_info "Maximum allowed: ${max_size_mb}MB"
    
    if [[ $file_size -gt $max_size ]]; then
        log_error "File size $(format_file_size "$file_size") exceeds limit of ${max_size_mb}MB"
        return 1
    fi
    
    if [[ $file_size -eq 0 ]]; then
        log_error "File is empty: $file_path"
        return 1
    fi
    
    log_success "File size validation passed"
    return 0
}
```

**Add to validation checks:**
```bash
validate_all_inputs() {
    # ... existing validations ...
    
    validate_file_size || ((validation_errors++))
    
    # ... rest of function ...
}
```

**Add to `action.yml`:**
```yaml
inputs:
  max_file_size_mb:
    description: 'Maximum file size in MB'
    required: false
    default: '150'
```

---

### 📦 Deliverables - Sprint 3

- [ ] ✅ Upload retry mechanism implemented and tested
- [ ] ✅ Enhanced package detection with multi-module support
- [ ] ✅ API endpoint validation added
- [ ] ✅ File size validation implemented
- [ ] ✅ All tests passing
- [ ] 📄 Sprint 3 completion report

**Expected Score:** 93/100 (+3 from Sprint 2)

---

## 📅 Sprint 4: Polish & Enhancement (Week 6-12)

**Goal:** Final polish, documentation, and enhancements  
**Duration:** 6 weeks  
**Effort:** ~40 hours (distributed)  
**Score Target:** 95/100

### 📚 Priority 1: Documentation Improvements (Week 6-7)

#### Task 4.1: Split and Reorganize Documentation
**Effort:** 6 hours  
**Assignee:** Technical writer / Developer

**Create new documentation structure:**
```
docs/
├── getting-started/
│   ├── README.md (Quick start)
│   ├── installation.md
│   └── first-deployment.md
├── configuration/
│   ├── README.md (Overview)
│   ├── inputs.md (All inputs reference)
│   ├── keystore-sources.md
│   └── advanced-options.md
├── examples/
│   ├── README.md (Index)
│   ├── basic-apk.md
│   ├── aab-with-keystore.md
│   ├── multi-variant.md
│   ├── monorepo.md
│   └── custom-keystore-script.md
├── guides/
│   ├── troubleshooting.md
│   ├── security-best-practices.md
│   ├── performance-tuning.md
│   └── migration-guide.md
└── api/
    └── reference.md
```

**Update main README.md to be concise:**
- Introduction and overview
- Quick start (30 seconds to deploy)
- Links to detailed documentation
- Support and contributing links

---

#### Task 4.2: Create Troubleshooting Guide
**File:** `docs/guides/troubleshooting.md`  
**Effort:** 4 hours  
**Assignee:** Technical writer / Developer

**Content outline:**
```markdown
# Troubleshooting Guide

## Common Issues

### Authentication Errors
- Invalid API token
- Token expired
- Insufficient permissions

### File Upload Errors
- File not found
- File size too large
- Network timeouts
- Invalid file format

### Keystore Issues
- Invalid keystore password
- Key alias not found
- Keystore validation failed
- Decryption errors

### Package Detection Failures
- Package name not found
- Invalid build.gradle format
- Multi-module confusion

### API Errors
- HTTP 4xx errors (client)
- HTTP 5xx errors (server)
- Rate limiting

## Debug Mode

Enable verbose logging:
```yaml
with:
  verbose: 'true'
```

## Getting Help

- Check workflow logs
- Enable debug mode
- Review related issues
- Contact support
```

---

#### Task 4.3: Expand Security Documentation
**File:** `SECURITY.md` + `docs/guides/security-best-practices.md`  
**Effort:** 3 hours  
**Assignee:** Security expert / Developer

**Expand SECURITY.md:**
- Supported versions
- Security features
- Best practices overview
- Reporting vulnerabilities (already there)

**Create detailed security guide:**
- Keystore security comparison
- Secret management
- Network security
- Audit logging
- Compliance considerations

---

### ⚡ Priority 2: Performance Optimization (Week 8)

#### Task 4.4: Optimize Package Detection
**Effort:** 2 hours  
**Assignee:** Developer

**Improvements:**
- Cache gradle file locations
- Parallel file searching
- Limit search depth
- Skip common directories (node_modules, .git, etc.)

---

#### Task 4.5: Add Upload Progress
**File:** `scripts/core/upload-to-store.sh`  
**Effort:** 3 hours  
**Assignee:** Developer

**Implementation:**
```bash
upload_with_progress() {
    local temp_log="$TEMP_DIR/curl_progress.log"
    
    # Start upload in background
    "${curl_cmd[@]}" > "$temp_log" 2>&1 &
    local curl_pid=$!
    
    # Monitor progress
    while kill -0 $curl_pid 2>/dev/null; do
        log_info "Upload in progress..."
        sleep 5
    done
    
    # Wait for completion
    wait $curl_pid
    local exit_code=$?
    
    return $exit_code
}
```

---

### 🎨 Priority 3: Enhancements (Week 9-10)

#### Task 4.6: Add Output Parameters
**File:** `action.yml` and scripts  
**Effort:** 4 hours  
**Assignee:** Developer

**Add outputs to `action.yml`:**
```yaml
outputs:
  upload_status:
    description: 'Upload status (success/failure)'
    value: ${{ steps.upload.outputs.status }}
  upload_url:
    description: 'URL of uploaded package'
    value: ${{ steps.upload.outputs.url }}
  package_version:
    description: 'Version of uploaded package'
    value: ${{ steps.upload.outputs.version }}
  file_size:
    description: 'Size of uploaded file'
    value: ${{ steps.upload.outputs.size }}
```

**Update scripts to set outputs:**
```bash
# In upload-to-store.sh
echo "status=success" >> "$GITHUB_OUTPUT"
echo "url=$UPLOAD_URL" >> "$GITHUB_OUTPUT"
echo "version=$VERSION" >> "$GITHUB_OUTPUT"
echo "size=$(get_file_size "$UPLOAD_FILE_PATH")" >> "$GITHUB_OUTPUT"
```

---

#### Task 4.7: Add Dry Run Mode
**Effort:** 3 hours  
**Assignee:** Developer

**Add to `action.yml`:**
```yaml
inputs:
  dry_run:
    description: 'Validate without uploading'
    required: false
    default: 'false'
```

**Implementation:**
- Run all validations
- Prepare upload
- Log what would be uploaded
- Skip actual upload
- Exit with success

---

#### Task 4.8: Enhance Error Messages
**Effort:** 4 hours  
**Assignee:** Developer

**Improvements:**
- More descriptive error messages
- Suggestions for fixes
- Links to troubleshooting guide
- Error codes for categorization

---

### 🔒 Priority 4: Security Enhancements (Week 11)

#### Task 4.9: Add Hash Verification for Downloads
**File:** `scripts/utils/keystore.sh`  
**Effort:** 2 hours  
**Assignee:** Developer

**Add optional SHA256 verification:**
```bash
download_keystore() {
    local url="$1"
    local output_path="$2"
    local auth_header="$3"
    local expected_sha256="$4"  # Optional
    
    # Download
    # ... existing code ...
    
    # Verify if hash provided
    if [[ -n "$expected_sha256" ]]; then
        log_info "Verifying keystore integrity..."
        local actual_sha256
        actual_sha256=$(sha256sum "$output_path" | cut -d' ' -f1)
        
        if [[ "$actual_sha256" != "$expected_sha256" ]]; then
            log_error "Keystore hash mismatch!"
            log_error "Expected: $expected_sha256"
            log_error "Actual: $actual_sha256"
            secure_remove "$output_path"
            return 1
        fi
        
        log_success "Keystore integrity verified"
    fi
    
    return 0
}
```

---

#### Task 4.10: Improve Secret Masking
**Effort:** 3 hours  
**Assignee:** Security expert

**Implementation:**
- Mask secrets in all log outputs
- Use GitHub Actions secret masking
- Redact sensitive information from errors
- Audit all log statements

---

### 📊 Priority 5: Metrics and Monitoring (Week 12)

#### Task 4.11: Add Telemetry (Opt-in)
**Effort:** 6 hours  
**Assignee:** Developer

**Features:**
- Usage statistics (opt-in)
- Success/failure rates
- Average upload times
- Popular configurations
- Anonymous error reporting

**Privacy:**
- Opt-in only
- No sensitive data
- Clear privacy policy
- Easy to disable

---

#### Task 4.12: Performance Benchmarking
**Effort:** 4 hours  
**Assignee:** Developer

**Create benchmarking suite:**
- Measure execution time for each component
- Test with different file sizes
- Test with different keystore sources
- Document performance characteristics

---

### 📦 Deliverables - Sprint 4

- [ ] ✅ Documentation reorganized and improved
- [ ] ✅ Troubleshooting guide created
- [ ] ✅ Security documentation expanded
- [ ] ✅ Performance optimizations implemented
- [ ] ✅ Upload progress indication added
- [ ] ✅ Output parameters available
- [ ] ✅ Dry run mode working
- [ ] ✅ Error messages enhanced
- [ ] ✅ Hash verification for downloads
- [ ] ✅ Secret masking improved
- [ ] ✅ Telemetry framework (opt-in)
- [ ] ✅ Performance benchmarks documented
- [ ] 📄 Final sprint report

**Expected Score:** 95/100 (+2 from Sprint 3)

---

## 📈 Progress Tracking

### Metrics Dashboard

Track progress using these metrics:

| Metric | Baseline | Sprint 1 | Sprint 2 | Sprint 3 | Sprint 4 | Target |
|--------|----------|----------|----------|----------|----------|--------|
| Overall Score | 85 | 87 | 90 | 93 | 95 | 95 |
| Test Coverage | 0% | 0% | 70% | 80% | 85% | 80%+ |
| ShellCheck Issues | 24 | 0 | 0 | 0 | 0 | 0 |
| Critical Issues | 2 | 0 | 0 | 0 | 0 | 0 |
| High Issues | 4 | 4 | 1 | 0 | 0 | 0 |
| Medium Issues | 5 | 5 | 3 | 1 | 0 | 0 |
| Documentation Score | 90 | 90 | 90 | 90 | 95 | 95 |

### Weekly Checkins

**Every Monday:**
- Review progress from previous week
- Update roadmap if needed
- Prioritize tasks for current week
- Address blockers

**Every Friday:**
- Sprint retrospective
- Update metrics
- Plan next week
- Celebrate wins

---

## 🎯 Success Criteria

### Sprint 1 Complete When:
- [ ] Command injection fixed
- [ ] All ShellCheck warnings resolved
- [ ] CI/CD running successfully
- [ ] Security scan passing

### Sprint 2 Complete When:
- [ ] Test framework installed
- [ ] 50+ unit tests passing
- [ ] 10+ integration tests passing
- [ ] 70%+ test coverage

### Sprint 3 Complete When:
- [ ] Retry mechanism working
- [ ] Enhanced package detection deployed
- [ ] API validation implemented
- [ ] All high-priority issues resolved

### Sprint 4 Complete When:
- [ ] Documentation reorganized
- [ ] Troubleshooting guide complete
- [ ] All enhancements deployed
- [ ] 95/100 score achieved
- [ ] Production ready with confidence

---

## 🚧 Risk Management

### Identified Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Test framework integration issues | Medium | High | Early setup, community support |
| Breaking changes during fixes | Low | High | Comprehensive testing, staged rollout |
| Resource constraints | Medium | Medium | Prioritize critical items, extend timeline if needed |
| API changes | Low | High | Version pinning, monitoring |

### Contingency Plans

**If behind schedule:**
- Focus on critical and high priority items
- Defer nice-to-have enhancements
- Extend Sprint 4 timeline

**If issues arise:**
- Roll back problematic changes
- Create hotfix branch
- Address immediately

**If resources unavailable:**
- Community contributions welcome
- Adjust timeline accordingly
- Focus on automation

---

## 👥 Team & Responsibilities

### Roles

**Project Lead:**
- Overall roadmap coordination
- Sprint planning
- Stakeholder communication

**Development Team:**
- Implement fixes and features
- Write tests
- Code reviews

**QA/Testing:**
- Test planning
- Test execution
- Bug reporting

**Documentation:**
- Technical writing
- User guides
- Examples

**Security:**
- Security reviews
- Vulnerability assessment
- Best practices

### Communication

**Daily:**
- Async updates in channel

**Weekly:**
- Sprint planning (Monday)
- Sprint review (Friday)

**Ad-hoc:**
- Blocker resolution
- Technical discussions
- PR reviews

---

## 📚 Resources

### Documentation
- [Comprehensive Analysis](ANALYSIS_REPORT.md)
- [Architecture Guide](ARCHITECTURE.md)
- [Issues & Recommendations](ISSUES_AND_RECOMMENDATIONS.md)
- [Metrics & Statistics](METRICS_AND_STATISTICS.md)

### Tools
- ShellCheck: https://www.shellcheck.net/
- bats-core: https://github.com/bats-core/bats-core
- GitHub Actions: https://docs.github.com/actions

### Community
- GitHub Issues: Report bugs and request features
- Pull Requests: Contribute code
- Discussions: Ask questions

---

## 🎉 Milestones

### Month 1 (Sprint 1-2)
**Milestone:** "Security & Testing Foundation"
- ✅ Critical security issues resolved
- ✅ Testing infrastructure established
- ✅ CI/CD operational
- 🎯 Score: 90/100

### Month 2 (Sprint 3)
**Milestone:** "Reliability & Robustness"
- ✅ Retry mechanism implemented
- ✅ Enhanced validation
- ✅ All high-priority issues resolved
- 🎯 Score: 93/100

### Month 3 (Sprint 4)
**Milestone:** "Production Excellence"
- ✅ Documentation polished
- ✅ Performance optimized
- ✅ All enhancements complete
- 🎯 Score: 95/100 (A+ grade)

---

## 🔄 Maintenance Plan

### Post-Roadmap

**Monthly:**
- Review metrics
- Check for new vulnerabilities
- Update dependencies
- Review and triage new issues

**Quarterly:**
- Feature planning
- Performance review
- Documentation update
- Community feedback

**Yearly:**
- Major version planning
- Architecture review
- Roadmap refresh

---

## 📝 Notes

### Assumptions
- GitHub Actions environment availability
- Access to Indus Appstore API
- Community contribution potential
- Stable API endpoints

### Dependencies
- External: GitHub Actions, Indus Appstore API
- Internal: All scripts interdependent
- Tools: bash, curl, keytool, shellcheck

### Change Management
- All changes via Pull Requests
- Minimum 1 reviewer
- All tests must pass
- No direct commits to main

---

## ✅ Acceptance Criteria

This roadmap is complete when:
1. [ ] All sprints completed
2. [ ] Score reaches 95/100
3. [ ] 80%+ test coverage
4. [ ] 0 critical/high issues
5. [ ] Documentation complete
6. [ ] Production deployment successful
7. [ ] Team trained and confident
8. [ ] Community engaged

---

**Version:** 1.0  
**Created:** October 23, 2025  
**Owner:** Repository Maintainers  
**Status:** 🟢 Active

---

*This roadmap is a living document. Update it as progress is made and priorities change.*
