#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "❌ xcodebuild not available. Install Xcode command line tools before running the doctor."
  exit 1
fi

echo "=== monGARS iOS Doctor (Enhanced: Blueprint + Codegen Check) ==="
echo "Date: $(date)"
echo "Xcode: $(xcodebuild -version | head -1)"
echo "Node: $(node --version)"
echo "Ruby: $(ruby --version)"
echo "Pod: $(pod --version)"

# Your existing checks...
(
  cd "$ROOT_DIR"
  npm run lint
  npm test
)
(
  cd "$IOS_DIR"
  xcodegen generate
  bundle exec pod install --repo-update
)

# New: Blueprint duplicate scan
echo "Scanning for blueprint duplicates..."
BLUEPRINT_ISSUES=$(cd "$IOS_DIR" && xcodebuild -workspace monGARS.xcworkspace -scheme monGARS -showBuildSettings 2>&1 | grep -c "Unexpectedly found another blueprint" || true)
if [ "${BLUEPRINT_ISSUES:-0}" -gt 0 ]; then
  echo "⚠️  $BLUEPRINT_ISSUES blueprint duplicates detected. Running auto-clean..."
  find "$IOS_DIR/build/generated/ios" -name "*JSI-generated*" -delete 2>/dev/null || true
  find "$IOS_DIR/build/generated/ios" -name "*Spec-generated*" -delete 2>/dev/null || true
  (
    cd "$IOS_DIR"
    bundle exec pod install  # Re-gen clean
  )
fi

# New: Test archive dry-run
echo "Dry-run archive..."
if ! (cd "$IOS_DIR" && xcodebuild -workspace monGARS.xcworkspace -scheme monGARS \
  -configuration Release \
  -destination "generic/platform=iOS" \
  CODE_SIGNING_ALLOWED=NO \
  -dry-run clean archive); then
  echo "❌ Archive dry-run failed. Check logs."
  exit 1
fi

# Your existing sim/device tests...
echo "✅ Doctor passed. Ready for full build."
