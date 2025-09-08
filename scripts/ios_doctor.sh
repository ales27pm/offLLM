#!/usr/bin/env bash
set -euo pipefail
IOS_DIR="${1:-ios}"
WS="$(/usr/bin/find "$IOS_DIR" -maxdepth 1 -name '*.xcworkspace' -print -quit || true)"
if [ -z "${WS:-}" ]; then
  echo "❌ No .xcworkspace found after 'pod install' in: $IOS_DIR"
  exit 1
fi
echo "✅ Found workspace: $WS"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "WORKSPACE=$WS" >> "$GITHUB_ENV"
fi
