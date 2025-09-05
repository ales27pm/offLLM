#!/usr/bin/env bash
set -euo pipefail

echo "Starting clean iOS build process..."

# Step 1: Clean JavaScript dependencies
rm -rf node_modules package-lock.json

# Step 2: Clean iOS native dependencies and build artifacts
pushd ios >/dev/null
rm -rf Pods Podfile.lock build
popd >/dev/null

# Step 3: Reinstall all dependencies
npm install
pushd ios >/dev/null
pod update hermes-engine --no-repo-update && pod install --repo-update
popd >/dev/null

# Step 4: Reset the React Native bundler cache
npx react-native start --reset-cache &
BUNDLER_PID=$!
sleep 10

# Step 5: Build the iOS application
npx react-native build-ios --mode Release

# Step 6: Kill the bundler process
kill $BUNDLER_PID

echo "✅ Clean iOS build process completed successfully."
