#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <archive-path> <output-dir> [basename]" >&2
  exit 1
fi

ARCHIVE_PATH="$1"
OUTPUT_DIR="$2"
APP_BASENAME="${3:-}"

if [ ! -d "$ARCHIVE_PATH" ]; then
  echo "::error title=Missing archive::Archive not found at $ARCHIVE_PATH" >&2
  exit 1
fi

APP_DIR="$ARCHIVE_PATH/Products/Applications"
if [ ! -d "$APP_DIR" ]; then
  echo "::error title=No Applications directory::Expected $APP_DIR to exist" >&2
  echo "Archive contents:" >&2
  ls -R "$ARCHIVE_PATH" >&2 || true
  exit 1
fi

APP_PATH=$(find "$APP_DIR" -maxdepth 1 -name '*.app' -print -quit)
if [ -z "$APP_PATH" ]; then
  echo "::error title=No .app in archive::No .app found under $APP_DIR" >&2
  echo "Applications directory contents:" >&2
  ls -R "$APP_DIR" >&2 || true
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
(cd "$(dirname "$APP_PATH")" && /usr/bin/zip -qry "$OUTPUT_DIR/$(basename "$APP_PATH").zip" "$(basename "$APP_PATH")")

if [ -z "$APP_BASENAME" ]; then
  APP_BASENAME="$(basename "$APP_PATH" .app)"
fi

TMP_DIR="$(mktemp -d)"
mkdir -p "$TMP_DIR/Payload"
cp -R "$APP_PATH" "$TMP_DIR/Payload/"
(cd "$TMP_DIR" && /usr/bin/zip -qry "$OUTPUT_DIR/${APP_BASENAME}-device-unsigned.ipa" "Payload")
rm -rf "$TMP_DIR"
