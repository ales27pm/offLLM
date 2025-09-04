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
rm -rf node_modules package-lock.json
rm -rf "${PROJECT_DIR}/Pods" "${PROJECT_DIR}/Podfile.lock" "${PROJECT_DIR}/build"
rm -rf ~/Library/Developer/Xcode/DerivedData

# Step 3: Reinstall dependencies
echo "📦 Installing Node.js dependencies..."
npm ci

echo "📦 Installing Ruby dependencies for CocoaPods..."
cd ios && bundle install && cd ..

echo "📱 Generating Xcode project and installing CocoaPods..."
cd ios && xcodegen generate && bundle exec pod install --repo-update && cd ..

# Step 4: Run the Xcode build
echo "📦 Archiving the application (unsigned)..."
xcodebuild archive \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$BUILD_DIR/${SCHEME}.xcarchive" \
  -resultBundlePath "$BUILD_DIR/${SCHEME}.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS=arm64 \
  | tee "$BUILD_DIR/xcodebuild.log"

echo "✅ Build script completed."
