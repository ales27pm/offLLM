#!/bin/sh
# Verify iOS deployment target is set correctly
if [ "$IPHONEOS_DEPLOYMENT_TARGET" != "14.0" ]; then
  echo "ERROR: iOS deployment target must be 14.0 for React Native 0.73.11"
  echo "Current value: $IPHONEOS_DEPLOYMENT_TARGET"
  exit 1
fi
echo "Verified iOS deployment target: $IPHONEOS_DEPLOYMENT_TARGET"
exit 0
