#!/usr/bin/env bash
# Ensures the packaged monGARS Payload never bundles Hermes as a dynamic framework.
# Shipping both the static CocoaPods build and a bundled hermes.framework causes
# the ObjC runtime to abort while loading duplicate symbols during dyld's
# map_images phase. CI calls this helper after creating Payload/monGARS.app to
# guarantee Hermes stays statically linked.
set -euo pipefail

PAYLOAD_ROOT="${1:-}"
APP_NAME="${2:-monGARS}"

if [ -z "${PAYLOAD_ROOT}" ]; then
  echo "::error title=verify-hermes-static::Payload directory not provided" >&2
  exit 64
fi

if [ ! -d "${PAYLOAD_ROOT}" ]; then
  echo "::error title=verify-hermes-static::Payload directory '${PAYLOAD_ROOT}' not found" >&2
  exit 65
fi

APP_DIR="${PAYLOAD_ROOT%/}/${APP_NAME}.app"
if [ ! -d "${APP_DIR}" ]; then
  echo "::error title=verify-hermes-static::App bundle '${APP_DIR}' not found" >&2
  ls -la "${PAYLOAD_ROOT}" >&2 || true
  exit 66
fi

FRAMEWORKS_DIR="${APP_DIR}/Frameworks"
if [ -d "${FRAMEWORKS_DIR}" ]; then
  for candidate in hermes.framework Hermes.framework; do
    if [ -e "${FRAMEWORKS_DIR}/${candidate}" ]; then
      echo "::error title=verify-hermes-static::${candidate} must not be embedded. Hermes is linked statically via CocoaPods; remove the dynamic framework." >&2
      exit 70
    fi
  done
fi

INFO_PLIST="${APP_DIR}/Info.plist"
BUNDLE_EXECUTABLE="${APP_NAME}"
if [ -f "${INFO_PLIST}" ]; then
  EXECUTABLE_FROM_PLIST=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${INFO_PLIST}" 2>/dev/null || true)
  if [ -n "${EXECUTABLE_FROM_PLIST}" ]; then
    BUNDLE_EXECUTABLE="${EXECUTABLE_FROM_PLIST}"
  fi
fi

APP_BINARY="${APP_DIR}/${BUNDLE_EXECUTABLE}"
if [ ! -f "${APP_BINARY}" ]; then
  APP_BINARY=$(find "${APP_DIR}" -maxdepth 1 -type f -perm -111 -print -quit)
fi

if [ -z "${APP_BINARY}" ] || [ ! -f "${APP_BINARY}" ]; then
  echo "::error title=verify-hermes-static::Unable to locate executable inside ${APP_DIR}" >&2
  exit 67
fi

if command -v xcrun >/dev/null 2>&1; then
  OTOOL_BIN=$(xcrun --find otool 2>/dev/null || true)
else
  OTOOL_BIN=""
fi
if [ -z "${OTOOL_BIN}" ]; then
  OTOOL_BIN=$(command -v otool || true)
fi
if [ -z "${OTOOL_BIN}" ]; then
  echo "::error title=verify-hermes-static::otool not found on PATH" >&2
  exit 68
fi

if "${OTOOL_BIN}" -L "${APP_BINARY}" | grep -Fi 'hermes.framework' >/dev/null; then
  echo "::error title=verify-hermes-static::App binary links against hermes.framework; ensure Hermes is provided only by the static CocoaPods build." >&2
  exit 70
fi

echo "Hermes static linkage verified for ${APP_DIR}" >&2
