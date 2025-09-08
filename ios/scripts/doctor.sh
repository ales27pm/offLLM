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
echo "OK: workspace and Pods project present."
