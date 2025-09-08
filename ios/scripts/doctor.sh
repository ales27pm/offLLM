#!/usr/bin/env bash
set -euo pipefail
if [ ! -f "monGARS.xcworkspace/contents.xcworkspacedata" ]; then
  echo "::error title=Missing Xcode workspace::ios/monGARS.xcworkspace not found post-install. Did 'bundle exec pod install' run?"
  exit 2
fi
echo "OK: monGARS.xcworkspace present."
