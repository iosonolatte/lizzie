# Lizzie Mobile

A Flutter port of [Lizzie](https://github.com/featurecat/lizzie) — a real-time Go (Baduk/Weiqi) analysis frontend that talks to a [KataGo](https://github.com/lightvector/KataGo) engine over GTP.

This is the mobile counterpart to the Java desktop app in the parent directory. It currently ships as a remote-GTP client: the Flutter app connects to a KataGo process (running on the same device, a server on your LAN, or a cloud engine) and renders the analysis, board, and move list.

## Status

The Go rules engine (Zobrist hashing, captures, ko, handicap placement, SGF parser/serializer, board history navigation, move-data parsing from KataGo/LZ output) and the UI (board widget, analysis panel, move list, winrate chart, subboard, dialogs) are in place. Engine transport is remote-only for now — see [Engine](#engine) below.

## Build

Requires Flutter 3.44+ (Dart 3.12+).

```sh
cd lizzie_mobile
flutter pub get
flutter test         # 49 tests, covers board/SGF/handicap/MoveData
flutter analyze
flutter build apk --debug
```

## Engine

`RemoteEngine` and `MockEngine` are implemented; the app expects a KataGo-compatible GTP server at `host:port` (TLS optional). On Android, you can also bundle the native `katago` binary in the app's assets and have it run on-device; the engine plumbing is in place but the on-device `AndroidLocalEngine` is not yet wired into the UI.

A prebuilt `katago` binary for Android (arm64-v8a, x86_64) and a small GTP config are produced by the sibling CI workflow at `.github/workflows/katago-build.yml`.

## Project layout

```
lizzie_mobile/
  lib/
    engine/         # GTP client, engine interface, mock + remote impls
    go/             # board, SGF, handicap, MoveData, Zobrist, coords
    state/          # Riverpod providers and controllers
    ui/             # board widget, panels, dialogs, screens
  test/             # unit tests (board, SGF, widget render)
  android/          # standard Flutter Android module
  ios/              # standard Flutter iOS module
```

## CI

- `.github/workflows/build-apk.yml` — on every push/PR to `master`, `main`, or `mobile-flutter`: `pub get → dart format check → analyze → test → build apk --debug`. APK is uploaded as an artifact.
- `.github/workflows/katago-build.yml` — manual `workflow_dispatch`: clones upstream KataGo, builds arm64-v8a + x86_64 binaries, downloads a network model, and publishes a GitHub release.

## Related

- Parent project: [featurecat/lizzie](https://github.com/featurecat/lizzie) (Java desktop)
- Engine: [lightvector/KataGo](https://github.com/lightvector/KataGo)
