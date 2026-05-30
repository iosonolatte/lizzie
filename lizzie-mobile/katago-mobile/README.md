# KataGo Mobile Build Infrastructure

This directory contains scripts and configs for cross-compiling Katago for Android and iOS.

## Prerequisites

### Both platforms
- Git
- CMake 3.16+
- Eigen3 (header-only math library — fetched automatically)

### Android
- Android NDK (r26+ recommended)
  - Install via Android Studio: SDK Manager → SDK Tools → NDK
  - Or standalone: https://developer.android.com/ndk/downloads
  - Set `ANDROID_NDK_HOME` environment variable

### iOS (macOS only)
- Xcode 15+ with iOS SDK 17+
- A Mac with Apple Silicon or Intel

## Quick Start

### 1. Clone KataGo source

```bash
cd katago-mobile
git clone --depth 1 --branch v1.15.0 https://github.com/lightvector/KataGo.git src
```

Or use the helper:
```bash
bash scripts/clone-katago.sh
```

### 2. Build for Android

```bash
bash scripts/build-android.sh
```

Output: `out/android/arm64-v8a/katago` (binary to bundle in APK)

### 3. Build for iOS (macOS only)

```bash
bash scripts/build-ios.sh
```

Output: `out/ios/libkatago.a` (static library)

### 4. Download a mobile-optimized network

```bash
bash scripts/download-model.sh
```

Downloads a ~20MB model suitable for mobile into `models/`.

## Architecture

```
katago-mobile/
├── src/                    # KataGo source (git clone)
├── eigen/                  # Eigen3 header lib (auto-fetched)
├── out/android/            # Android binaries
│   └── arm64-v8a/katago    # Native executable
├── out/ios/                # iOS static libs
│   └── libkatago.a         # Static library
├── models/                 # KataGo network weights
│   ├── katago-mobile.bin.gz
│   └── model-version.txt
├── configs/                # Mobile-optimized KataGo configs
│   ├── android-gtp.cfg
│   └── ios-gtp.cfg
└── scripts/
    ├── clone-katago.sh
    ├── build-android.sh
    ├── build-ios.sh
    ├── build-ios-staticlib.sh   # iOS static lib variant
    └── download-model.sh
```

## Integration with Android App

The built `katago` binary is placed in:
```
composeApp/src/main/assets/katago/arm64-v8a/katago
composeApp/src/main/assets/katago/models/katago-mobile.bin.gz
composeApp/src/main/assets/katago/configs/gtp.cfg
```

The `AndroidLocalEngine` extracts these to internal storage on first launch.

## Integration with iOS App

The static library is linked via Xcode:
- Add `libkatago.a` to the Xcode project
- Add C header bridge for `katago_send()` / `katago_read()` functions
- Reference via `IosLocalEngine`'s cinterop bindings