#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
NPM_ENV_HELPER="$ROOT_DIR/scripts/lib/npm_env.sh"
# shellcheck source=lib/npm_env.sh
source "$NPM_ENV_HELPER"
# Normalize deprecated npm proxy environment variables before invoking npm.
sanitize_npm_proxy_env

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
bundle install
xcodegen generate
bundle exec pod update hermes-engine --no-repo-update
bundle exec pod install --repo-update
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
