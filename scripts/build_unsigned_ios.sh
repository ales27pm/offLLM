#!/usr/bin/env bash
# Build an unsigned iOS IPA.
# Environment variables:
#   SCHEME    - Xcode scheme (default: MyOfflineLLMApp)
#   WORKSPACE - Xcode workspace path (default: ios/MyOfflineLLMApp/MyOfflineLLMApp.xcworkspace)
#   IPA_OUTPUT- Output path for the unsigned IPA (default: ${PWD}/${SCHEME}-unsigned.ipa)
set -euo pipefail

SCHEME=${SCHEME:-MyOfflineLLMApp}
WORKSPACE=${WORKSPACE:-ios/MyOfflineLLMApp/MyOfflineLLMApp.xcworkspace}
IPA_OUTPUT=${IPA_OUTPUT:-${PWD}/${SCHEME}-unsigned.ipa}
ARCHIVE_PATH="build/${SCHEME}.xcarchive"

xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration Release -archivePath "$ARCHIVE_PATH" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO archive

APP_PATH="$ARCHIVE_PATH/Products/Applications/${SCHEME}.app"
PAYLOAD_DIR="Payload"
rm -rf "$PAYLOAD_DIR" "$IPA_OUTPUT"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR"
zip -r "$IPA_OUTPUT" "$PAYLOAD_DIR"
rm -rf "$PAYLOAD_DIR" "$ARCHIVE_PATH"
echo "Created unsigned IPA at $IPA_OUTPUT"
