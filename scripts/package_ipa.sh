#!/usr/bin/env bash
set -euo pipefail
ARCHIVE_PATH="${1:-build/DerivedData/Archive.xcarchive}"
OUT_DIR="${2:-build}"
APP_NAME_HINT="${3:-}"
if [ ! -d "$ARCHIVE_PATH" ]; then
  echo "::error title=Archive not found::'$ARCHIVE_PATH' does not exist (archive failed)."
  exit 66
fi
APP_DIR="${ARCHIVE_PATH}/Products/Applications"
if [ ! -d "$APP_DIR" ]; then
  echo "::error title=No Applications inside archive::'$APP_DIR' missing (compile/signing probably failed)."
  exit 67
fi
if [ -n "$APP_NAME_HINT" ] && [ -d "$APP_DIR/$APP_NAME_HINT.app" ]; then
  APP_PATH="$APP_DIR/$APP_NAME_HINT.app"
else
  APP_PATH="$(/usr/bin/find "$APP_DIR" -maxdepth 1 -name '*.app' -print -quit || true)"
fi
if [ -z "${APP_PATH:-}" ] || [ ! -d "$APP_PATH" ]; then
  ls -la "$APP_DIR" || true
  echo "::error title=.app not found in archive::No .app under $APP_DIR."
  exit 68
fi
mkdir -p "$OUT_DIR"
( cd "$(dirname "$APP_PATH")" && /usr/bin/zip -qry "$PWD/${OUT_DIR}/$(basename "$APP_PATH").zip" "$(basename "$APP_PATH")" )
APP_BASENAME="$(basename "$APP_PATH" .app)"
TMP="$(mktemp -d)"; mkdir -p "$TMP/Payload"
cp -R "$APP_PATH" "$TMP/Payload/"
( cd "$TMP" && /usr/bin/zip -qry "$PWD/${OUT_DIR}/${APP_BASENAME}-device-unsigned.ipa" "Payload" )
mv "$TMP/${OUT_DIR}/${APP_BASENAME}-device-unsigned.ipa" "$OUT_DIR/" || true
rm -rf "$TMP"
echo "::notice title=Packaging complete::${OUT_DIR}/${APP_BASENAME}-device-unsigned.ipa"

