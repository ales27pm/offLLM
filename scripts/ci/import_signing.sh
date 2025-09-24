#!/usr/bin/env bash
# Import signing assets into a temporary keychain for CI workflows.
#
# Usage: import_signing.sh <p12-path> <p12-password> <mobileprovision-path> <keychain-name-or-path> <keychain-password>
# - Supports keychain arguments that are names, absolute paths, relative paths, or home-relative paths.
# - Emits PROFILE_UUID and KEYCHAIN_PATH for downstream GitHub Actions steps.
# - Enables verbose logging via `set -x` while masking sensitive arguments.

set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "::error ::Expected 5 arguments, received $#" >&2
  exit 1
fi

P12_PATH="$1"
P12_PASSWORD="$2"
MP_PATH="$3"
KC_ARG="$4"
KC_PASS="$5"

# Mask secrets in GitHub Actions logs
echo "::add-mask::$P12_PASSWORD"
echo "::add-mask::$KC_PASS"

if [[ ! -f "$P12_PATH" ]]; then
  echo "::error ::P12 not found at $P12_PATH" >&2
  exit 1
fi

if [[ ! -f "$MP_PATH" ]]; then
  echo "::error ::Provisioning profile not found at $MP_PATH" >&2
  exit 1
fi

resolve_keychain_path() {
  local arg="$1"
  case "$arg" in
    /*)
      printf '%s' "$arg"
      ;;
    ~*|*/*)
      python3 -c 'import os, sys; print(os.path.abspath(os.path.expanduser(sys.argv[1])))' "$arg"
      ;;
    *)
      printf '%s' "$HOME/Library/Keychains/$arg"
      ;;
  esac
}

KC_PATH="$(resolve_keychain_path "$KC_ARG")"
mkdir -p "$(dirname "$KC_PATH")"

log() {
  printf '::notice ::%s\n' "$1"
}

cleanup_tmp_files() {
  if [[ -n "$KEYCHAIN_LIST_TMP" && -f "$KEYCHAIN_LIST_TMP" ]]; then
    rm -f "$KEYCHAIN_LIST_TMP"
  fi
  if [[ -n "$PLIST_TMP" && -f "$PLIST_TMP" ]]; then
    rm -f "$PLIST_TMP"
  fi
}

KEYCHAIN_LIST_TMP=""
PLIST_TMP=""
trap cleanup_tmp_files EXIT

log "Importing signing assets into keychain: $KC_PATH"

set -x

security delete-keychain "$KC_PATH" >/dev/null 2>&1 || true

set +x
security create-keychain -p "$KC_PASS" "$KC_PATH"
set -x

set +x
security set-keychain-settings -lut 21600 "$KC_PATH"
set -x

set +x
security unlock-keychain -p "$KC_PASS" "$KC_PATH"
set -x

set +x
security import "$P12_PATH" -k "$KC_PATH" -P "$P12_PASSWORD" -f pkcs12 -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/xcodebuild
set -x

set +x
security set-key-partition-list -S apple-tool:,apple: -s -k "$KC_PASS" "$KC_PATH" >/dev/null 2>&1 || true
set -x

KEYCHAIN_LIST_TMP="$(mktemp)"
RESTORE_KEYCHAINS=("$KC_PATH")
if security list-keychains -d user >"$KEYCHAIN_LIST_TMP"; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim leading whitespace and surrounding quotes.
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*"//' -e 's/"$//')"
    [[ -z "$line" || "$line" == "$KC_PATH" ]] && continue
    RESTORE_KEYCHAINS+=("$line")
  done <"$KEYCHAIN_LIST_TMP"
else
  log "Unable to read existing keychain search list; defaulting to $KC_PATH only"
fi

security list-keychains -d user -s "${RESTORE_KEYCHAINS[@]}"

security default-keychain -s "$KC_PATH"

PP_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$PP_DIR"
PLIST_TMP="$(mktemp)"

set +x
security cms -D -i "$MP_PATH" > "$PLIST_TMP"
set -x

UUID=$(/usr/libexec/PlistBuddy -c 'Print UUID' "$PLIST_TMP")
PROFILE_NAME=$(/usr/libexec/PlistBuddy -c 'Print Name' "$PLIST_TMP")
if [[ -z "$UUID" || -z "$PROFILE_NAME" ]]; then
  set +x
  echo "::error ::Failed to resolve provisioning profile metadata" >&2
  exit 1
fi
cp "$MP_PATH" "$PP_DIR/$UUID.mobileprovision"
rm -f "$PLIST_TMP"

set +x
echo "PROFILE_UUID=$UUID" >> "$GITHUB_ENV"
echo "PROFILE_NAME=$PROFILE_NAME" >> "$GITHUB_ENV"
echo "KEYCHAIN_PATH=$KC_PATH" >> "$GITHUB_ENV"
set -x

log "Installed provisioning profile $PROFILE_NAME ($UUID)"

# Restore xtrace to default off for downstream scripts.
set +x
