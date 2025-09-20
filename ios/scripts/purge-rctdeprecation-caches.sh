#!/usr/bin/env bash
set -euo pipefail

log_info() {
  printf '[purge-rctdeprecation] %s\n' "$1"
}

log_warn() {
  printf '[purge-rctdeprecation] %s\n' "$1" >&2
}

if [ -z "${BASH_VERSION:-}" ]; then
  log_warn "This script requires bash"
  exit 1
fi

if [ "${BASH_VERSINFO[0]}" -lt 3 ]; then
  log_warn "Bash 3.0 or newer is required"
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
project_dir_default="$(cd "${script_dir}/.." && pwd -P)"
project_dir_source="${PROJECT_DIR:-$project_dir_default}"

if ! PROJECT_DIR="$(cd "${project_dir_source}" 2>/dev/null && pwd -P)"; then
  log_warn "Unable to resolve project directory from ${project_dir_source}; skipping purge"
  exit 0
fi

if ! PROJECT_ROOT="$(cd "${PROJECT_DIR}/.." 2>/dev/null && pwd -P)"; then
  log_warn "Unable to resolve project root from ${PROJECT_DIR}/..; skipping purge"
  exit 0
fi

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

  local probe="$raw"
  if [ ! -d "$probe" ]; then
    probe="$(dirname "$probe")"
    if [ ! -d "$probe" ]; then
      return 0
    fi
  fi

  local canonical
  if ! canonical="$(cd "$probe" 2>/dev/null && pwd -P)"; then
    log_warn "Skipping unreadable derived data root $probe"
    return 0
  fi

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
  log_info "No derived data roots to inspect"
  exit 0
fi

safe_remove_dir() {
  local target="$1"
  if rm -rf "$target"; then
    return 0
  fi

  log_warn "Warning: failed to remove directory $target"
  return 1
}

safe_remove_file() {
  local target="$1"
  if rm -f "$target"; then
    return 0
  fi

  log_warn "Warning: failed to remove file $target"
  return 1
}

remove_matches() {
  local description="$1"
  local root="$2"
  shift 2

  if [ ! -d "$root" ]; then
    return 0
  fi

  local status=0

  while IFS= read -r -d '' path; do
    if [ -z "$path" ]; then
      continue
    fi

    if [ -d "$path" ]; then
      log_info "Removing $description directory $path"
      safe_remove_dir "$path" || status=1
    else
      log_info "Removing $description file $path"
      safe_remove_file "$path" || status=1
    fi
  done < <(find "$root" "$@" -print0 2>/dev/null || true)

  return "$status"
}

overall_status=0

for root in "${candidate_roots[@]}"; do
  remove_matches "bridging header cache" "$root" -type f -name "${APP_TARGET}-Bridging-Header-swift*.pch" || overall_status=1
  remove_matches "module cache" "$root" -path "*ModuleCache.noindex*" -name "*${MODULE_NAME}*" || overall_status=1
  remove_matches "legacy module map" "$root" -type f -name "${LEGACY_MODULE_MAP_NAME}" || overall_status=1
done

if [ "$overall_status" -ne 0 ]; then
  log_warn "Completed with warnings"
fi

exit 0
