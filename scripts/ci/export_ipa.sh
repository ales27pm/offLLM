#!/usr/bin/env bash
# Export an Xcode archive to an IPA with the provided export options.
# Usage: export_ipa.sh <archive-path> <export-options-plist> <export-directory>

set -euo pipefail
set -x

ARCHIVE_PATH="$1"
EXPORT_OPTS="$2"
EXPORT_DIR="$3"

mkdir -p "$EXPORT_DIR"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTS"

ls -la "$EXPORT_DIR"

set +x
