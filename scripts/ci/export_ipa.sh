#!/usr/bin/env bash
# export_ipa.sh — Wrapper around `xcodebuild -exportArchive` for CI.
#
# Arguments:
#   1. Path to the .xcarchive to export
#   2. Path to the exportOptions.plist file
#   3. Output directory for the exported IPA

set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage: export_ipa.sh <archive-path> <export-options> <export-dir>
USAGE
}

log() {
  printf '[export_ipa] %s\n' "$*"
}

if [[ $# -ne 3 ]]; then
  usage
  exit 1
fi

ARCHIVE_PATH=$1
EXPORT_OPTIONS=$2
EXPORT_DIR=$3

if [[ ! -d "$ARCHIVE_PATH" ]]; then
  echo "Archive not found: $ARCHIVE_PATH" >&2
  exit 1
fi

if [[ ! -f "$EXPORT_OPTIONS" ]]; then
  echo "exportOptions.plist not found: $EXPORT_OPTIONS" >&2
  exit 1
fi

log "Exporting IPA to $EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

log "Export complete"
ls -la "$EXPORT_DIR"
