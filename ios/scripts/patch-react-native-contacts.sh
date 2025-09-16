#!/usr/bin/env bash
set -euo pipefail

# This script assumes the Pods directory lives at $PROJECT_ROOT/Pods unless the
# caller exports PODS_ROOT. If your Pods directory is customized, export
# PODS_ROOT before invoking the script so it can locate react-native-contacts.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PODS_DIR="${PODS_ROOT:-$PROJECT_ROOT/Pods}"

if [ ! -d "$PODS_DIR" ]; then
  echo "⚠️ Pods directory not found at $PODS_DIR. If you use a custom location, set the PODS_ROOT environment variable."
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "❌ python3 is required to patch react-native-contacts but was not found on PATH."
  exit 1
fi

if ! python3 - <<'PY' >/dev/null 2>&1; then
import sys
sys.exit(0 if sys.version_info >= (3, 7) else 1)
PY
then
  PY_VERSION="$(python3 --version 2>/dev/null || echo 'python3 unavailable')"
  echo "❌ python3 3.7 or newer is required to patch react-native-contacts (detected: $PY_VERSION)."
  exit 1
fi

TARGET_FILE="$PODS_DIR/react-native-contacts/ios/RCTContacts.mm"

if [ ! -f "$TARGET_FILE" ]; then
  TARGET_FILE="$(python3 - "$PODS_DIR" <<'PY'
import pathlib
import sys

pods_dir = pathlib.Path(sys.argv[1])
matches = sorted(pods_dir.rglob('react-native-contacts/ios/RCTContacts.mm'))
if matches:
    print(matches[0])
PY
)"
  TARGET_FILE="${TARGET_FILE%$'\r'}"
fi

if [ -z "$TARGET_FILE" ] || [ ! -f "$TARGET_FILE" ]; then
  echo "ℹ️ react-native-contacts pod not found under $PODS_DIR; skipping orientation patch."
  exit 0
fi

python3 - "$TARGET_FILE" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
updated = False
changes = []

if '#import <ImageIO/CGImageProperties.h>' not in text:
    marker = '#import <Photos/Photos.h>'
    if marker in text:
        text = text.replace(
            marker,
            marker + '\n#import <ImageIO/CGImageProperties.h>',
            1,
        )
        updated = True
        changes.append('import')

if 'requestImageDataForAsset:' in text:
    text = text.replace(
        'requestImageDataForAsset:',
        'requestImageDataAndOrientationForAsset:',
    )
    updated = True
    changes.append('requestImageDataAndOrientationForAsset')

handler_pattern = re.compile(
    r'resultHandler:\^\(\s*NSData \* _Nullable data,\s*NSString \* _Nullable dataUTI,\s*UIImageOrientation\s+orientation,\s*NSDictionary \* _Nullable info\s*\)'
)
if handler_pattern.search(text):
    text = handler_pattern.sub(
        'resultHandler:^(NSData * _Nullable data, NSString * _Nullable dataUTI, CGImagePropertyOrientation orientation, NSDictionary * _Nullable info)',
        text,
    )
    updated = True
    changes.append('resultHandler signature')

orientation_pattern = re.compile(r'UIImageOrientation(?![A-Za-z0-9_])')
if orientation_pattern.search(text):
    text = orientation_pattern.sub('CGImagePropertyOrientation', text)
    updated = True
    changes.append('enum type')

if updated:
    path.write_text(text)
    summary = ', '.join(dict.fromkeys(changes))
    if summary:
        summary = f' ({summary})'
    print(f'✅ Patched {path}{summary}.')
else:
    print(f'ℹ️ {path} already uses CGImagePropertyOrientation-compatible APIs; no changes made.')
PY
