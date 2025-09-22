#!/usr/bin/env bash
# Ensures the app bundle contains only arm64-ready binaries (no arm64e slices).
set -euo pipefail

APP_DIR="${1:-}"

if [ -z "${APP_DIR}" ]; then
  echo "::error title=verify-arm-slices::Path to .app bundle required" >&2
  exit 64
fi

if [ ! -d "${APP_DIR}" ]; then
  echo "::error title=verify-arm-slices::'${APP_DIR}' does not exist" >&2
  exit 65
fi

has_error=0

check_binary() {
  local binary="$1"
  local archs=""

  if command -v lipo >/dev/null 2>&1; then
    archs=$(lipo -info "$binary" 2>/dev/null || true)
  fi

  if [ -z "${archs}" ] && command -v otool >/dev/null 2>&1; then
    archs=$(otool -hv "$binary" 2>/dev/null || true)
  fi

  if [ -z "${archs}" ]; then
    return
  fi

  if printf '%s\n' "${archs}" | grep -Eiq '\barm64e\b'; then
    echo "::error title=arm64e slice detected::${binary} contains an arm64e architecture slice" >&2
    has_error=1
  fi
}

while IFS= read -r -d '' candidate; do
  # Skip symlinks so we only scan real binaries once.
  if [ -L "${candidate}" ]; then
    continue
  fi
  check_binary "${candidate}"
done < <(find "${APP_DIR}" -type f \( -perm -u=x -o -perm -g=x -o -perm -o=x \) -print0)

exit "${has_error}"
