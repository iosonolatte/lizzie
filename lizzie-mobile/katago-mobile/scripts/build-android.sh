#!/usr/bin/env bash
# Builds the KataGo binary for Android (arm64-v8a and x86_64).
# Expects ANDROID_NDK_HOME and ANDROID_HOME to be set, and src/ to be present.
set -euo pipefail

: "${ANDROID_NDK_HOME:?ANDROID_NDK_HOME must be set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

TOOLCHAIN="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake"
SRC="$SCRIPT_DIR/../src/cpp"

build_for_abi() {
  local abi="$1"
  local build_dir="out/android/build/$abi"
  echo "[build-android] Configuring $abi"
  cmake -B "$build_dir" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DANDROID_ABI="$abi" \
    -DANDROID_PLATFORM=android-26 \
    -DUSE_TCMALLOC=OFF \
    -DBUILD_DISTRIBUTED=OFF \
    "$SRC"
  echo "[build-android] Compiling $abi"
  cmake --build "$build_dir" --target katago
}

build_for_abi arm64-v8a
build_for_abi x86_64
