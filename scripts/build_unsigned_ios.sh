#!/usr/bin/env bash
set -euo pipefail

# Simple unsigned iOS Simulator build helper. Assumes pods and project are ready.

ROOT="$(pwd)"
IOS_DIR="ios"
DERIVED="${IOS_DIR}/build"

: "${SCHEME:?SCHEME env var required}"
: "${WORKSPACE:?WORKSPACE env var required}"
IOS_DESTINATION="${IOS_DESTINATION:-}"

RESULT_BUNDLE="${IOS_DIR}/${SCHEME}.xcresult"
LOG_FILE="${IOS_DIR}/xcodebuild.log"

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
SDK="iphonesimulator"

XCODE_CMD=(xcodebuild
  -workspace "$WORKSPACE"
  -scheme "$SCHEME"
  -configuration Release
  -sdk "$SDK"
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_ENTITLEMENTS=
  CODE_SIGN_STYLE=Manual
  -derivedDataPath "$DERIVED"
  -resultBundlePath "$RESULT_BUNDLE"
)
if [ -n "${IOS_DESTINATION}" ]; then
  XCODE_CMD+=(-destination "${IOS_DESTINATION}")
fi
"${XCODE_CMD[@]}" | tee "$LOG_FILE"

APP_PATH="${DERIVED}/Build/Products/Release-iphonesimulator/${SCHEME}.app"
if [ ! -d "${APP_PATH}" ]; then
  echo "error: expected app bundle at ${APP_PATH}" >&2
  exit 1
fi
ditto -ck --sequesterRsrc --keepParent "$APP_PATH" "${IOS_DIR}/${SCHEME}-Simulator.zip"

echo "✅  Simulator build finished."
