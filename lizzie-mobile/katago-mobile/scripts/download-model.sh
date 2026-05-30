#!/usr/bin/env bash
# Download a mobile-optimized KataGo network file.
# Smaller networks (~20MB) are suitable for mobile CPU inference.
# Usage: bash scripts/download-model.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/models"
mkdir -p "$MODELS_DIR"

echo "Downloading mobile-optimized KataGo network..."

# Binary file for KataGo - use the latest training network
# For production, replace with a specific small/medium network
# Options from https://katagotraining.org/networks/
#
# b18c384nbt-mobile - small network (~20MB) optimized for mobile
# b28c512nbt - medium network (~50MB) good balance
# b40c256x2-s5092488192 - latest strong network (~100MB+, too big for mobile)

# We'll download the medium network as a reasonable default
MODEL_URL="https://media.katagotraining.org/uploaded/networks/models/kata1-b28c512nbt-s9851807232-d4973981529.bin.gz"
MODEL_NAME="katago-mobile.bin.gz"
MODEL_PATH="$MODELS_DIR/$MODEL_NAME"

echo "URL: $MODEL_URL"
echo "Target: $MODEL_PATH"
echo ""
echo "Note: This is ~50MB. On mobile, for faster first-launch,"
echo "consider the smaller b18c384nbt network (~20MB) from:"
echo "  https://katagotraining.org/networks/"
echo ""

# Download with curl or wget
if command -v curl &>/dev/null; then
    curl -L -o "$MODEL_PATH" "$MODEL_URL"
elif command -v wget &>/dev/null; then
    wget -O "$MODEL_PATH" "$MODEL_URL"
else
    echo "Error: Neither curl nor wget found. Please download manually:"
    echo "  $MODEL_URL"
    echo "  Save to: $MODEL_PATH"
    exit 1
fi

echo ""
echo "Downloaded: $MODEL_PATH"
ls -lh "$MODEL_PATH"

# Write version info
echo "b28c512nbt-s9851807232-d4973981529" > "$MODELS_DIR/model-version.txt"

echo "Done."