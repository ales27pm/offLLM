#!/usr/bin/env bash
set -euo pipefail

WS="${WORKSPACE:-monGARS.xcworkspace}"
SCHEME="${SCHEME:-monGARS}"

if [ ! -f "$WS/contents.xcworkspacedata" ]; then
  echo "::error title=Missing Xcode workspace::ios/$WS not found post-install. Did 'bundle exec pod install' run?"
  exit 2
fi

if [ ! -f "Pods/Pods.xcodeproj/project.pbxproj" ]; then
  echo "::error title=Missing Pods project::ios/Pods/Pods.xcodeproj not found. Did 'bundle exec pod install' succeed?"
  exit 3
fi

schemes=$(xcodebuild -list -json -workspace "$WS" | python - <<'PY'
import json,sys
j=json.load(sys.stdin)
print('\n'.join(j.get('workspace', {}).get('schemes', [])))
PY
)
if ! echo "$schemes" | grep -xq "$SCHEME"; then
  echo "::error title=Missing scheme::Scheme '$SCHEME' not found in workspace."
  exit 4
fi
echo "OK: workspace, Pods project, and scheme present."
