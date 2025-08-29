#!/usr/bin/env bash
# Build an unsigned iOS IPA.
# Environment variables:
#   SCHEME    - Xcode scheme (default: MyOfflineLLMApp)
#   WORKSPACE - Xcode workspace path (default: ios/MyOfflineLLMApp.xcworkspace)
#   IPA_OUTPUT- Output path for the unsigned IPA (default: ${PWD}/${SCHEME}-unsigned.ipa)
set -euo pipefail

SCHEME=${SCHEME:-MyOfflineLLMApp}
WORKSPACE=${WORKSPACE:-ios/MyOfflineLLMApp.xcworkspace}
IPA_OUTPUT=${IPA_OUTPUT:-${PWD}/${SCHEME}-unsigned.ipa}
ARCHIVE_PATH="build/${SCHEME}.xcarchive"

echo "Generating Xcode project with XcodeGen..."
xcodegen generate --spec ios/MyOfflineLLMApp/project.yml --project ios/MyOfflineLLMApp/MyOfflineLLMApp.xcodeproj

echo "Installing CocoaPods dependencies..."
pod install --project-directory=ios

echo "Checking iOS directory structure..."
ls -la ios/
ls -la ios/MyOfflineLLMApp/
ls -la ios/*.xcworkspace 2>/dev/null || true
if [[ ! -f "$WORKSPACE" ]]; then
  echo "Workspace not found at $WORKSPACE" >&2
  exit 1
fi

xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration Release -archivePath "$ARCHIVE_PATH" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO archive

APP_PATH="$ARCHIVE_PATH/Products/Applications/${SCHEME}.app"
PAYLOAD_DIR="Payload"

# Validate paths before removal to avoid accidental data loss
if [[ -z "$PAYLOAD_DIR" || "$PAYLOAD_DIR" == "/" ]]; then
  echo "Error: PAYLOAD_DIR is not set correctly. Aborting to prevent data loss."
  exit 1
fi
if [[ -z "$IPA_OUTPUT" || "$IPA_OUTPUT" == "/" ]]; then
  echo "Error: IPA_OUTPUT is not set correctly. Aborting to prevent data loss."
  exit 1
fi

rm -rf "$PAYLOAD_DIR" "$IPA_OUTPUT"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR"
zip -r "$IPA_OUTPUT" "$PAYLOAD_DIR"
rm -rf "$PAYLOAD_DIR" "$ARCHIVE_PATH"
echo "Created unsigned IPA at $IPA_OUTPUT"

