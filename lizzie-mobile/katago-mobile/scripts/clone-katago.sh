#!/usr/bin/env bash
# Clones KataGo source into ./src/ at the requested tag.
# Usage: clone-katago.sh [version-tag]
set -euo pipefail

VERSION="${1:-v1.15.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/../src"

if [ -d "$SRC_DIR/.git" ]; then
  echo "[clone-katago] src/ already a git checkout, fetching $VERSION"
  git -C "$SRC_DIR" fetch --depth 1 origin tag "$VERSION"
  git -C "$SRC_DIR" checkout "$VERSION"
else
  echo "[clone-katago] Cloning KataGo $VERSION into src/"
  rm -rf "$SRC_DIR"
  git clone --depth 1 --branch "$VERSION" \
    https://github.com/lightvector/KataGo.git "$SRC_DIR"
fi
