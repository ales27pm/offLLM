#!/usr/bin/env bash
# Fails the build if unexpected dynamic frameworks appear in the app bundle.
# We intentionally keep Hermes and the rest of React Native statically linked
# through CocoaPods, so the Frameworks directory should remain empty unless a
# new allowlisted dependency is introduced.
set -euo pipefail

APP_DIR="${1:-}"

if [ -z "${APP_DIR}" ]; then
  echo "::error title=guard-no-dynamic-frameworks::Path to .app bundle required" >&2
  exit 64
fi

if [ ! -d "${APP_DIR}" ]; then
  echo "::error title=guard-no-dynamic-frameworks::'${APP_DIR}' does not exist" >&2
  exit 65
fi

FRAMEWORKS_DIR="${APP_DIR%/}/Frameworks"
ALLOWLIST_REGEX='^( )$'

if [ -d "${FRAMEWORKS_DIR}" ] && [ -n "$(ls -A "${FRAMEWORKS_DIR}" 2>/dev/null)" ]; then
  found=()
  while IFS= read -r fw; do
    found+=("${fw}")
  done < <(find "${FRAMEWORKS_DIR}" -maxdepth 1 -type d -name '*.framework' -exec basename {} \; | sort)

  if [ "${#found[@]}" -eq 0 ]; then
    # Non-framework contents (e.g. empty directory) — nothing to report.
    exit 0
  fi

  printf 'Found frameworks in %s:%s' "${FRAMEWORKS_DIR}" "\n" >&2
  for fw in "${found[@]}"; do
    printf '  %s%s' "${fw}" "\n" >&2
  done

  joined=$(printf '%s ' "${found[@]}")
  if ! printf '%s\n' "${joined}" | grep -Eq "${ALLOWLIST_REGEX}"; then
    echo "::error title=Unexpected dynamic frameworks::App bundle contains dynamic frameworks that must be removed or explicitly allowlisted." >&2
    exit 66
  fi
fi

exit 0
