#!/usr/bin/env bash
# Downloads a KataGo neural-net model into ./models/.
# Usage: download-model.sh [model-name]
set -euo pipefail

MODEL_NAME="${1:-kata1-b18c384nbt-s9996604416-d4316597426}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_DIR="$SCRIPT_DIR/../models"
MODEL_FILE="$MODEL_DIR/${MODEL_NAME}.bin.gz"

mkdir -p "$MODEL_DIR"

if [ -f "$MODEL_FILE" ]; then
  echo "[download-model] $MODEL_FILE already present, skipping"
  exit 0
fi

echo "[download-model] Fetching $MODEL_NAME from katagoarchive.org"
wget --progress=dot:giga \
  "https://katagoarchive.org/models/${MODEL_NAME}.bin.gz" \
  -O "$MODEL_FILE"
