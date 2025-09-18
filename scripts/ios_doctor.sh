#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"

require_command() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "❌ $tool not available. Install it before running the doctor."
    exit 1
  fi
}

print_environment() {
  echo "=== monGARS iOS Doctor ==="
  echo "Date: $(date)"
  echo "Xcode: $(xcodebuild -version | head -1)"
  echo "Node: $(node --version)"
  echo "Ruby: $(ruby --version)"
  echo "Pod: $(pod --version)"
}

run_js_checks() {
  echo "Running JavaScript lint/tests..."
  (
    cd "$ROOT_DIR"
    npm run lint
    npm test
  )
}

sync_ios_dependencies() {
  echo "Regenerating iOS project files..."
  (
    cd "$IOS_DIR"
    xcodegen generate
    bundle exec pod install --repo-update
  )
}

collect_codegen_duplicates() {
  local generated_root="$IOS_DIR/build/generated/ios"
  [[ -d "$generated_root" ]] || return 0

  find "$generated_root" -type f \
    \( -name '*JSI-generated*' -o -name '*Spec-generated*' \) -print0 2>/dev/null |
    while IFS= read -r -d '' artifact; do
      local manual="${artifact/-generated/}"
      if [[ -e "$manual" ]]; then
        printf '%s\0' "$artifact"
      fi
    done
}

clean_codegen_duplicates() {
  echo "Scanning generated specs for duplicates..."
  local duplicates=()
  if mapfile -d '' duplicates < <(collect_codegen_duplicates || true); then
    :
  fi

  local count=${#duplicates[@]}
  if ((count > 0)); then
    echo "⚠️  Found $count duplicate codegen artifacts. Removing and reinstalling pods..."
    for path in "${duplicates[@]}"; do
      rm -f "$path"
    done
    (
      cd "$IOS_DIR"
      bundle exec pod install
    )
  else
    echo "No duplicate codegen artifacts detected."
  fi
}

purge_xcode_caches() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Skipping DerivedData purge (non-macOS environment)."
    return
  fi

  local derived_dir="$HOME/Library/Developer/Xcode/DerivedData"
  local module_cache="$HOME/Library/Developer/Xcode/DerivedData/ModuleCache.noindex"

  if [[ -d "$derived_dir" ]]; then
    echo "Removing DerivedData at $derived_dir..."
    rm -rf "$derived_dir"
  fi

  if [[ -d "$module_cache" ]]; then
    echo "Removing ModuleCache at $module_cache..."
    rm -rf "$module_cache"
  fi
}

dry_run_archive() {
  echo "Dry-run archive..."
  if ! (
    cd "$IOS_DIR" && \
      xcodebuild -workspace monGARS.xcworkspace -scheme monGARS \
        -configuration Release \
        -destination "generic/platform=iOS" \
        CODE_SIGNING_ALLOWED=NO \
        -dry-run clean archive
  ); then
    echo "❌ Archive dry-run failed. Check logs."
    exit 1
  fi
}

main() {
  require_command xcodebuild
  require_command node
  require_command ruby
  require_command pod
  require_command xcodegen

  print_environment
  run_js_checks
  sync_ios_dependencies
  clean_codegen_duplicates
  purge_xcode_caches
  dry_run_archive

  echo "✅ Doctor passed. Ready for full build."
}

main "$@"
