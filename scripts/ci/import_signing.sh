#!/usr/bin/env bash
# import_signing.sh — Prepare a temporary keychain and install signing assets for CI builds.
#
# Arguments:
#   1. Path to the .p12 certificate file
#   2. Password for the .p12 certificate
#   3. Path to the provisioning profile (.mobileprovision)
#   4. Name of the keychain to create/use
#   5. Password for the temporary keychain
#
# The script outputs PROFILE_UUID, PROFILE_NAME, ORIG_KEYCHAINS_B64, and
# ORIG_DEFAULT_KEYCHAIN to $GITHUB_ENV so downstream workflow steps can reference
# them during signing and cleanup.

set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage: import_signing.sh <p12-path> <p12-password> <provision-path> <keychain-name> <keychain-password>
USAGE
}

log() {
  printf '[import_signing] %s\n' "$*"
}

if [[ $# -ne 5 ]]; then
  usage
  exit 1
fi

P12_PATH=$1
P12_PASSWORD=$2
MOBILEPROVISION_PATH=$3
KEYCHAIN_NAME=$4
KEYCHAIN_PASSWORD=$5

if [[ ! -f "$P12_PATH" ]]; then
  echo "Certificate not found: $P12_PATH" >&2
  exit 1
fi

if [[ ! -f "$MOBILEPROVISION_PATH" ]]; then
  echo "Provisioning profile not found: $MOBILEPROVISION_PATH" >&2
  exit 1
fi

log "Creating temporary keychain $KEYCHAIN_NAME"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security set-keychain-settings -lut 21600 "$KEYCHAIN_NAME"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"

log "Capturing existing keychain search list"
ORIG_KEYCHAIN_ARRAY=()
while IFS= read -r line; do
  parsed=$(printf '%s' "$line" | sed 's/^[ \t]*//' | tr -d '"')
  if [[ -n "$parsed" ]]; then
    ORIG_KEYCHAIN_ARRAY+=("$parsed")
  fi
done < <(security list-keychains -d user)
ORIG_DEFAULT_KEYCHAIN=$(security default-keychain | tr -d '"')
ORIG_KEYCHAINS_JOINED=""
if (( ${#ORIG_KEYCHAIN_ARRAY[@]} > 0 )); then
  for keychain in "${ORIG_KEYCHAIN_ARRAY[@]}"; do
    ORIG_KEYCHAINS_JOINED+="$keychain"$'\n'
  done
fi
ORIG_KEYCHAINS_B64=$(printf '%s' "$ORIG_KEYCHAINS_JOINED" | python3 - <<'PY'
import base64, sys
payload = sys.stdin.read().encode()
sys.stdout.write(base64.b64encode(payload).decode())
PY
)

{
  echo "ORIG_KEYCHAINS_B64=$ORIG_KEYCHAINS_B64"
  echo "ORIG_DEFAULT_KEYCHAIN=$ORIG_DEFAULT_KEYCHAIN"
} >> "$GITHUB_ENV"

log "Importing signing certificate"
security import "$P12_PATH" -k "$KEYCHAIN_NAME" -P "$P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME" || true

log "Updating keychain search path"
security list-keychains -d user -s "$KEYCHAIN_NAME" "${ORIG_KEYCHAIN_ARRAY[@]}"
security default-keychain -s "$KEYCHAIN_NAME"

log "Installing provisioning profile"
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$PROFILE_DIR"
# shellcheck disable=SC2317 # false positive: trap handler defined below is used by EXIT trap
cleanup_plist() {
  rm -f "$PLIST_TMP"
}

PLIST_TMP=$(mktemp)
trap cleanup_plist EXIT

security cms -D -i "$MOBILEPROVISION_PATH" > "$PLIST_TMP"
PROFILE_UUID=$(/usr/libexec/PlistBuddy -c 'Print UUID' "$PLIST_TMP")
PROFILE_NAME=$(/usr/libexec/PlistBuddy -c 'Print Name' "$PLIST_TMP")
cp "$MOBILEPROVISION_PATH" "$PROFILE_DIR/$PROFILE_UUID.mobileprovision"

{
  echo "PROFILE_UUID=$PROFILE_UUID"
  echo "PROFILE_NAME=$PROFILE_NAME"
} >> "$GITHUB_ENV"

log "Provisioning profile $PROFILE_NAME ($PROFILE_UUID) installed"

exit 0
