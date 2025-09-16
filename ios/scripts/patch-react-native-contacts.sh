#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PODS_DIR="${PODS_ROOT:-$PROJECT_ROOT/Pods}"
TARGET_FILE="$PODS_DIR/react-native-contacts/ios/RCTContacts.mm"

if [ ! -f "$TARGET_FILE" ]; then
  echo "ℹ️ react-native-contacts pod not found at $TARGET_FILE; skipping orientation patch."
  exit 0
fi

python3 - "$TARGET_FILE" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
updated = False

if '#import <ImageIO/CGImageProperties.h>' not in text:
    marker = '#import <Photos/Photos.h>'
    if marker in text:
        text = text.replace(
            marker,
            marker + '\n#import <ImageIO/CGImageProperties.h>',
            1,
        )
        updated = True

pattern = re.compile(r'UIImageOrientation(?![A-Za-z0-9_])')
new_text, count = pattern.subn('CGImagePropertyOrientation', text)
if count:
    text = new_text
    updated = True

if updated:
    path.write_text(text)
    print(f"✅ Patched {path} for CGImagePropertyOrientation compatibility.")
else:
    print(f"ℹ️ {path} already uses CGImagePropertyOrientation; no changes made.")
PY
