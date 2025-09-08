#!/usr/bin/env bash
set -euo pipefail

# Helper to keep MLX sample project aligned with RN's iOS 18.0 minimum.
YML="ios/project.yml"
PODFILE="ios/Podfile"

if [ ! -f "$YML" ]; then
  echo "ERROR: $YML not found." >&2
  exit 1
fi

# 1) Ensure bridging header setting exists
if ! grep -q 'SWIFT_OBJC_BRIDGING_HEADER' "$YML"; then
  awk '
  BEGIN{added=0}
  {print}
  /settings:/ && added==0 {
    print "      SWIFT_OBJC_BRIDGING_HEADER: MyOfflineLLMApp/Bridging/MyOfflineLLMApp-Bridging-Header.h"
    added=1
  }
  ' "$YML" > "$YML.tmp" && mv "$YML.tmp" "$YML"
  echo "✅ Added SWIFT_OBJC_BRIDGING_HEADER to project.yml"
else
  awk '
    BEGIN{in_settings=0}
    /^settings:/ {in_settings=1}
    in_settings && /^\s*SWIFT_OBJC_BRIDGING_HEADER:/ {
      sub(/SWIFT_OBJC_BRIDGING_HEADER:.*/,"SWIFT_OBJC_BRIDGING_HEADER: MyOfflineLLMApp/Bridging/MyOfflineLLMApp-Bridging-Header.h")
    }
    {print}
  ' "$YML" > "$YML.tmp" && mv "$YML.tmp" "$YML"
  echo "✅ Normalized SWIFT_OBJC_BRIDGING_HEADER in project.yml (scoped to settings)"
fi

# 2) Ensure packages block for MLX & MLXLibraries
if ! grep -q '^packages:' "$YML"; then
  # Insert after options: or at top if not found
  if grep -q '^options:' "$YML"; then
    awk '
      BEGIN{printed=0}
      {print}
      /^options:/ && printed==0 {
        print ""
        print "packages:"
        print "  MLX:"
        print "    url: https://github.com/ml-explore/mlx-swift.git"
        print "    from: 0.25.6"
        print "  MLXLibraries:"
        print "    url: https://github.com/ml-explore/mlx-swift-examples"
        print "    from: 2.25.7"
        printed=1
      }
    ' "$YML" > "$YML.tmp" && mv "$YML.tmp" "$YML"
  else
    cat > "$YML.tmp" <<'YAML'
packages:
  MLX:
    url: https://github.com/ml-explore/mlx-swift.git
    from: 0.25.6
  MLXLibraries:
    url: https://github.com/ml-explore/mlx-swift-examples
    from: 2.25.7
YAML
    cat "$YML" >> "$YML.tmp" && mv "$YML.tmp" "$YML"
  fi
  echo "✅ Inserted packages block (MLX, MLXLibraries) in project.yml"
else
  # packages exist; ensure our entries are present
  if ! grep -q 'mlx-swift.git' "$YML"; then
    sed -i.bak '/^packages:/a\  MLX:\n    url: https://github.com/ml-explore/mlx-swift.git\n    from: 0.25.6' "$YML"
  fi
  if ! grep -q 'mlx-swift-examples' "$YML"; then
    sed -i.bak '/^packages:/a\  MLXLibraries:\n    url: https://github.com/ml-explore/mlx-swift-examples\n    from: 2.25.7' "$YML"
  fi
  echo "✅ Ensured MLX/MLXLibraries packages in project.yml"
fi

# 3) Exclude old ObjC++ file if present
if grep -q 'MLXTurboModule\.mm' "$YML"; then
  sed -i.bak '/MLXTurboModule\.mm/d' "$YML"
  echo "✅ Removed MLXTurboModule.mm from sources excludes"
fi

# 4) Ensure target dependencies include MLX + MLXLLM
if ! grep -q 'product: MLX$' "$YML"; then
  # Add under monGARS target dependencies
  awk '
  BEGIN{inTarget=0; deps=0}
  /^targets:/ {print; next}
  {
    if ($0 ~ /^  monGARS:/) inTarget=1
    if (inTarget && $0 ~ /dependencies:/) deps=1
    print
    if (inTarget && deps && $0 ~ /dependencies:/) {
      print "      - package: MLX"
      print "        product: MLX"
      print "      - package: MLXLibraries"
      print "        product: MLXLLM"
      inTarget=0; deps=0
    }
  }' "$YML" > "$YML.tmp" && mv "$YML.tmp" "$YML"
  echo "✅ Added MLX + MLXLLM to target dependencies"
fi

# 5) Podfile: set platform 18.0 and normalize all pod targets to 18.0
if [ -f "$PODFILE" ]; then
# Update the platform version at the top of the Podfile.  If the directive
# already exists, replace its version; otherwise insert a new directive.
  if grep -q "^platform :ios" "$PODFILE"; then
    sed -i.bak "s/^platform :ios.*/platform :ios, '18.0'/" "$PODFILE"
  else
    sed -i.bak "1s;^;platform :ios, '18.0'\n\n;" "$PODFILE"
  fi

  # Ensure a post_install hook exists and normalizes deployment targets across
  # all pods.  When adding the hook, set the deployment target to 18.0.
  if ! grep -q "post_install do |installer|" "$PODFILE"; then
    cat >> "$PODFILE" <<'RUBY'

post_install do |installer|
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
    end
  end
end
RUBY
  fi
  echo "✅ Updated Podfile (platform & post_install normalization)"
else
  echo "ℹ️  Podfile not found; skipping Podfile edits."
fi

echo "Done. Next steps:"
echo "  1) cd ios && xcodegen generate && bundle exec pod update hermes-engine --no-repo-update && bundle exec pod install --repo-update"
echo "  2) git add -A && git commit -m 'iOS: MLX Swift bridge + SPM, bridging header, RN types bump, Pod targets 18.0'"
