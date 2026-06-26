# Lizzie

![screenshot](https://raw.githubusercontent.com/featurecat/lizzie/master/screenshot0.7.jpg?raw=true)

A real-time Go (Baduk/Weiqi) analysis frontend. This repository hosts
two implementations that share the same project goals and the upstream
[lightvector/KataGo](https://github.com/lightvector/KataGo) engine:

| Project | Path | Status |
| --- | --- | --- |
| **Lizzie** (Java desktop) | `./` | The original Swing GUI; builds with Maven, runs on any JVM. |
| **Lizzie Mobile** (Flutter) | [`lizzie_mobile/`](lizzie_mobile/) | Mobile/tablet frontend (Android + iOS). Talks to KataGo over GTP. |
| **Native katago for Android** | [`lizzie-mobile/katago-mobile/`](lizzie-mobile/katago-mobile/) | Cross-compiles upstream KataGo for `arm64-v8a` and `x86_64`. The Mobile app uses the produced binary to run KataGo on-device. |

CI: [![Build](https://github.com/iosonolatte/lizzie/actions/workflows/build.yml/badge.svg)](https://github.com/iosonolatte/lizzie/actions/workflows/build.yml) (Java) · [Build Flutter APK](https://github.com/iosonolatte/lizzie/actions/workflows/build-apk.yml) · [Build KataGo for Android](https://github.com/iosonolatte/lizzie/actions/workflows/katago-build.yml)

---

## Lizzie (Java desktop)

The original graphical interface for analyzing Go games in real time
using [Leela Zero](https://github.com/gcp/leela-zero) or KataGo. You
need Java 11 or higher to run this program.

### Running a release

Download the latest archive from the
[Releases page](https://github.com/featurecat/lizzie/releases/latest)
and follow the instructions in the bundled `readme`.

### Building from source

You will need:

- **JDK 11 or newer** (e.g. [Eclipse Temurin](https://adoptium.net/))
- **[Apache Maven](https://maven.apache.org/) 3.6+**
- A working **Leela Zero** or **KataGo** binary

#### Building Leela Zero (or use KataGo)

```sh
git clone --recursive --branch next https://github.com/gcp/leela-zero.git
# (or grab a KataGo release binary)
```

#### Building Lizzie

```sh
mvn clean package
```

The runnable JAR is in `target/` (look for the `-shaded.jar` suffix).

#### Running

```sh
java -jar target/lizzie-0.7.4-shaded.jar
```

After this command you should see a GUI start. Lizzie will also start
the Leela Zero / KataGo process and communicate with it. Configure the
engine path in `config.txt`.

### Usage tips

Hold down the key **x** to see all keyboard commands listed in the GUI.

---

## Lizzie Mobile (Flutter)

A Flutter port of Lizzie for Android and iOS. The Go rules engine
(Zobrist hashing, captures, ko, handicap, SGF parser, board history
navigation, KataGo/LZ move-data parsing) and the UI (board widget,
analysis panel, move list, winrate chart, subboard, dialogs) are
implemented. The app currently ships as a **remote-GTP client**: it
connects to a KataGo process running on the same device, a server on
your LAN, or a cloud engine.

See [`lizzie_mobile/README.md`](lizzie_mobile/README.md) for the full
project layout, build instructions, and current status.

### Build

Requires Flutter 3.44+ (Dart 3.12+).

```sh
cd lizzie_mobile
flutter pub get
flutter test
flutter build apk --debug
```

The CI workflow at `.github/workflows/build-apk.yml` runs on every push
to `master`, `main`, or `mobile-flutter` and uploads the debug APK as
an artifact.

### Native katago for Android

To run KataGo on-device, you need an Android NDK build of the engine
plus a network model. The CI workflow at
`.github/workflows/katago-build.yml` does this end-to-end and publishes
a GitHub Release with the prebuilt binaries (`arm64-v8a`, `x86_64`) and
a default neural-net model.

```sh
# Local build (requires Android NDK r27 + cmake + ninja)
cd lizzie-mobile/katago-mobile
bash scripts/clone-katago.sh v1.15.0
bash scripts/download-model.sh kata1-b18c384nbt-s9996604416-d4316597426
ANDROID_NDK_HOME=$ANDROID_HOME/ndk/27.0.12077973 bash scripts/build-android.sh
```

The output binaries land in `out/android/build/{arm64-v8a,x86_64}/katago`.

---

## Contributing

Pull requests are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md)
for general guidelines.

CI matrix:

- **Java desktop** — `mvn clean package` on Linux, macOS and Windows
  against JDK 11, 17 and 21; formatting enforced via
  `mvn com.coveo:fmt-maven-plugin:check`. Run locally with
  `mvn com.coveo:fmt-maven-plugin:format`.
- **Flutter mobile** — `flutter pub get`, `dart format` check,
  `flutter analyze`, `flutter test`, `flutter build apk --debug` on
  Ubuntu.
- **Native katago for Android** — manual `workflow_dispatch`; clones
  upstream KataGo, cross-compiles for `arm64-v8a` + `x86_64`, downloads
  a model, and publishes a GitHub release.

### Project layout

```
.
├── src/                    # Java desktop source (Lizzie Swing GUI)
├── pom.xml                 # Maven build for the desktop app
├── theme/                  # Default board themes (yasnaya, etc.)
├── lizzie_mobile/          # Flutter mobile app
│   ├── lib/                # Dart source
│   ├── android/            # Android module
│   ├── ios/                # iOS module
│   └── test/               # 49 unit tests (board, SGF, widget)
└── lizzie-mobile/          # Native build infrastructure
    └── katago-mobile/
        ├── scripts/         # clone-katago.sh, build-android.sh, etc.
        └── (src/, eigen/, out/, models/ are populated by the scripts)
```

## See also

- [Wiki](https://github.com/featurecat/lizzie/wiki) — usage guides
- [lightvector/KataGo](https://github.com/lightvector/KataGo) — the engine
- [gcp/leela-zero](https://github.com/gcp/leela-zero) — the original engine
- [featurecat/lizzie](https://github.com/featurecat/lizzie) — upstream Java app
