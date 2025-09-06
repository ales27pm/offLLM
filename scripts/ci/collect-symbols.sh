#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${1:-build}"
CONF="${2:-Release}"
APP_NAME="${3:-monGARS}"

DD="$BUILD_DIR/DerivedData"
PROD="$DD/Build/Products/${CONF}-iphoneos"

DSYM_SRC="$DD/Build/Products/${CONF}-iphoneos/${APP_NAME}.app.dSYM"
if [ -d "$DSYM_SRC" ]; then
  (cd "$DD/Build/Products/${CONF}-iphoneos" && zip -qry "$PWD/../../../${APP_NAME}.dSYM.zip" "${APP_NAME}.app.dSYM")
  echo "Zipped dSYM -> $BUILD_DIR/${APP_NAME}.dSYM.zip"
else
  echo "No dSYM found at $DSYM_SRC"
fi

# BCSymbolMaps (when present)
BC_DIR="$DD/Build/Products/${CONF}-iphoneos/${APP_NAME}.app/Frameworks"
SYMROOT="$DD/Build/Products/${CONF}-iphoneos"
tmpdir="$(mktemp -d)"
found=0

if [ -d "$SYMROOT" ]; then
  mapfile -t MAPS < <(find "$SYMROOT" -name "*.bcsymbolmap" 2>/dev/null || true)
  if [ "${#MAPS[@]}" -gt 0 ]; then
    found=1
    for f in "${MAPS[@]}"; do cp "$f" "$tmpdir/"; done
    (cd "$tmpdir" && zip -qry "$PWD/../BCSymbolMaps.zip" .)
    mv "$tmpdir/../BCSymbolMaps.zip" "$BUILD_DIR/BCSymbolMaps.zip"
    echo "Zipped BCSymbolMaps -> $BUILD_DIR/BCSymbolMaps.zip"
  fi
fi

rm -rf "$tmpdir" || true
[ "$found" -eq 0 ] && echo "No BCSymbolMaps found (OK)"
