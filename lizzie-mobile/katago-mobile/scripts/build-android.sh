#!/usr/bin/env bash
# Cross-compile KataGo for Android (arm64-v8a) using NDK.
# Usage: bash scripts/build-android.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KATAGO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SRC_DIR="$KATAGO_DIR/src"
EIGEN_DIR="$KATAGO_DIR/eigen"
OUT_DIR="$KATAGO_DIR/out/android"
BUILD_DIR="$OUT_DIR/build"

# --- Check prerequisites ---
if [ ! -d "$SRC_DIR/CMakeLists.txt" ]; then
    echo "Error: KataGo source not found at $SRC_DIR"
    echo "Run 'bash scripts/clone-katago.sh' first."
    exit 1
fi

if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    # Try common locations
    if [ -d "$HOME/Android/Sdk/ndk" ]; then
        # Find the latest NDK version
        ANDROID_NDK_HOME=$(ls -d "$HOME/Android/Sdk/ndk/"* 2>/dev/null | sort -V | tail -1)
    elif [ -d "$ANDROID_HOME/ndk" ]; then
        ANDROID_NDK_HOME=$(ls -d "$ANDROID_HOME/ndk/"* 2>/dev/null | sort -V | tail -1)
    fi
fi

if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    echo "Error: ANDROID_NDK_HOME not set and couldn't find NDK automatically."
    echo "Install Android NDK via Android Studio: SDK Manager → SDK Tools → NDK"
    echo "Then: export ANDROID_NDK_HOME=/path/to/ndk"
    exit 1
fi

echo "Using NDK at: $ANDROID_NDK_HOME"

TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake"
if [ ! -f "$TOOLCHAIN_FILE" ]; then
    echo "Error: CMake toolchain not found at $TOOLCHAIN_FILE"
    exit 1
fi

# --- Fetch Eigen (header-only, no build needed) ---
if [ ! -d "$EIGEN_DIR" ]; then
    echo "Fetching Eigen..."
    git clone --depth 1 --branch 3.4.0 \
        https://gitlab.com/libeigen/eigen.git "$EIGEN_DIR"
fi

# --- Create mobile-optimized config ---
CONFIG_DIR="$KATAGO_DIR/configs"
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/android-gtp.cfg" ]; then
    cp "$SCRIPT_DIR/../configs/android-gtp.cfg" "$CONFIG_DIR/" 2>/dev/null || true
fi

# --- Build ---
ABI="arm64-v8a"
mkdir -p "$BUILD_DIR/$ABI"
cd "$BUILD_DIR/$ABI"

cmake -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM=android-26 \
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
    "$SRC_DIR"

echo "Building KataGo for Android $ABI..."
cmake --build . -j"$(nproc 2>/dev/null || echo 4)" --target katago

# Copy output
BINARY_SRC="$BUILD_DIR/$ABI/katago"
BINARY_DST="$OUT_DIR/$ABI/katago"
mkdir -p "$OUT_DIR/$ABI"
cp "$BINARY_SRC" "$BINARY_DST"

echo ""
echo "=== Build complete ==="
echo "Binary: $BINARY_DST"
echo ""
echo "To integrate into the Android app:"
echo "cp $BINARY_DST ../../composeApp/src/main/assets/katago/$ABI/katago"
echo ""
echo "Binary size:"
ls -lh "$BINARY_DST"