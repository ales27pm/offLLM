#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="${1:-"$ROOT_DIR/ios"}"
WS=""
for ws in "$IOS_DIR"/*.xcworkspace; do
  if [ -e "$ws" ]; then
    WS="$ws"
    break
  fi
done
if [ -z "${WS:-}" ]; then
  echo "❌ No .xcworkspace found after 'pod install' in: $IOS_DIR"
  exit 1
fi
echo "✅ Found workspace: $WS"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "WORKSPACE=$WS" >> "$GITHUB_ENV"
fi
