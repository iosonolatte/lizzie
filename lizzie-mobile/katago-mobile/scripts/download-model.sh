#!/usr/bin/env bash
# Download a mobile-suitable KataGo network file.
# b18c384nbt (~94MB) is a good mobile balance: reasonable strength vs file size.
# Usage: bash scripts/download-model.sh [model-name]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/models"
mkdir -p "$MODELS_DIR"

# Default: latest b18c384nbt (smaller = faster on mobile)
MODEL_NAME="${1:-kata1-b18c384nbt-s9996604416-d4316597426}"
MODEL_FILENAME="${MODEL_NAME}.bin.gz"
MODEL_URL="https://media.katagotraining.org/uploaded/networks/models/kata1/${MODEL_FILENAME}"
MODEL_PATH="$MODELS_DIR/$MODEL_FILENAME"

echo "Downloading model: $MODEL_NAME"
echo "URL: $MODEL_URL"
echo "Target: $MODEL_PATH"
echo ""
echo "Available model sizes:"
echo "  b18c384nbt (~94MB)  - Recommended for mobile (good balance)"
echo "  b28c512nbt (~259MB) - Stronger, but larger download"
echo "  b40c768nbt (~600MB) - Latest strongest, too large for mobile"
echo ""
echo "For fastest first-launch, consider the b18c384nbt series."
echo ""

if [ -f "$MODEL_PATH" ]; then
    echo "Model already exists: $(ls -lh "$MODEL_PATH" | awk '{print $5}')"
    echo "Delete $MODEL_PATH to re-download."
    exit 0
fi

# Download with curl or wget
if command -v curl &>/dev/null; then
    echo "Downloading (curl)..."
    curl -L --progress-bar -o "$MODEL_PATH" "$MODEL_URL"
elif command -v wget &>/dev/null; then
    echo "Downloading (wget)..."
    wget --show-progress -O "$MODEL_PATH" "$MODEL_URL"
else
    echo "Error: Neither curl nor wget found. Install one of them."
    exit 1
fi

echo ""
echo "Download complete:"
ls -lh "$MODEL_PATH"

# Write version info
echo "$MODEL_NAME" > "$MODELS_DIR/model-version.txt"
echo "Model version recorded in model-version.txt"
echo "Done."