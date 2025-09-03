#!/usr/bin/env bash
set -euo pipefail

# Simple unsigned iOS Simulator build helper. Assumes pods and project are ready.

ROOT="$(pwd)"
IOS_DIR="ios"
BUILD_DIR="${BUILD_DIR:-build}"
DERIVED_DATA="${DERIVED_DATA:-${BUILD_DIR}/derived-data}"

: "${SCHEME:?SCHEME env var required}"
: "${WORKSPACE:?WORKSPACE env var required}"
IOS_DESTINATION="${IOS_DESTINATION:-}"

RESULT_BUNDLE="${RESULT_BUNDLE:-${BUILD_DIR}/${SCHEME}.xcresult}"
LOG_FILE="${LOG_FILE:-${BUILD_DIR}/xcodebuild.log}"

# Ensure output directories exist (supports custom paths)
mkdir -p "$BUILD_DIR"
mkdir -p "$(dirname "$RESULT_BUNDLE")"
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$DERIVED_DATA"

echo "▶️  Unsigned iOS build starting…"
echo "Environment:"
echo "  SCHEME=${SCHEME}"
echo "  WORKSPACE=${WORKSPACE}"
if [ -n "${IOS_DESTINATION}" ]; then
  echo "  IOS_DESTINATION=${IOS_DESTINATION}"
fi
if [ -n "${IOS_SIM_OS:-}" ]; then
  echo "  IOS_SIM_OS=${IOS_SIM_OS}"
fi
echo

XCODE_CMD=(xcodebuild
  -workspace "$WORKSPACE"
  -scheme "$SCHEME"
  -configuration Release
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_ENTITLEMENTS=
  CODE_SIGN_STYLE=Manual
  -derivedDataPath "$DERIVED_DATA"
  -resultBundlePath "$RESULT_BUNDLE"
)
if [ -n "${IOS_DESTINATION}" ]; then
  XCODE_CMD+=(-destination "${IOS_DESTINATION}")
fi
"${XCODE_CMD[@]}" | tee "$LOG_FILE"

APP_PATH="${DERIVED_DATA}/Build/Products/Release-iphonesimulator/${SCHEME}.app"
if [ ! -d "${APP_PATH}" ]; then
  echo "error: expected app bundle at ${APP_PATH}" >&2
  exit 1
fi
ditto -ck --sequesterRsrc --keepParent "$APP_PATH" "${IOS_DIR}/${SCHEME}-Simulator.zip"

echo "✅  Simulator build finished."
