#!/bin/bash
# Copyright 2025 PhonePe Limited
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"
PACKAGE_NAME="$INPUT_PACKAGE_NAME"

if [[ -z "$PACKAGE_NAME" && "$INPUT_AUTO_DETECT_PACKAGE" == "true" ]]; then
  log_debug "Attempting to auto-detect package name from build.gradle..."
  
  if [[ -f "app/build.gradle" ]]; then
    DETECTED_PACKAGE=$(grep -o "applicationId ['\"].*['\"]" app/build.gradle | sed -E "s/applicationId ['\"]([^'\"]*)['\"].*/\1/")
  elif [[ -f "app/build.gradle.kts" ]]; then
    DETECTED_PACKAGE=$(grep -o 'applicationId = ".*"' app/build.gradle.kts | sed -E 's/applicationId = "(.*)"/\1/')
  fi
  
  if [[ -n "$DETECTED_PACKAGE" ]]; then
    log_debug "Detected package name: $DETECTED_PACKAGE"
    PACKAGE_NAME="$DETECTED_PACKAGE"
  else
    echo "Error: Could not auto-detect package name and none was provided"
    exit 1
  fi
fi

if [[ -z "$PACKAGE_NAME" ]]; then
  echo "Error: Package name is required"
  exit 1
fi

echo "PACKAGE_NAME=$PACKAGE_NAME" >> "$GITHUB_ENV"
echo "✓ Package name set to: $PACKAGE_NAME"
