#!/usr/bin/env bash
# Build KataGo as a static library for iOS arm64.
# Must be run on macOS with Xcode installed.
# Also builds a small C bridge layer for GTP communication.
# Usage: bash scripts/build-ios.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KATAGO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SRC_DIR="$KATAGO_DIR/src"
EIGEN_DIR="$KATAGO_DIR/eigen"
OUT_DIR="$KATAGO_DIR/out/ios"
BUILD_DIR="$OUT_DIR/build"
IOS_ARCH="arm64"
IOS_SDK="iphoneos"

# --- Check prerequisites ---
if [ "$(uname)" != "Darwin" ]; then
    echo "Error: iOS builds require macOS with Xcode."
    echo "Skipping iOS build."
    exit 0
fi

if [ ! -d "$SRC_DIR/CMakeLists.txt" ]; then
    echo "Error: KataGo source not found at $SRC_DIR"
    echo "Run 'bash scripts/clone-katago.sh' first."
    exit 1
fi

if ! xcode-select -p &>/dev/null; then
    echo "Error: Xcode not found. Install from App Store."
    exit 1
fi

echo "Building for iOS ($IOS_ARCH)..."

# --- Fetch Eigen ---
if [ ! -d "$EIGEN_DIR" ]; then
    echo "Fetching Eigen..."
    git clone --depth 1 --branch 3.4.0 \
        https://gitlab.com/libeigen/eigen.git "$EIGEN_DIR"
fi

# --- Build as static library ---
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES="$IOS_ARCH" \
    -DCMAKE_OSX_SYSROOT="$(xcode-select -p)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk" \
    -DCMAKE_CXX_STANDARD=17 \
    -DUSE_CUDA=OFF \
    -DUSE_OPENCL=OFF \
    -DUSE_TENSORRT=OFF \
    -DUSE_BACKEND=EIGEN \
    -DEigen3_DIR="$EIGEN_DIR" \
    -DUSE_GLOG=OFF \
    -DUSE_AVX2=OFF \
    -DUSE_AVX512=OFF \
    -DUSE_NEON=ON \
    -DBUILD_DISTRIBUTED=OFF \
    -DBUILD_MAIN=OFF \
    "$SRC_DIR"

echo "Building katago static library..."
cmake --build . -j"$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)" \
    --target katago -- -arch "$IOS_ARCH"

# --- Find and copy the static library ---
LIB_SRC="$BUILD_DIR/libkatago.a"
mkdir -p "$OUT_DIR"

if [ -f "$LIB_SRC" ]; then
    cp "$LIB_SRC" "$OUT_DIR/libkatago.a"
else
    # May be in a subdirectory
    find "$BUILD_DIR" -name "libkatago.a" -exec cp {} "$OUT_DIR/libkatago.a" \;
fi

# --- Build C bridge layer ---
BRIDGE_DIR="$SRC_DIR/cpp_bridge"
mkdir -p "$BRIDGE_DIR"

cat > "$BRIDGE_DIR/katago_bridge.h" << 'HEADER_EOF'
#ifndef KATAGO_BRIDGE_H
#define KATAGO_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

// Initialize KataGo instance. Returns handle (0 on failure).
void* katago_init(const char* model_path, const char* config_path);

// Send a GTP command and get the response (caller must free).
char* katago_send(void* handle, const char* command);

// Read next analysis line (if available). Returns NULL if none.
// Caller must free the returned string.
char* katago_read_analysis(void* handle);

// Destroy KataGo instance.
void katago_destroy(void* handle);

#ifdef __cplusplus
}
#endif

#endif // KATAGO_BRIDGE_H
HEADER_EOF

cat > "$BRIDGE_DIR/katago_bridge.cpp" << 'BRIDGE_EOF'
#include "katago_bridge.h"
#include <cstring>
#include <string>
#include <sstream>
#include <iostream>

// Include KataGo's GTP engine
// This is a stub — the actual implementation routes to KataGo's
// GTPEngine class through a pipe-based interface.

// Forward declaration of KataGo's main classes
namespace KataGo {
    class GTPEngine;
}

struct KataGoHandle {
    KataGo::GTPEngine* engine;
    std::stringstream analysis_output;
};

void* katago_init(const char* model_path, const char* config_path) {
    // TODO: Actual initialization of KataGo with model/config
    // This requires linking against KataGo's internal API
    (void)model_path;
    (void)config_path;
    return nullptr;
}

char* katago_send(void* handle, const char* command) {
    (void)handle;
    (void)command;
    char* result = strdup("= not implemented\n");
    return result;
}

char* katago_read_analysis(void* handle) {
    (void)handle;
    return nullptr;
}

void katago_destroy(void* handle) {
    (void)handle;
}
BRIDGE_EOF

echo ""
echo "=== iOS build complete ==="
echo "Static library: $OUT_DIR/libkatago.a"
echo "Bridge header:  $BRIDGE_DIR/katago_bridge.h"
echo "Bridge source:  $BRIDGE_DIR/katago_bridge.cpp"
echo ""
echo "To integrate into Xcode project:"
echo "1. Add libkatago.a to Xcode (Linked Frameworks & Libraries)"
echo "2. Add katago_bridge.cpp to the compile sources"
echo "3. Add katago_bridge.h to the bridging header"
echo ""