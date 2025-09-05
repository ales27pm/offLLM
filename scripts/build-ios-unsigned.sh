#!/bin/bash
set -euo pipefail

echo "🚀 Starting failproof iOS unsigned build process..."

# Step 1: Verify Node.js version
echo "✅ Checking Node.js version..."
REQUIRED_NODE_VERSION="18.0.0"
CURRENT_NODE_VERSION="$(node -v | sed 's/v//')"
version_ge() {
  # returns 0 if $1 >= $2
  [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}
if ! version_ge "$CURRENT_NODE_VERSION" "$REQUIRED_NODE_VERSION"; then
  echo "❌ Error: Node.js $REQUIRED_NODE_VERSION or higher is required. Current version is $CURRENT_NODE_VERSION."
  exit 1
fi
echo "Node.js version $CURRENT_NODE_VERSION is compatible."

# Step 2: Clean all caches and dependencies
echo "🧹 Cleaning all dependencies and caches..."
rm -rf node_modules package-lock.json
rm -rf ios/Pods ios/Podfile.lock ios/build
npx react-native start --reset-cache >/dev/null 2>&1 &
BUNDLER_PID=$!
if ! kill -0 "$BUNDLER_PID" 2>/dev/null; then
  echo "❌ Failed to start React Native bundler."
  exit 1
fi
trap 'kill "$BUNDLER_PID" 2>/dev/null || true' EXIT INT TERM
# Wait up to 30s for Metro to listen on default port 8081
for i in {1..30}; do
  if nc -z localhost 8081 2>/dev/null; then
    break
  fi
  sleep 1
done

# Step 3: Reinstall dependencies
echo "📦 Reinstalling dependencies..."
npm install

# Step 4: Install native dependencies
echo "📱 Installing iOS native dependencies..."
cd ios
pod update hermes-engine --no-repo-update && pod install --repo-update
cd ..

# Step 5: Kill the bundler and perform a clean build
kill $BUNDLER_PID 2>/dev/null || true
echo "🔨 Performing clean Xcode build..."
cd ios
if [ ! -d "MyOfflineLLMApp.xcworkspace" ]; then
  echo "❌ Xcode workspace 'MyOfflineLLMApp.xcworkspace' not found."
  exit 1
fi
xcodebuild clean -workspace MyOfflineLLMApp.xcworkspace -scheme MyOfflineLLMApp
mkdir -p build
xcodebuild \
  -workspace MyOfflineLLMApp.xcworkspace \
  -scheme MyOfflineLLMApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "build/MyOfflineLLMApp.xcarchive" \
  archive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

# Step 6: Export the unsigned IPA
# Step 6: Export the unsigned IPA (manual packaging to avoid signing requirements)
OUT_DIR="build/unsigned_ipa"
APP_PATH="build/MyOfflineLLMApp.xcarchive/Products/Applications/MyOfflineLLMApp.app"
mkdir -p "$OUT_DIR/Payload"
if [ ! -d "$APP_PATH" ]; then
  echo "❌ Error: App not found at $APP_PATH"; exit 1
fi
cp -R "$APP_PATH" "$OUT_DIR/Payload/"
# Ensure truly unsigned bundle
rm -rf "$OUT_DIR/Payload/MyOfflineLLMApp.app/_CodeSignature" "$OUT_DIR/Payload/MyOfflineLLMApp.app/embedded.mobileprovision"
# Zip to IPA
(
  cd "$OUT_DIR"
  zip -qry "MyOfflineLLMApp.ipa" "Payload"
)
# Clean up temporary Payload folder
rm -rf "$OUT_DIR/Payload"
cd ..
echo "🎉 Unsigned IPA generated at ./ios/build/unsigned_ipa/MyOfflineLLMApp.ipa"

echo "✅ Failproof iOS build process completed successfully."
