#!/usr/bin/env bash
set -euo pipefail
if [ ! -f "monGARS.xcworkspace/contents.xcworkspacedata" ]; then
  echo "::error title=Missing Xcode workspace::ios/monGARS.xcworkspace not found post-install. Did 'bundle exec pod install' run?"
  exit 2
fi
if [ ! -f "Pods/Pods.xcodeproj/project.pbxproj" ]; then
  echo "::error title=Missing Pods project::ios/Pods/Pods.xcodeproj not found. Did 'bundle exec pod install' succeed?"
  exit 3
fi
schemes=$(xcodebuild -list -workspace monGARS.xcworkspace | awk '/Schemes:/ {flag=1; next} /^$/ {flag=0} flag {print}')
if ! echo "$schemes" | grep -xq "monGARS"; then
  echo "::error title=Missing scheme::Scheme 'monGARS' not found in workspace."
  exit 4
fi
echo "OK: workspace, Pods project, and scheme present."
