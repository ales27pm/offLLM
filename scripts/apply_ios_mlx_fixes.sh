#!/bin/bash
# File: scripts/apply_ios_mlx_fixes.sh

# Exit on error
set -e

echo "Applying iOS MLX fixes..."

# Update bridging header path if necessary
BRIDGING_HEADER_PATH="MyOfflineLLMApp/Bridging/MyOfflineLLMApp-Bridging-Header.h"
NEW_HEADER_PATH="MyOfflineLLMApp/Bridging/monGARS-Bridging-Header.h"
if [ -f $BRIDGING_HEADER_PATH ]; then
  echo "Renaming bridging header to match scheme..."
  mv "$BRIDGING_HEADER_PATH" "$NEW_HEADER_PATH"
  # Update project file references via XcodeGen if needed
  sed -i '' "s|MyOfflineLLMApp-Bridging-Header|monGARS-Bridging-Header|g" ios/project.yml
fi

# Additional fixes for MLX (if MLXCompat was removed etc)
echo "No MLX-specific fixes required (up-to-date MLX API assumed)."

echo "iOS MLX fixes applied successfully."
