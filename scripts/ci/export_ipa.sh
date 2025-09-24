#!/usr/bin/env bash
# Export an Xcode archive to an IPA with the provided export options.
# Usage: export_ipa.sh <archive-path> <export-options-plist> <export-directory>

set -euo pipefail
if [[ $# -ne 3 ]]; then
  echo "::error ::Usage: $0 <archive-path> <export-options-plist> <export-directory>" >&2
  exit 2
fi

ARCHIVE_PATH="$1"
EXPORT_OPTS="$2"
EXPORT_DIR="$3"

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "::error ::Archive not found (expected directory): $ARCHIVE_PATH" >&2
  exit 1
fi

if [[ ! -f "$EXPORT_OPTS" ]]; then
  echo "::error ::exportOptions.plist not found: $EXPORT_OPTS" >&2
  exit 1
fi

set -x

mkdir -p "$EXPORT_DIR"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTS"

ls -la "$EXPORT_DIR"

set +x
