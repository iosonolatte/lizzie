#!/usr/bin/env bash
# Clone KataGo source for mobile cross-compilation.
# Usage: bash scripts/clone-katago.sh [version]
set -euo pipefail

KATAGO_VERSION="${1:-v1.15.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KATAGO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/src"

if [ -d "$KATAGO_DIR/.git" ]; then
    echo "KataGo already cloned at $KATAGO_DIR"
    echo "Fetching latest tags..."
    cd "$KATAGO_DIR"
    git fetch --tags
    git checkout "$KATAGO_VERSION" 2>/dev/null || echo "Tag $KATAGO_VERSION not found, staying on current"
    exit 0
fi

echo "Cloning KataGo $KATAGO_VERSION..."
git clone --depth 1 --branch "$KATAGO_VERSION" \
    https://github.com/lightvector/KataGo.git "$KATAGO_DIR"

echo "Done. KataGo source at: $KATAGO_DIR"