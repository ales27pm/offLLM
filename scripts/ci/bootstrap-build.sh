#!/usr/bin/env bash
set -euo pipefail

SCHEME="${SCHEME:-monGARS}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="${BUILD_DIR:-build}"

echo "==> Installing JS deps"
npm ci

echo "==> Ensuring XcodeGen"
if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi

echo "==> Seeding minimal XcodeGen spec (if missing)"
if [ ! -f ios/project.yml ]; then
  mkdir -p ios
  cat > ios/project.yml <<'YML'
  name: monGARS
  options:
    bundleIdPrefix: com.example
    deploymentTarget:
      iOS: "18.0"
  targets:
    monGARS:
      type: application
      platform: iOS
      sources:
        - path: .
          excludes:
            - ios/**/*
            - android/**/*
            - node_modules/**/*
      settings:
        PRODUCT_BUNDLE_IDENTIFIER: com.example.monGARS
        INFOPLIST_FILE: ios/Info.plist
  YML
  if [ ! -f ios/Info.plist ]; then
    cat > ios/Info.plist <<'PLIST'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleName</key><string>monGARS</string>
      <key>CFBundleIdentifier</key><string>com.example.monGARS</string>
      <key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>UISupportedInterfaceOrientations</key>
      <array><string>UIInterfaceOrientationPortrait</string></array>
      <key>LSRequiresIPhoneOS</key><true/>
    </dict>
    </plist>
    PLIST
  fi
fi

echo "==> Generate project"
( cd ios && xcodegen generate )

echo "==> Pods"
( cd ios && bundle install --path vendor/bundle && bundle exec pod repo update && bundle exec pod install )

echo "==> Clean & build"
rm -rf "$BUILD_DIR/DerivedData"
xcodebuild \
  -workspace ios/monGARS.xcworkspace \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  -resultBundlePath "$BUILD_DIR/$SCHEME.xcresult" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  | tee "$BUILD_DIR/xcodebuild.log"

echo "==> Package unsigned IPA"
APP_DIR="$BUILD_DIR/DerivedData/Build/Products/${CONFIGURATION}-iphoneos"
APP_PATH="$APP_DIR/$SCHEME.app"
if [ -d "$APP_PATH" ]; then
  rm -rf "$BUILD_DIR/Payload"
  mkdir -p "$BUILD_DIR/Payload"
  cp -R "$APP_PATH" "$BUILD_DIR/Payload/"
  (cd "$BUILD_DIR" && zip -qry offLLM-unsigned.ipa Payload)
  (cd "$APP_DIR" && zip -qry "$PWD/../../$SCHEME.app.zip" "$SCHEME.app")
fi

echo "==> Export xcresult JSON (if available)"
if command -v xcrun >/dev/null 2>&1 && [ -d "$BUILD_DIR/$SCHEME.xcresult" ]; then
  xcrun xcresulttool get --format json --path "$BUILD_DIR/$SCHEME.xcresult" > "$BUILD_DIR/$SCHEME.xcresult.json" || true
fi

echo "Done."
