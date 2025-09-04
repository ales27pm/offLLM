#!/usr/bin/env bash
set -euo pipefail

# Configuration
: "${SCHEME:=MyOfflineLLMApp}"
: "${WORKSPACE:=${PWD}/ios/MyOfflineLLMApp.xcworkspace}"
: "${BUILD_DIR:=build}"
: "${PROJECT_DIR:=ios}"
: "${REQUIRED_NODE_VERSION:=20.0.0}"

echo "▶️ Starting robust unsigned iOS build..."

# Step 1: Validate Node.js version
CURRENT_NODE_VERSION=$(node -v | sed 's/v//')
version_ge() {
  [[ "$1" == "$2" ]] && return 0
  [[ "$1" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || return 2
  local v1_major=${BASH_REMATCH[1]} v1_minor=${BASH_REMATCH[2]} v1_patch=${BASH_REMATCH[3]}
  [[ "$2" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || return 2
  local v2_major=${BASH_REMATCH[1]} v2_minor=${BASH_REMATCH[2]} v2_patch=${BASH_REMATCH[3]}
  [[ $v1_major -gt $v2_major ]] && return 0 || [[ $v1_major -lt $v2_major ]] && return 1
  [[ $v1_minor -gt $v2_minor ]] && return 0 || [[ $v1_minor -lt $v2_minor ]] && return 1
  [[ $v1_patch -ge $v2_patch ]]
}
if ! version_ge "$CURRENT_NODE_VERSION" "$REQUIRED_NODE_VERSION"; then
  echo "❌ Error: Node.js $REQUIRED_NODE_VERSION or higher is required. Current version is $CURRENT_NODE_VERSION."
  exit 1
fi
echo "✅ Node.js version $CURRENT_NODE_VERSION is compatible."

# Step 2: Clean all caches and dependencies
echo "🧹 Cleaning all dependencies and caches..."
rm -rf node_modules
rm -rf "$BUILD_DIR" "${PROJECT_DIR}/build"
mkdir -p "$BUILD_DIR"

# Step 3: Reinstall dependencies
echo "📦 Installing Node.js dependencies..."
npm ci

echo "📦 Installing Ruby dependencies for CocoaPods..."
cd ios && bundle install && cd ..

echo "📱 Generating Xcode project and installing CocoaPods..."
cd ios && xcodegen generate && bundle exec pod install --repo-update && cd ..

# Ensure the Xcode workspace exists before attempting to build.
# If the initial pod install failed to produce it (e.g. due to a flaky
# environment), retry once and bail out with a clear error message.
if [ ! -d "$WORKSPACE" ]; then
  echo "⚠️ Workspace not found at $WORKSPACE; rerunning CocoaPods install..."
  (cd ios && bundle exec pod install --repo-update)
fi

if [ ! -d "$WORKSPACE" ]; then
  echo "❌ Error: Xcode workspace still missing at $WORKSPACE"
  exit 1
fi

# Step 4: Run the Xcode build (Simulator, unsigned)
echo "📦 Building for iOS Simulator (unsigned)..."
xcodebuild build \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  -resultBundlePath "$BUILD_DIR/${SCHEME}.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  | tee "$BUILD_DIR/xcodebuild.log"

# … previous xcodebuild step …

echo "📦 Packaging simulator build as artifact..."
APP_DIR="$BUILD_DIR/DerivedData/Build/Products/Release-iphonesimulator"
APP_PATH="$(/usr/bin/find "$APP_DIR" -maxdepth 1 -name "${SCHEME}.app" -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "❌ Error: Built .app not found in $APP_DIR"
  exit 1
fi
PAYLOAD_DIR="$BUILD_DIR/Payload"
rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"
(cd "$BUILD_DIR" && zip -qr offLLM-unsigned-ipa.zip Payload)
echo "✅ Artifact created at $BUILD_DIR/offLLM-unsigned-ipa.zip"

echo "✅ Build script completed."
