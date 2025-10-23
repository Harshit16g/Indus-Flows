# Architecture and Component Breakdown

**Repository:** Harshit16g/Indus-Flows  
**Date:** October 23, 2025

---

## 1. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Actions Workflow                      │
│                    (User's .github/workflows/)                   │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Indus-Flows Action (action.yml)               │
│  ┌──────────────┬──────────────┬──────────────┬──────────────┐  │
│  │   Inputs     │  Environment │   Composite  │   Cleanup    │  │
│  │  Validation  │     Setup    │    Steps     │   (Always)   │  │
│  └──────────────┴──────────────┴──────────────┴──────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ Core Scripts │     │   Keystore   │     │    Utils     │
│              │     │    Scripts   │     │   Scripts    │
│ • validate   │     │ • setup      │     │ • common     │
│ • detect     │     │ • cleanup    │     │ • keystore   │
│ • prepare    │     │              │     │ • validation │
│ • upload     │     │              │     │              │
└──────────────┘     └──────────────┘     └──────────────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              Indus Appstore Developer API                        │
│         https://developer-api.indusappstore.com/devtools         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Component Breakdown

### 2.1 Entry Point: action.yml

**Role:** GitHub Action Composite Definition

**Responsibilities:**
- Define input parameters (23 inputs)
- Orchestrate script execution
- Set up environment variables
- Ensure cleanup runs always

**Key Inputs:**
```yaml
Core:
  - operation_mode: 'deploy_only'
  - file_path: Path to APK/AAB/APKS
  - file_type: 'apk' | 'aab' | 'apks'
  - package_name: Android package identifier
  - api_token: Indus Appstore API token
  - release_notes: Deployment notes

Keystore:
  - keystore_source: Source type (6 options)
  - keystore_*: Source-specific parameters
  - keystore_password: Keystore password
  - key_alias: Key alias
  - key_password: Key password

Options:
  - auto_detect_package: Auto-detect from gradle
  - keystore_validation: Validate before use
  - verbose: Enable debug logging
```

**Execution Flow:**
```
1. Set script permissions
   ↓
2. Detect package name (if auto-detect enabled)
   ↓
3. Validate all inputs
   ↓
4. Setup keystore (if file_type == 'aab')
   ↓
5. Prepare for upload
   ↓
6. Upload to Indus Appstore
   ↓
7. Cleanup keystore (always, even on failure)
```

---

### 2.2 Core Scripts Layer

#### 2.2.1 validate-inputs.sh

**Purpose:** Input validation orchestrator

**Dependencies:**
- `utils/common.sh` - Logging functions
- `utils/validation.sh` - Validation functions

**Validation Checks:**
```
┌─────────────────────────────────────┐
│   validate_operation_mode()         │ → Only 'deploy_only'
├─────────────────────────────────────┤
│   validate_file_type()              │ → 'apk'|'aab'|'apks'
├─────────────────────────────────────┤
│   validate_api_token()              │ → Length >= 20
├─────────────────────────────────────┤
│   validate_package_info()           │ → Java package format
├─────────────────────────────────────┤
│   validate_keystore_configuration() │ → Source-specific
├─────────────────────────────────────┤
│   validate_deployment_file()        │ → File exists
├─────────────────────────────────────┤
│   validate_boolean_parameters()     │ → 'true'|'false'
└─────────────────────────────────────┘
```

**Exit Codes:**
- 0: All validations passed
- 1: One or more validations failed

#### 2.2.2 detect-package-name.sh

**Purpose:** Auto-detect Android package name

**Detection Strategy:**
```
1. Check if manual package_name provided
   ├─ Yes → Use it
   └─ No → Continue
   
2. Check if auto_detect_package == 'true'
   ├─ No → Error: package name required
   └─ Yes → Continue
   
3. Look for app/build.gradle
   ├─ Found → Extract applicationId (Groovy)
   └─ Not found → Continue
   
4. Look for app/build.gradle.kts
   ├─ Found → Extract applicationId (Kotlin)
   └─ Not found → Error
   
5. Set PACKAGE_NAME environment variable
```

**Regex Patterns:**
```bash
# Groovy DSL
applicationId ["'].*["']

# Kotlin DSL
applicationId = ".*"
```

**Limitations:**
- Only checks `app/` directory
- No multi-module support
- No AndroidManifest.xml fallback
- Regex might fail with complex files

#### 2.2.3 prepare-upload.sh

**Purpose:** Prepare file and API URL

**Tasks:**
```
1. Validate file exists at INPUT_FILE_PATH
   ↓
2. Set UPLOAD_FILE_PATH environment variable
   ↓
3. Construct API URL based on file_type:
   ├─ apk  → /apk/upgrade/{package}
   ├─ aab  → /aab/upgrade/{package}
   └─ apks → /apks/upgrade/{package}
   ↓
4. Set API_URL environment variable
```

**API URL Construction:**
```
BASE_URL = https://developer-api.indusappstore.com/devtools

For APK:  {BASE_URL}/apk/upgrade/{PACKAGE_NAME}
For AAB:  {BASE_URL}/aab/upgrade/{PACKAGE_NAME}
For APKS: {BASE_URL}/apks/upgrade/{PACKAGE_NAME}
```

#### 2.2.4 upload-to-store.sh

**Purpose:** Upload file to Indus Appstore API

**Upload Flow:**
```
1. Construct curl command
   ├─ Method: POST
   ├─ Auth: O-Bearer token
   ├─ Content-Type: multipart/form-data
   └─ Form fields:
       ├─ file: @{file_path}
       ├─ releaseNotes: {notes}
       └─ If AAB:
           ├─ file: @{keystore}
           ├─ keystorePassword
           ├─ keystoreAlias
           └─ keyPassword
   ↓
2. Execute upload (⚠️ uses eval)
   ↓
3. Extract HTTP status code
   ↓
4. Check status:
   ├─ 2xx → Success
   └─ Other → Failure
```

**Current Issues:**
- Uses `eval` (security risk)
- No retry mechanism
- Minimal response validation
- No progress indication
- No cleanup of response.txt

---

### 2.3 Keystore Management Layer

#### 2.3.1 setup-keystore.sh

**Purpose:** Setup keystore from various sources

**Source Handlers:**

```
┌──────────────────────────────────────────────────────────┐
│ Keystore Source: base64                                  │
├──────────────────────────────────────────────────────────┤
│ 1. Receive base64 string from secrets                    │
│ 2. Decode to binary keystore file                        │
│ 3. Set permissions to 600                                │
│ 4. Validate with keytool                                 │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ Keystore Source: cdn                                     │
├──────────────────────────────────────────────────────────┤
│ 1. Construct curl command with auth                      │
│ 2. Download from CDN URL                                 │
│ 3. Retry up to 3 times with backoff                      │
│ 4. Set permissions to 600                                │
│ 5. Validate with keytool                                 │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ Keystore Source: script                                  │
├──────────────────────────────────────────────────────────┤
│ 1. Make script executable                                │
│ 2. Set KEYSTORE_OUTPUT_PATH env var                      │
│ 3. Execute script with arguments                         │
│ 4. Check if keystore created                             │
│ 5. Set permissions to 600                                │
│ 6. Validate with keytool                                 │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ Keystore Source: encrypted_file                          │
├──────────────────────────────────────────────────────────┤
│ 1. Check OpenSSL availability                            │
│ 2. Decrypt using AES-256-CBC                             │
│ 3. Write to keystore file                                │
│ 4. Set permissions to 600                                │
│ 5. Validate with keytool                                 │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ Keystore Source: file                                    │
├──────────────────────────────────────────────────────────┤
│ 1. Check file exists                                     │
│ 2. Secure copy to workspace                              │
│ 3. Set permissions to 600                                │
│ 4. Validate with keytool                                 │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ Keystore Source: none                                    │
├──────────────────────────────────────────────────────────┤
│ Skip keystore setup (for unsigned builds)                │
└──────────────────────────────────────────────────────────┘
```

**Validation Process:**
```
IF keystore_validation == 'true':
   1. Check keytool availability
   2. Run: keytool -list -keystore {file} -storepass {pass} -alias {alias}
   3. Capture output to temp file
   4. Check exit code
   5. Securely delete temp file
   6. Return success/failure
```

#### 2.3.2 cleanup-keystore.sh

**Purpose:** Securely remove all keystore files

**Cleanup Process:**
```
1. Securely remove keystore file
   ├─ If shred available: shred -vfz -n 3
   └─ Else: rm -f
   
2. Remove signing.properties file
   
3. Unset environment variables:
   ├─ KEYSTORE_FILE_PATH
   ├─ KEYSTORE_PASSWORD
   ├─ KEY_ALIAS
   ├─ KEY_PASSWORD
   └─ KEYSTORE_OUTPUT_PATH
   
4. Clean up temporary directory
   └─ rm -rf $TEMP_DIR
```

---

### 2.4 Utilities Layer

#### 2.4.1 common.sh

**Purpose:** Shared utility functions

**Function Categories:**

**Logging Functions:**
```bash
log_info()     # Blue ℹ️  information
log_success()  # Green ✅ success
log_warning()  # Yellow ⚠️  warning
log_error()    # Red ❌ error
log_debug()    # Purple 🔍 debug (verbose mode only)
log_section()  # Cyan 🔹 section header with separator
```

**File Operations:**
```bash
secure_copy()      # Copy with permissions 600
secure_remove()    # Shred then remove
get_file_size()    # Cross-platform file size
format_file_size() # Human-readable format (B, KB, MB, GB)
```

**Validation:**
```bash
validate_env_var()   # Check environment variable
validate_file_path() # Check for injection patterns
validate_url()       # Basic URL validation
```

**Utilities:**
```bash
command_exists()   # Check if command available
retry_command()    # Retry with exponential backoff
measure_time()     # Time command execution
setup_temp_dir()   # Create secure temp directory
cleanup_temp_dir() # Remove temp directory
```

**Global Constants:**
```bash
WORKSPACE_DIR      # GitHub workspace
TEMP_DIR           # .indus-temp directory
KEYSTORE_FILE_PATH # signing-keystore.jks
```

#### 2.4.2 keystore.sh

**Purpose:** Keystore-specific operations

**Public Functions:**
```bash
validate_keystore()      # Validate with keytool
download_keystore()      # Download from CDN
decode_base64_keystore() # Decode base64 content
execute_keystore_script()# Run custom script
decrypt_keystore_file()  # Decrypt encrypted file
setup_keystore()         # Main setup orchestrator
cleanup_keystore()       # Main cleanup orchestrator
```

**Dependencies:**
- `common.sh` - For logging and utilities
- External tools: curl, base64, openssl, keytool

#### 2.4.3 validation.sh

**Purpose:** Input validation functions

**Validation Functions:**
```bash
validate_operation_mode()
validate_file_type()
validate_api_token()
validate_package_info()
validate_keystore_source()
validate_keystore_configuration()
validate_deployment_file()
validate_boolean_parameters()
validate_all_inputs()  # Orchestrator
```

**Validation Rules:**

| Parameter | Rules | Error Messages |
|-----------|-------|----------------|
| operation_mode | Must be 'deploy_only' | "Currently only 'deploy_only' operation mode is supported" |
| file_type | Must be 'apk', 'aab', or 'apks' | "Invalid file type: {type}" |
| api_token | Must be >= 20 chars | "API token appears to be too short" |
| package_name | Must match Java package regex | "Invalid package name format: {name}" |
| keystore_source | Must be valid source type | "Invalid keystore source: {source}" |
| file_path | Must exist | "Deployment file does not exist: {path}" |
| boolean params | Must be 'true' or 'false' | "Invalid boolean value for {param}" |

---

## 3. Data Flow

### 3.1 APK Deployment Flow

```
User Workflow
     │
     ▼
┌────────────────────┐
│ action.yml         │
│ Set permissions    │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│ detect-package     │ ◄── app/build.gradle
│ name.sh            │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│ validate-inputs.sh │
│ All checks pass?   │
└─────────┬──────────┘
          │ Yes
          ▼
┌────────────────────┐
│ prepare-upload.sh  │
│ Set API URL        │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│ upload-to-store.sh │ ──────► Indus API
│ POST multipart     │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│ Success!           │
└────────────────────┘
```

### 3.2 AAB Deployment Flow (with Keystore)

```
User Workflow
     │
     ▼
┌────────────────────┐
│ action.yml         │
│ Set permissions    │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│ detect-package     │
│ name.sh            │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│ validate-inputs.sh │
│ Check keystore     │
└─────────┬──────────┘
          │ Yes
          ▼
┌────────────────────┐
│ setup-keystore.sh  │ ◄── Base64/CDN/Script/
│ Prepare keystore   │     Encrypted/File
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│ prepare-upload.sh  │
│ Set API URL        │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│ upload-to-store.sh │ ──────► Indus API
│ POST with keystore │         (AAB + Keystore)
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│ cleanup-keystore   │
│ Secure deletion    │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│ Success!           │
└────────────────────┘
```

---

## 4. Security Architecture

### 4.1 Security Layers

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Input Validation                               │
│ • Path injection prevention                             │
│ • URL validation                                         │
│ • Parameter type checking                               │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 2: Secure File Handling                           │
│ • Permissions 600 for keystores                         │
│ • Secure copy operations                                │
│ • Path traversal prevention                             │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 3: Encryption                                      │
│ • AES-256-CBC for encrypted keystores                   │
│ • HTTPS for CDN downloads                               │
│ • Secure credential handling                            │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 4: Cleanup & Sanitization                         │
│ • Secure deletion (shred)                               │
│ • Environment variable cleanup                          │
│ • Temp directory removal                                │
│ • Always runs (even on failure)                         │
└─────────────────────────────────────────────────────────┘
```

### 4.2 Secret Handling

**Secrets Flow:**
```
GitHub Secrets
     │
     ├─► INPUT_API_TOKEN ──────► upload-to-store.sh
     │                            (HTTP header)
     │
     ├─► INPUT_KEYSTORE_BASE64 ─► decode_base64_keystore()
     │                            → File with permissions 600
     │                            → Validated with keytool
     │                            → Uploaded to API
     │                            → Securely deleted
     │
     ├─► INPUT_KEYSTORE_PASSWORD → Environment variable
     │                            → Used by keytool/curl
     │                            → Unset in cleanup
     │
     └─► INPUT_KEY_PASSWORD ─────► Environment variable
                                   → Used by curl
                                   → Unset in cleanup
```

**Potential Leakage Points:**
1. ❌ Verbose logging might print secrets
2. ❌ Process environment visible during execution
3. ❌ response.txt not cleaned up
4. ✅ Credentials never written to disk (except keystore)
5. ✅ Always cleanup prevents leakage

---

## 5. Error Handling Architecture

### 5.1 Error Propagation

```
Script Level
     │
     ├─► set -e (Exit on error)
     │
     ├─► Validation Functions
     │   └─► Return 1 on error
     │
     ├─► Setup Functions
     │   └─► Return 1 on error
     │       └─► Log error message
     │
     └─► Main Function
         └─► Check return codes
             └─► Exit with code
```

### 5.2 Cleanup Guarantee

```yaml
# action.yml ensures cleanup always runs
- name: Cleanup keystore
  if: always()  # ◄── Runs even if previous steps fail
  shell: bash
  run: ${{ github.action_path }}/scripts/keystore/cleanup-keystore.sh
```

---

## 6. Performance Characteristics

### 6.1 Time Complexity

| Operation | Time Complexity | Factors |
|-----------|----------------|---------|
| Input Validation | O(1) | Fixed checks |
| Package Detection | O(n) | n = gradle file lines |
| Keystore Setup (base64) | O(m) | m = keystore size |
| Keystore Setup (cdn) | O(d) | d = download time |
| Keystore Setup (script) | O(s) | s = script execution |
| File Upload | O(f) | f = file size |
| Cleanup | O(1) | Fixed operations |

### 6.2 Space Complexity

| Component | Space Usage |
|-----------|-------------|
| Scripts | ~1 KB (in memory) |
| Keystore | Variable (typically 2-10 KB) |
| Upload File | Variable (5-150 MB typical) |
| Temp Files | ~Keystore size + response |
| Environment | ~1 KB (variables) |

---

## 7. Integration Points

### 7.1 External Dependencies

```
GitHub Actions Runner
     ├─► bash (required)
     ├─► curl (required)
     ├─► base64 (required)
     ├─► grep/sed (required)
     ├─► keytool (optional, for validation)
     ├─► shred (optional, for secure delete)
     ├─► openssl (optional, for encryption)
     └─► xmllint (future, for manifest parsing)
```

### 7.2 API Integration

**Endpoint:** `https://developer-api.indusappstore.com/devtools`

**Authentication:** Custom "O-Bearer" token

**Request Format:**
```http
POST /{type}/upgrade/{package} HTTP/1.1
Host: developer-api.indusappstore.com
Authorization: O-Bearer {token}
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary...

------WebKitFormBoundary...
Content-Disposition: form-data; name="file"; filename="app-release.aab"
Content-Type: application/octet-stream

[binary data]
------WebKitFormBoundary...
Content-Disposition: form-data; name="releaseNotes"

Release notes text
------WebKitFormBoundary...
[For AAB: keystore file and credentials]
------WebKitFormBoundary...--
```

**Response:**
```json
{
  "status": "success|error",
  "message": "...",
  "data": {
    "packageName": "com.example.app",
    "version": "1.0.0",
    "uploadUrl": "..."
  }
}
```

---

## 8. Extension Points

### 8.1 Adding New Keystore Source

**Steps:**
1. Add new source to `validate_keystore_source()` in validation.sh
2. Add case to `setup_keystore()` in keystore.sh
3. Create handler function (e.g., `fetch_from_vault()`)
4. Add input to action.yml
5. Document in README.md

**Example:**
```bash
# In keystore.sh
fetch_from_vault() {
    local vault_url="$1"
    local vault_token="$2"
    local output_path="$3"
    
    # Implementation
    curl -H "X-Vault-Token: $vault_token" \
         "$vault_url/secret/keystore" \
         -o "$output_path"
}

# In setup_keystore()
case "$keystore_source" in
    # ... existing cases ...
    "vault")
        fetch_from_vault "$INPUT_VAULT_URL" \
                        "$INPUT_VAULT_TOKEN" \
                        "$KEYSTORE_FILE_PATH"
        ;;
esac
```

### 8.2 Adding New File Type

**Steps:**
1. Add type to `validate_file_type()` in validation.sh
2. Add API endpoint in prepare-upload.sh
3. Document in README.md
4. Add example workflow

---

**Document Version:** 1.0  
**Last Updated:** October 23, 2025  
**Status:** Complete
