#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"
WORKSPACE_CANDIDATES=("monGARS.xcworkspace" "MyOfflineLLMApp.xcworkspace")
echo "🔎 iOS Doctor: verifying CocoaPods created an .xcworkspace…"
cd "$IOS_DIR"
FOUND=""
for ws in "${WORKSPACE_CANDIDATES[@]}"; do
  if [[ -f "$ws/contents.xcworkspacedata" || -d "$ws" ]]; then
    FOUND="$ws"
    break
  fi
done
if [[ -z "$FOUND" ]]; then
  echo "❌ No .xcworkspace found after 'pod install' in: $IOS_DIR"
  echo "   Expected one of: ${WORKSPACE_CANDIDATES[*]}"
  echo "   Tips:"
  echo "     - Ensure XcodeGen generated the .xcodeproj (ios/project.yml)."
  echo "     - Ensure Podfile autodetected the .xcodeproj near the Podfile."
  echo "     - Re-run 'bundle exec pod install --repo-update'."
  exit 1
fi
echo "✅ Found workspace: $FOUND"
[[ -n "${GITHUB_ENV:-}" ]] && echo "WORKSPACE=$FOUND" >> "$GITHUB_ENV"

