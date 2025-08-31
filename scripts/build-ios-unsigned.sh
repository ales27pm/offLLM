#!/bin/bash
set -euo pipefail

echo "🚀 Starting failproof iOS unsigned build process..."

# Step 1: Verify Node.js version
echo "✅ Checking Node.js version..."
REQUIRED_NODE_VERSION="18.0.0"
CURRENT_NODE_VERSION=$(node -v | sed 's/v//')
if ! npx semver -r ">=$REQUIRED_NODE_VERSION" "$CURRENT_NODE_VERSION" >/dev/null 2>&1; then
  echo "❌ Error: Node.js $REQUIRED_NODE_VERSION or higher is required. Current version is $CURRENT_NODE_VERSION."
  exit 1
fi
echo "Node.js version $CURRENT_NODE_VERSION is compatible."

# Step 2: Clean all caches and dependencies
echo "🧹 Cleaning all dependencies and caches..."
rm -rf node_modules package-lock.json
rm -rf ios/Pods ios/Podfile.lock ios/build
npx react-native start --reset-cache &
BUNDLER_PID=$!
sleep 10 # Allow the bundler to start

# Step 3: Reinstall dependencies
echo "📦 Reinstalling dependencies..."
npm install

# Step 4: Install native dependencies
echo "📱 Installing iOS native dependencies..."
cd ios
pod install --repo-update
cd ..

# Step 5: Kill the bundler and perform a clean build
kill $BUNDLER_PID 2>/dev/null || true
echo "🔨 Performing clean Xcode build..."
cd ios
xcodebuild clean -workspace MyOfflineLLMApp.xcworkspace -scheme MyOfflineLLMApp
xcodebuild \
  -workspace MyOfflineLLMApp.xcworkspace \
  -scheme MyOfflineLLMApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "build/MyOfflineLLMApp.xcarchive" \
  archive \
  CODE_SIGNING_ALLOWED=NO

# Step 6: Export the unsigned IPA
xcodebuild \
  -exportArchive \
  -archivePath "build/MyOfflineLLMApp.xcarchive" \
  -exportPath "build/unsigned_ipa" \
  -exportOptionsPlist export-options.plist \
  CODE_SIGNING_ALLOWED=NO

cd ..
echo "🎉 Unsigned IPA generated at ./ios/build/unsigned_ipa/MyOfflineLLMApp.ipa"

echo "✅ Failproof iOS build process completed successfully."
