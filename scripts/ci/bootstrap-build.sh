#!/usr/bin/env bash
set -euo pipefail

SCHEME="${SCHEME:-monGARS}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="${BUILD_DIR:-build}"

xcresult_supports_legacy_flag() {
  case "${XCRESULT_SUPPORTS_LEGACY:-}" in
    yes)
      return 0
      ;;
    no|unknown)
      return 1
      ;;
  esac

  if ! command -v xcrun >/dev/null 2>&1; then
    XCRESULT_SUPPORTS_LEGACY="unknown"
    return 1
  fi

  local help_output=""
  if help_output="$(xcrun xcresulttool get --help 2>&1)"; then
    if printf '%s' "$help_output" | grep -qi -- '--legacy'; then
      XCRESULT_SUPPORTS_LEGACY="yes"
      return 0
    fi
    XCRESULT_SUPPORTS_LEGACY="no"
    return 1
  fi

  if printf '%s' "$help_output" | grep -qi -- '--legacy'; then
    XCRESULT_SUPPORTS_LEGACY="yes"
    return 0
  fi

  XCRESULT_SUPPORTS_LEGACY="unknown"
  return 1
}

legacy_error_indicates_removed() {
  local message="$1"
  if [ -z "$message" ]; then
    return 1
  fi

  local lower="${message,,}"
  [[ "$lower" == *"--legacy"* ]] || return 1

  local token
  for token in \
    "unknown option" \
    "unrecognized option" \
    "invalid option" \
    "invalid argument" \
    "not supported" \
    "no longer supported" \
    "unsupported option" \
    "does not support" \
    "has been removed" \
    "was removed" \
    "removed in" \
    "not a valid option"; do
    if [[ "$lower" == *"$token"* ]]; then
      return 0
    fi
  done

  return 1
}

run_xcresulttool_json() {
  local bundle="$1"
  local output="$2"

  if [ ! -d "$bundle" ]; then
    return 1
  fi
  if ! command -v xcrun >/dev/null 2>&1; then
    return 1
  fi

  local tmp_err
  tmp_err="$(mktemp)"
  local best_err=""
  local variants=()

  xcresult_supports_legacy_flag || true
  case "${XCRESULT_SUPPORTS_LEGACY:-unknown}" in
    no)
      variants=("without" "with")
      ;;
    yes)
      variants=("with" "without")
      ;;
    *)
      variants=("with" "without")
      ;;
  esac

  for variant in "${variants[@]}"; do
    if [ "$variant" = "with" ]; then
      if xcrun xcresulttool get --format json --legacy --path "$bundle" \
        >"$output" 2>"$tmp_err"; then
        rm -f "$tmp_err"
        return 0
      fi
    else
      if xcrun xcresulttool get --format json --path "$bundle" \
        >"$output" 2>"$tmp_err"; then
        rm -f "$tmp_err"
        return 0
      fi
    fi

    local err=""
    err="$(cat "$tmp_err" 2>/dev/null)"
    rm -f "$output" || true
    if [ -n "$err" ]; then
      if [ -z "$best_err" ]; then
        best_err="$err"
      elif legacy_error_indicates_removed "$best_err" && ! legacy_error_indicates_removed "$err"; then
        best_err="$err"
      fi
    fi
  done

  if [ -n "$best_err" ]; then
    printf '%s\n' "$best_err" >&2 || true
  fi
  rm -f "$tmp_err"
  return 1
}

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
  (cd "$BUILD_DIR" && zip -qry monGARS-unsigned.ipa Payload)
  (cd "$APP_DIR" && zip -qry "$PWD/../../$SCHEME.app.zip" "$SCHEME.app")
fi

echo "==> Export xcresult JSON (if available)"
if [ -d "$BUILD_DIR/$SCHEME.xcresult" ]; then
  run_xcresulttool_json "$BUILD_DIR/$SCHEME.xcresult" "$BUILD_DIR/$SCHEME.xcresult.json" || true
fi

echo "Done."
