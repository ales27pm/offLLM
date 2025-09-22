#!/usr/bin/env bash
# Ensures the packaged monGARS Payload never bundles Hermes as a dynamic framework.
# Shipping both the static CocoaPods build and a bundled hermes.framework causes
# the ObjC runtime to abort while loading duplicate symbols during dyld's
# map_images phase. CI calls this helper after creating Payload/monGARS.app (or
# directly on the built .app/.ipa) to guarantee Hermes stays statically linked.
set -euo pipefail

INPUT_PATH="${1:-}"
APP_NAME_HINT="${2:-monGARS}"

if [ -z "${INPUT_PATH}" ]; then
  echo "::error title=verify-hermes-static::Payload, .app, or .ipa path not provided" >&2
  exit 64
fi

if [ ! -e "${INPUT_PATH}" ]; then
  echo "::error title=verify-hermes-static::'${INPUT_PATH}' does not exist" >&2
  exit 65
fi

TEMP_DIR=""
cleanup() {
  if [ -n "${TEMP_DIR}" ] && [ -d "${TEMP_DIR}" ]; then
    rm -rf "${TEMP_DIR}"
  fi
}
trap cleanup EXIT

INPUT_ROOT="${INPUT_PATH}"
if [ -f "${INPUT_PATH}" ]; then
  case "${INPUT_PATH}" in
    *.ipa|*.zip)
      if ! command -v unzip >/dev/null 2>&1; then
        echo "::error title=verify-hermes-static::unzip not found; unable to inspect ${INPUT_PATH}" >&2
        exit 69
      fi
      TEMP_DIR=$(mktemp -d)
      unzip -qq "${INPUT_PATH}" -d "${TEMP_DIR}"
      if [ -d "${TEMP_DIR}/Payload" ]; then
        INPUT_ROOT="${TEMP_DIR}/Payload"
      else
        INPUT_ROOT="${TEMP_DIR}"
      fi
      ;;
    *)
      # Regular file but not an IPA/zip; nothing to inspect.
      echo "::error title=verify-hermes-static::Unsupported file type '${INPUT_PATH}'. Provide a Payload directory, .app bundle, or .ipa archive." >&2
      exit 69
      ;;
  esac
fi

resolve_app_dir() {
  local path="$1"
  local app_name="$2"

  if [ -d "${path}" ] && [[ "${path}" == *.app ]]; then
    printf '%s' "${path%/}"
    return 0
  fi

  local root="${path%/}"
  if [ -d "${root}/${app_name}.app" ]; then
    printf '%s' "${root}/${app_name}.app"
    return 0
  fi

  local discovered
  discovered=$(find "${root}" -maxdepth 1 -type d -name '*.app' -print -quit 2>/dev/null || true)
  if [ -n "${discovered}" ]; then
    printf '%s' "${discovered%/}"
    return 0
  fi

  return 1
}

APP_DIR=$(resolve_app_dir "${INPUT_ROOT}" "${APP_NAME_HINT}" || true)

if [ -z "${APP_DIR}" ] || [ ! -d "${APP_DIR}" ]; then
  echo "::error title=verify-hermes-static::App bundle not found near '${INPUT_ROOT}'" >&2
  if [ -d "${INPUT_ROOT}" ]; then
    ls -la "${INPUT_ROOT}" >&2 || true
  fi
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

# Look for hermes.framework anywhere under the bundle in case a resign step
# copied it outside of the top-level Frameworks directory.
if find "${APP_DIR}" -type d \( -name 'hermes.framework' -o -name 'Hermes.framework' \) -print -quit | grep -q .; then
  echo "::error title=verify-hermes-static::Detected an embedded hermes.framework somewhere inside ${APP_DIR}. Hermes must remain statically linked via CocoaPods." >&2
  exit 70
fi

INFO_PLIST="${APP_DIR}/Info.plist"
BUNDLE_EXECUTABLE="${APP_NAME_HINT}"
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
exit 0
