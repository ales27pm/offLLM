#!/usr/bin/env bash
# Export an Xcode archive to an IPA with the provided export options.
# Usage: export_ipa.sh <archive-path> <export-options-plist> <export-directory>
#
# Environment variables:
#   EXPORT_TEAM_ID            - Preferred team identifier injected into export options
#   DEVELOPMENT_TEAM          - Fallback team identifier when EXPORT_TEAM_ID is unset
#   PROFILE_UUID              - Provisioning profile UUID to resolve a team identifier from disk
#   PRODUCT_BUNDLE_IDENTIFIER - Bundle identifier to associate with the provisioning profile
#   PROFILE_NAME              - Provisioning profile name recorded in export options for signing

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

TMP_EXPORT_OPTS=""

cleanup() {
  if [[ -n "$TMP_EXPORT_OPTS" && -f "$TMP_EXPORT_OPTS" ]]; then
    rm -f "$TMP_EXPORT_OPTS"
  fi
}

trap cleanup EXIT

ensure_export_opts_copy() {
  if [[ -z "$TMP_EXPORT_OPTS" ]]; then
    TMP_EXPORT_OPTS="$(mktemp -t exportOptions.XXXXXX.plist)"
    cp "$EXPORT_OPTS" "$TMP_EXPORT_OPTS"
    EXPORT_OPTS="$TMP_EXPORT_OPTS"
  fi
}

resolve_bundle_identifier_from_archive() {
  local archive="$1"

  if [[ ! -x /usr/libexec/PlistBuddy ]]; then
    return 1
  fi

  local archive_plist
  archive_plist="${archive}/Info.plist"
  if [[ -f "$archive_plist" ]]; then
    local bundle_id
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleIdentifier' "$archive_plist" 2>/dev/null || true)
    if [[ -n "${bundle_id// }" ]]; then
      printf '%s' "$bundle_id"
      return 0
    fi
  fi

  local info_plist
  info_plist="$(find "${archive}/Products/Applications" -maxdepth 2 -name 'Info.plist' 2>/dev/null | head -n 1 || true)"
  if [[ -n "${info_plist// }" && -f "$info_plist" ]]; then
    local bundle_id
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist" 2>/dev/null || true)
    if [[ -n "${bundle_id// }" ]]; then
      printf '%s' "$bundle_id"
      return 0
    fi
  fi

  return 1
}

resolve_team_id_from_profile() {
  local uuid="${PROFILE_UUID:-}"
  if [[ -z "${uuid// }" ]]; then
    return 0
  fi

  local profile_path="$HOME/Library/MobileDevice/Provisioning Profiles/${uuid}.mobileprovision"
  if [[ ! -f "$profile_path" ]]; then
    return 0
  fi

  if ! command -v security >/dev/null 2>&1; then
    echo "::warning ::security command not available; unable to parse provisioning profile for team identifier" >&2
    return 0
  fi

  local plist_tmp
  plist_tmp="$(mktemp)"
  if ! security cms -D -i "$profile_path" >"$plist_tmp" 2>/dev/null; then
    rm -f "$plist_tmp"
    return 0
  fi

  local team_id=""
  if [[ -x /usr/libexec/PlistBuddy ]]; then
    team_id=$(/usr/libexec/PlistBuddy -c 'Print TeamIdentifier:0' "$plist_tmp" 2>/dev/null || true)
  fi

  rm -f "$plist_tmp"

  if [[ -n "${team_id// }" ]]; then
    printf '%s' "$team_id"
  fi

  return 0
}

TEAM_ID="${EXPORT_TEAM_ID:-}"
if [[ -z "${TEAM_ID// }" && -n "${DEVELOPMENT_TEAM:-}" ]]; then
  TEAM_ID="$DEVELOPMENT_TEAM"
fi

if [[ -z "${TEAM_ID// }" ]]; then
  TEAM_ID="$(resolve_team_id_from_profile)"
fi

if [[ -n "${TEAM_ID// }" && -x /usr/libexec/PlistBuddy ]]; then
  ensure_export_opts_copy
  if /usr/libexec/PlistBuddy -c 'Print teamID' "$EXPORT_OPTS" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set teamID $TEAM_ID" "$EXPORT_OPTS" >/dev/null 2>&1 || true
  else
    /usr/libexec/PlistBuddy -c "Add teamID string $TEAM_ID" "$EXPORT_OPTS" >/dev/null 2>&1 || \
      /usr/libexec/PlistBuddy -c "Set teamID $TEAM_ID" "$EXPORT_OPTS" >/dev/null 2>&1 || true
  fi
elif [[ -z "${TEAM_ID// }" ]]; then
  echo "::warning ::No team identifier resolved for export; xcodebuild may fail with 'No Team Found in Archive'" >&2
elif [[ ! -x /usr/libexec/PlistBuddy ]]; then
  echo "::warning ::/usr/libexec/PlistBuddy not available; unable to inject teamID into export options" >&2
fi

BUNDLE_IDENTIFIER="${PRODUCT_BUNDLE_IDENTIFIER:-}" 
if [[ -z "${BUNDLE_IDENTIFIER// }" ]]; then
  BUNDLE_IDENTIFIER="$(resolve_bundle_identifier_from_archive "$ARCHIVE_PATH" || true)"
fi

PROFILE_NAME="${PROFILE_NAME:-}"
if [[ -n "${PROFILE_NAME// }" && -n "${BUNDLE_IDENTIFIER// }" ]]; then
  if command -v plutil >/dev/null 2>&1; then
    ensure_export_opts_copy
    if ! plutil -extract ':provisioningProfiles' xml1 -o - "$EXPORT_OPTS" >/dev/null 2>&1; then
      if ! plutil -replace ':provisioningProfiles' -xml '<dict/>' "$EXPORT_OPTS" >/dev/null 2>&1; then
        echo "::warning ::Failed to initialise provisioningProfiles dictionary in export options" >&2
      fi
    fi

    if ! plutil -replace ":provisioningProfiles:${BUNDLE_IDENTIFIER}" -string "$PROFILE_NAME" "$EXPORT_OPTS" >/dev/null 2>&1; then
      echo "::warning ::Failed to record provisioning profile ${PROFILE_NAME} for ${BUNDLE_IDENTIFIER} in export options" >&2
    fi
  elif [[ -x /usr/libexec/PlistBuddy ]]; then
    echo "::warning ::plutil not available; unable to safely record provisioning profile ${PROFILE_NAME}" >&2
  else
    echo "::warning ::Required tools unavailable; unable to record provisioning profile ${PROFILE_NAME}" >&2
  fi
elif [[ -n "${PROFILE_NAME// }" ]]; then
  echo "::warning ::Provisioning profile ${PROFILE_NAME} provided but bundle identifier could not be determined" >&2
fi

set -x

mkdir -p "$EXPORT_DIR"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTS"

ls -la "$EXPORT_DIR"

set +x
