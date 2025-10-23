#!/bin/bash
# Copyright 2025 PhonePe Limited
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

echo "📋 Preparing file for upload..."

# Use the provided file path
UPLOAD_FILE_PATH="${INPUT_FILE_PATH}"

echo "UPLOAD_FILE_PATH=${UPLOAD_FILE_PATH}" >> "$GITHUB_ENV"

if [[ ! -f "${UPLOAD_FILE_PATH}" ]]; then
  echo "❌ Error: File not found at ${UPLOAD_FILE_PATH}"
  exit 1
fi

BASE_URL="https://developer-api.indusappstore.com/devtools"
case "$INPUT_FILE_TYPE" in
  "aab")
    echo "API_URL=${BASE_URL}/aab/upgrade/$PACKAGE_NAME" >> "$GITHUB_ENV"
    ;;
  "apks")
    echo "API_URL=${BASE_URL}/apks/upgrade/$PACKAGE_NAME" >> "$GITHUB_ENV"
    ;;
  *)
    # Default case (same as apk)
    echo "API_URL=${BASE_URL}/apk/upgrade/$PACKAGE_NAME" >> "$GITHUB_ENV"
    ;;
esac

log_debug "✅ Upload preparation complete. File path: ${UPLOAD_FILE_PATH}"
log_debug "✅ API URL set to: $(grep API_URL "$GITHUB_ENV" | cut -d= -f2)"
