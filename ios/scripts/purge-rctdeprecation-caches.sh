#!/usr/bin/env bash
set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
  echo "[purge-rctdeprecation] This script requires bash" >&2
  exit 1
fi

if [ "${BASH_VERSINFO[0]}" -lt 3 ]; then
  echo "[purge-rctdeprecation] Bash 3.0 or newer is required" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
project_dir_default="$(cd "${script_dir}/.." && pwd -P)"
PROJECT_DIR="${PROJECT_DIR:-$project_dir_default}"
PROJECT_DIR="$(cd "${PROJECT_DIR}" && pwd -P)"
PROJECT_ROOT="$(cd "${PROJECT_DIR}/.." && pwd -P)"

APP_TARGET="${APP_TARGET:-monGARS}"
MODULE_NAME="${MODULE_NAME:-RCTDeprecation}"
LEGACY_MODULE_MAP_NAME="${LEGACY_MODULE_MAP_NAME:-RCTDeprecation.modulemap}"

candidate_roots=()

append_candidate() {
  local raw="$1"

  if [ -z "$raw" ]; then
    return 0
  fi

  if [ ! -e "$raw" ]; then
    return 0
  fi

  if [ -d "$raw" ]; then
    :
  else
    raw="$(dirname "$raw")"
    if [ ! -d "$raw" ]; then
      return 0
    fi
  fi

  local canonical
  canonical="$(cd "$raw" && pwd -P)"

  local existing
  for existing in "${candidate_roots[@]}"; do
    if [ "$existing" = "$canonical" ]; then
      return 0
    fi
  done

  candidate_roots+=("$canonical")
}

append_candidate "${DERIVED_DATA_DIR:-}"
append_candidate "${OBJROOT:-}"
append_candidate "${SYMROOT:-}"
append_candidate "${PROJECT_ROOT}/build/DerivedData"
append_candidate "${HOME:-}/Library/Developer/Xcode/DerivedData"

if [ "${#candidate_roots[@]}" -eq 0 ]; then
  echo "[purge-rctdeprecation] No derived data roots to inspect" >&2
  exit 0
fi

remove_matches() {
  local description="$1"
  local root="$2"
  shift 2

  if [ ! -d "$root" ]; then
    return 0
  fi

  find "$root" "$@" -print0 2>/dev/null | while IFS= read -r -d '' path; do
    if [ -z "$path" ]; then
      continue
    fi

    if [ -d "$path" ]; then
      echo "[purge-rctdeprecation] Removing $description directory $path"
      rm -rf "$path"
    else
      echo "[purge-rctdeprecation] Removing $description file $path"
      rm -f "$path"
    fi
  done || :
}

for root in "${candidate_roots[@]}"; do
  remove_matches "bridging header cache" "$root" -type f -name "${APP_TARGET}-Bridging-Header-swift*.pch"
  remove_matches "module cache" "$root" -path "*ModuleCache.noindex*" -name "*${MODULE_NAME}*"
  remove_matches "legacy module map" "$root" -type f -name "${LEGACY_MODULE_MAP_NAME}"
done

exit 0
