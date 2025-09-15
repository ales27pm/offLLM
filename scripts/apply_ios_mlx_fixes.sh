#!/usr/bin/env bash
set -euo pipefail

# Helper to keep MLX sample project aligned with RN's iOS 18.0 minimum.
YML="ios/project.yml"
PODFILE="ios/Podfile"

if [ ! -f "$YML" ]; then
  echo "ERROR: $YML not found." >&2
  exit 1
fi

# 1) Ensure bridging header setting exists (use monGARS instead of MyOfflineLLMApp)
if ! grep -q 'SWIFT_OBJC_BRIDGING_HEADER' "$YML"; then
  awk '
  BEGIN{added=0}
  {print}
  /settings:/ && added==0 {
    print "      SWIFT_OBJC_BRIDGING_HEADER: monGARS/Bridging/monGARS-Bridging-Header.h"
    added=1
  }
  ' "$YML" > "$YML.tmp" && mv "$YML.tmp" "$YML"
  echo "✅ Added SWIFT_OBJC_BRIDGING_HEADER to project.yml"
else
  awk '
    BEGIN{in_settings=0}
    /^settings:/ {in_settings=1}
    in_settings && /^\s*SWIFT_OBJC_BRIDGING_HEADER:/ {
      sub(/SWIFT_OBJC_BRIDGING_HEADER:.*/, "SWIFT_OBJC_BRIDGING_HEADER: monGARS/Bridging/monGARS-Bridging-Header.h")
    }
    {print}
  ' "$YML" > "$YML.tmp" && mv "$YML.tmp" "$YML"
  echo "✅ Normalized SWIFT_OBJC_BRIDGING_HEADER in project.yml (scoped to settings)"
fi

# 2) Ensure packages block for MLX & MLXLibraries
# (rest of script unchanged)
# ...
