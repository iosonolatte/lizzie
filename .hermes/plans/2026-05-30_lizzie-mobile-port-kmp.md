# Lizzie Mobile (KMP) Implementation Plan

> **Goal:** Port Lizzie (desktop Go/Baduk analysis tool) to Android and iOS using Kotlin Multiplatform, with on-device KataGo as the primary engine and remote engine as fallback.

**Architecture:** KMP shared module (commonMain) for game logic, GTP protocol, engine interface, and SGF parsing. Platform-specific UIs: Jetpack Compose (Android) and SwiftUI (iOS). Engine layer abstracts over local process (Android NDK / iOS static lib) and remote WebSocket connection.

**Tech Stack:** Kotlin Multiplatform, Jetpack Compose (Android), SwiftUI (iOS), Gradle, Kotlin Coroutines/Flow, Kotlinx.serialization

---

## Source-Map: What Goes Where

**Reusable in `commonMain` (port from Java → Kotlin):**

| Java file | KMP target | Notes |
|---|---|---|
| `rules/Board.java` | `commonMain/.../rules/Board.kt` | Pure game state, no Swing |
| `rules/BoardData.java` | `commonMain/.../rules/BoardData.kt` | Data class, no Swing |
| `rules/BoardHistoryList.java` | `commonMain/.../rules/BoardHistoryList.kt` | Linked list + move logic |
| `rules/BoardHistoryNode.java` | `commonMain/.../rules/BoardHistoryNode.kt` | Node datastructure |
| `rules/Stone.java` | `commonMain/.../rules/Stone.kt` | Enum |
| `rules/Zobrist.java` | `commonMain/.../rules/Zobrist.kt` | Zobrist hashing |
| `rules/SGFParser.java` | `commonMain/.../rules/SGFParser.kt` | Pure parsing |
| `rules/GIBParser.java` | `commonMain/.../rules/GIBParser.kt` | Pure parsing |
| `rules/MoveList.java` | `commonMain/.../rules/MoveList.kt` | Data class |
| `analysis/MoveData.java` | `commonMain/.../analysis/MoveData.kt` | GTP line parsing |
| `analysis/Branch.java` | `commonMain/.../analysis/Branch.kt` | Analysis branch state |
| `analysis/GameInfo.java` | `commonMain/.../analysis/GameInfo.kt` | Game metadata |
| `analysis/LeelazListener.java` | `commonMain/.../analysis/EngineListener.kt` | Interface — rename |
| `Config.java` | `commonMain/.../config/Config.kt` | Data model only (strip Swing refs) |

**Must be rewritten per platform:**

| Area | Android | iOS |
|---|---|---|
| Board rendering | Jetpack Compose Canvas | SwiftUI Canvas / Metal |
| Touch/gesture | Compose gesture handlers | UIKit gesture recognizers |
| Winrate graph | Compose custom drawing | SwiftUI Path |
| Variation tree | Compose LazyColumn | SwiftUI List |
| GTP console | Compose Text + LazyColumn | SwiftUI ScrollView + Text |
| Settings UI | Compose PreferenceScreen | SwiftUI Form |
| Engine process mgmt | Android `Process` via NDK | N/A (use lib) |
| File picker (SGF) | ActivityResultContracts | UIDocumentPickerViewController |

**Engine layer (KMP with platform-specific implementations):**

- `commonMain`: `Engine` interface, `RemoteEngine` (WebSocket/TCP), GTP command/response models
- `androidMain`: `LocalEngine` — bundles KataGo binary in assets, spawns via NDK's `fork/exec` equivalent (JNI to C++)
- `iosMain`: `LocalEngine` — embeds Katago as a static library (pre-compiled for arm64), calls via C interop

---

## Phase 1: Project Scaffold + Shared Module Setup

### Task 1.1: Create KMP project structure

**Files to create:**

```
lizzie-mobile/
├── build.gradle.kts              # Root build file
├── settings.gradle.kts           # Project settings
├── gradle.properties             # KMP properties
├── gradle/
│   └── libs.versions.toml        # Version catalog
├── shared/
│   ├── build.gradle.kts          # Shared module build
│   └── src/
│       ├── commonMain/kotlin/com/lizzie/
│       │   └── rules/
│       ├── androidMain/kotlin/com/lizzie/
│       │   └── engine/
│       └── iosMain/kotlin/com/lizzie/
│           └── engine/
├── composeApp/
│   ├── build.gradle.kts
│   └── src/main/
│       ├── kotlin/com/lizzie/android/
│       │   ├── MainActivity.kt
│       │   └── ui/
│       ├── AndroidManifest.xml
│       └── res/
├── iosApp/
│   ├── iosApp.xcodeproj/
│   └── iosApp/
│       ├── ContentView.swift
│       ├── LizzieApp.swift
│       └── Views/
└── gradle/wrapper/
```

**Step 1: Create `settings.gradle.kts`**

```kotlin
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version("0.9.0")
}

rootProject.name = "LizzieMobile"

include(":shared")
include(":composeApp")
```

**Step 2: Create root `build.gradle.kts`**

```kotlin
plugins {
    alias(libs.plugins.androidApplication) apply false
    alias(libs.plugins.androidLibrary) apply false
    alias(libs.plugins.kotlinMultiplatform) apply false
    alias(libs.plugins.composeMultiplatform) apply false
    alias(libs.plugins.composeCompiler) apply false
    alias(libs.plugins.kotlinxSerialization) apply false
}
```

**Step 3: Create `gradle/libs.versions.toml`**

```toml
[versions]
agp = "8.7.3"
kotlin = "2.1.0"
compose-multiplatform = "1.7.3"
coroutines = "1.9.0"
ktor = "3.0.3"
kotlinx-serialization = "1.7.3"

[libraries]
kotlinx-coroutines-core = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-core", version.ref = "coroutines" }
kotlinx-serialization-json = { module = "org.jetbrains.kotlinx:kotlinx-serialization-json", version.ref = "kotlinx-serialization" }
ktor-client-core = { module = "io.ktor:ktor-client-core", version.ref = "ktor" }
ktor-client-okhttp = { module = "io.ktor:ktor-client-okhttp", version.ref = "ktor" }
ktor-client-darwin = { module = "io.ktor:ktor-client-darwin", version.ref = "ktor" }

[plugins]
androidApplication = { id = "com.android.application", version.ref = "agp" }
androidLibrary = { id = "com.android.library", version.ref = "agp" }
kotlinMultiplatform = { id = "org.jetbrains.kotlin.multiplatform", version.ref = "kotlin" }
composeMultiplatform = { id = "org.jetbrains.compose", version.ref = "compose-multiplatform" }
composeCompiler = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
kotlinxSerialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
```

**Step 4: Create `shared/build.gradle.kts`**

```kotlin
plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidLibrary)
    alias(libs.plugins.kotlinxSerialization)
}

kotlin {
    androidTarget()
    listOf(iosX64(), iosArm64(), iosSimulatorArm64()).forEach {
        it.binaries.framework {
            baseName = "shared"
            isStatic = true
        }
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.kotlinx.serialization.json)
            implementation(libs.ktor.client.core)
        }
        androidMain.dependencies {
            implementation(libs.ktor.client.okhttp)
        }
        iosMain.dependencies {
            implementation(libs.ktor.client.darwin)
        }
    }
}

android {
    namespace = "com.lizzie.shared"
    compileSdk = 35
    defaultConfig { minSdk = 26 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
```

**Step 5: Create shared module directory skeleton**

Create all the package directories under `shared/src/commonMain/kotlin/com/lizzie/`:
- `rules/`
- `analysis/`
- `engine/`
- `config/`

**Verify:** `./gradlew :shared:build` succeeds (even with empty source dirs)

---

## Phase 2: Port Core Game Logic to commonMain

### Task 2.1: Port `Stone.java` → `rules/Stone.kt`

**Objective:** Enum representing stone colors.

**File:** `shared/src/commonMain/kotlin/com/lizzie/rules/Stone.kt`

```kotlin
package com.lizzie.rules

enum class Stone(val value: Int) {
    EMPTY(0),
    BLACK(1),
    WHITE(2);

    fun opposite(): Stone = when (this) {
        BLACK -> WHITE
        WHITE -> BLACK
        EMPTY -> EMPTY
    }

    fun isBlack(): Boolean = this == BLACK
    fun isWhite(): Boolean = this == WHITE
    fun isNotEmpty(): Boolean = this != EMPTY
    fun isStone(): Boolean = this == BLACK || this == WHITE
}
```

**Verify:** `:shared:build` passes.

### Task 2.2: Port `BoardData.java` → `rules/BoardData.kt`

**Objective:** Data class holding a single board position.

**File:** `shared/src/commonMain/kotlin/com/lizzie/rules/BoardData.kt`

Port the fields and methods, replacing:
- `Optional<int[]>` → `IntArray?`
- `HashMap` → `MutableMap`
- Remove all `Lizzie.config` static references (pass config as params instead)
- Remove `bestMovesToString()` (UI concern)
- Keep `tryToSetBestMoves()`, `tryToClearBestMoves()` and related analysis state

```kotlin
package com.lizzie.rules

import com.lizzie.analysis.MoveData

data class BoardData(
    val stones: StoneArray,           // typed wrapper around IntArray
    val lastMove: Pair<Int, Int>?,    // (x, y)
    val lastMoveColor: Stone,
    val blackToPlay: Boolean,
    val zobrist: Zobrist = Zobrist(),
    val moveNumber: Int = 0,
    val moveMNNumber: Int = -1,
    val moveNumberList: IntArray,
    val blackCaptures: Int = 0,
    val whiteCaptures: Int = 0,
    val winrate: Double = 50.0,
    val playouts: Int = 0,
    val scoreMean: Double = 0.0,
    val engineIndex: Int = -1,
    val komi: Double = 0.0,
    val bestMoves: List<MoveData> = emptyList(),
    val comment: String = "",
    val properties: Map<String, String> = emptyMap(),
) {
    fun tryToSetBestMoves(moves: List<MoveData>): BoardData {
        if (MoveData.getPlayouts(moves) > playouts) {
            return copy(
                bestMoves = moves,
                playouts = MoveData.getPlayouts(moves),
                winrate = MoveData.getWinrateFromBestMoves(moves),
                scoreMean = MoveData.getScoreMeanFromBestMoves(moves)
            )
        }
        return this
    }

    companion object {
        fun empty(size: Int): BoardData = BoardData(
            stones = StoneArray(size * size) { Stone.EMPTY },
            lastMove = null,
            lastMoveColor = Stone.EMPTY,
            blackToPlay = true,
            zobrist = Zobrist(),
            moveNumber = 0,
            moveNumberList = IntArray(size * size),
            winrate = 50.0
        )
    }
}
```

**Create `StoneArray.kt`** — an inline wrapper around `IntArray` for type safety:

```kotlin
@JvmInline
value class StoneArray(val values: IntArray) {
    operator fun get(index: Int): Stone = Stone.fromValue(values[index])
    operator fun set(index: Int, stone: Stone) { values[index] = stone.value }
    fun clone(): StoneArray = StoneArray(values.copyOf())
    val size: Int get() = values.size
}
```

**Verify:** `:shared:build` passes.

### Task 2.3: Port `Zobrist.java` → `rules/Zobrist.kt`

**Objective:** Zobrist hashing for superko detection.

**File:** `shared/src/commonMain/kotlin/com/lizzie/rules/Zobrist.kt`

Port the hash generation logic — uses Kotlin's `Random` with fixed seeds for reproducibility. Remove `java.awt.Color` dependency (original uses it for random seed generation; use a simple Long seed instead).

### Task 2.4: Port `Board.java` → `rules/Board.kt`

**Objective:** Complete game state management.

**File:** `shared/src/commonMain/kotlin/com/lizzie/rules/Board.kt`

Port all static methods and state. Key methods:
- `isValid(x, y)` — coordinate validation
- `getIndex(x, y)` — 1D index from 2D coords
- `removeDeadChain(x, y, color, stones, zobrist)` — capture logic
- `convertCoordinatesToName(x, y)` — SGF coordinate conversion
- `asCoordinates(name)` — reverse conversion
- `getNeighbors(x, y)` — adjacent points
- `getGroup(x, y, stones)` — connected stones via flood fill

Replace `List<int[]>` returns with `List<Pair<Int, Int>>`. Replace `JOptionPane` usage with return codes or exceptions.

**Verify:** Write a simple test that places stones and verifies captures.

### Task 2.5: Port `BoardHistoryNode.java` → `rules/BoardHistoryNode.kt`

**Objective:** Linked list node for move history.

**File:** `shared/src/commonMain/kotlin/com/lizzie/rules/BoardHistoryNode.kt`

Port singly-linked list with branching support.

### Task 2.6: Port `BoardHistoryList.java` → `rules/BoardHistoryList.kt`

**Objective:** Move history traversal and manipulation.

**File:** `shared/src/commonMain/kotlin/com/lizzie/rules/BoardHistoryList.kt`

Port `place()`, `pass()`, `previous()`, `next()`, `addOrGoto()`, and branch management. Remove `Lizzie.frame` references (callbacks instead). Make `synchronized` blocks use Kotlin's `@Synchronized` annotation.

### Task 2.7: Port `SGFParser.java` → `rules/SGFParser.kt`

**Objective:** SGF file parsing.

**File:** `shared/src/commonMain/kotlin/com/lizzie/rules/SGFParser.kt`

Port the SGF parser. It's pure string manipulation, should port cleanly. Remove `JOptionPane` error handling — throw exceptions or return `Result`.

Include:
- `parseSgf(String)` → returns parsed game tree
- `saveSgf(BoardHistoryList, GameInfo)` → returns SGF string
- Property key-value parsing

### Task 2.8: Port `GIBParser.java` → `rules/GIBParser.kt`

**Objective:** GIB file format parsing.

**File:** `shared/src/commonMain/kotlin/com/lizzie/rules/GIBParser.kt`

Pure text parsing, ports cleanly.

**Verify:** Write tests for SGF round-trip (parse → save → re-parse match).

---

## Phase 3: Engine Abstraction Layer

### Task 3.1: Define `Engine` interface

**File:** `shared/src/commonMain/kotlin/com/lizzie/engine/Engine.kt`

```kotlin
package com.lizzie.engine

import com.lizzie.analysis.MoveData
import kotlinx.coroutines.flow.Flow

/** Result of engine analysis for a position. */
data class AnalysisResult(
    val bestMoves: List<MoveData>,
    val ownership: List<Double>?,    // KataGo territory ownership
    val scoreMean: Double,
    val scoreStdev: Double,
    val currentPlayouts: Int,
)

/** Status of the engine connection. */
sealed interface EngineStatus {
    data object Disconnected : EngineStatus
    data class Connecting(val info: String) : EngineStatus
    data class Ready(val engineName: String, val version: String) : EngineStatus
    data class Error(val message: String) : EngineStatus
}

/** Engine configuration. */
sealed interface EngineConfig {
    data class Local(
        val engineCommand: String,
        val weightsPath: String,
        val configPath: String? = null,
    ) : EngineConfig

    data class Remote(
        val host: String,
        val port: Int,
        val useTls: Boolean = false,
    ) : EngineConfig

    data object None : EngineConfig
}

/** Core engine interface for Go analysis. */
interface Engine {
    val status: Flow<EngineStatus>
    val analysis: Flow<AnalysisResult>

    /** Start the engine with given config. */
    suspend fun start(config: EngineConfig)

    /** Stop the engine. */
    suspend fun stop()

    /** Set board size and komi. */
    suspend fun initGame(boardSize: Int, komi: Double = 6.5, handicap: Int = 0)

    /** Play a move on the engine's internal board. */
    suspend fun playMove(color: Stone, coordinate: String?)

    /** Undo last move. */
    suspend fun undoMove()

    /** Start pondering on current position. */
    suspend fun startPonder()

    /** Stop pondering. */
    suspend fun stopPonder()

    /** Send a raw GTP command and get response. */
    suspend fun sendGtpCommand(command: String): String
}
```

### Task 3.2: Port `MoveData.java` → `analysis/MoveData.kt`

**File:** `shared/src/commonMain/kotlin/com/lizzie/analysis/MoveData.kt`

Port the data class and parsing methods (`fromInfoKatago`, `fromInfo`, `fromSummary`). These are pure regex/string parsing and port directly.

```kotlin
@Serializable
data class MoveData(
    val coordinate: String,
    val playouts: Int,
    val winrate: Double,
    val scoreMean: Double = 0.0,
    val scoreStdev: Double = 0.0,
    val policy: Double = 0.0,
    val lcb: Double = 0.0,
    val utility: Double = 0.0,
    val order: Int = 0,
    val variation: List<String> = emptyList(),
) {
    companion object {
        fun fromInfoKatago(line: String): MoveData { /* port from Java */ }
        fun fromInfo(line: String): MoveData { /* port from Java */ }
        fun fromSummary(line: String): MoveData { /* port from Java */ }
        fun getPlayouts(moves: List<MoveData>): Int = moves.sumOf { it.playouts }
        fun getWinrateFromBestMoves(moves: List<MoveData>): Double { /* weighted average */ }
        fun getScoreMeanFromBestMoves(moves: List<MoveData>): Double { /* weighted average */ }
    }
}
```

### Task 3.3: Implement `RemoteEngine` (commonMain)

**File:** `shared/src/commonMain/kotlin/com/lizzie/engine/RemoteEngine.kt`

Connect to a remote KataGo instance over TCP or WebSocket. KataGo supports GTP over TCP with `--gtp` flag.

- Use Ktor client for network transport
- Parse GTP responses line-by-line
- Send `kata-analyze` commands for pondering
- Expose analysis via `MutableStateFlow<AnalysisResult>`

```kotlin
class RemoteEngine : Engine {
    private val _status = MutableStateFlow<EngineStatus>(EngineStatus.Disconnected)
    override val status: Flow<EngineStatus> = _status.asStateFlow()

    private val _analysis = MutableStateFlow<AnalysisResult>(...)
    override val analysis: Flow<AnalysisResult> = _analysis.asStateFlow()

    override suspend fun start(config: EngineConfig) {
        val c = config as EngineConfig.Remote
        _status.value = EngineStatus.Connecting("Connecting to ${c.host}:${c.port}")
        // Ktor TCP socket connect
        // GTP handshake: name, version, boardsize, komi
        _status.value = EngineStatus.Ready(name, version)
    }

    // ... GTP command/response with cmdNumber tracking
}
```

### Task 3.4: Implement `AndroidLocalEngine` (androidMain)

**File:** `shared/src/androidMain/kotlin/com/lizzie/engine/AndroidLocalEngine.kt`

Android implementation that spawns KataGo binary as a subprocess:

- Copy KataGo binary from Android assets to internal storage on first run
- Use `ProcessBuilder` (Java interop) to spawn `/proc/self/fd/...` or extracted path
- Connect stdin/stdout for GTP communication
- Same GTP parsing as RemoteEngine, different transport layer
- Handle process lifecycle (start/stop/restart)
- Handle engine crash detection

```kotlin
class AndroidLocalEngine(private val context: Context) : Engine {
    private var process: Process? = null

    override suspend fun start(config: EngineConfig) {
        val c = config as EngineConfig.Local
        // Extract binary from assets
        val binaryPath = extractBinary("katago")
        val configPath = extractConfig(c.configPath)

        val pb = ProcessBuilder(
            binaryPath, "gtp",
            "-model", c.weightsPath,
            "-config", configPath
        )
        process = pb.start()
        // Start reader coroutine on Dispatchers.IO
        // GTP handshake
    }
}
```

### Task 3.5: Implement `IosLocalEngine` (iosMain)

**File:** `shared/src/iosMain/kotlin/com/lizzie/engine/IosLocalEngine.kt`

iOS cannot spawn subprocesses. Two options:

**Option A (recommended):** Use a C/C++ interop with a statically-linked KataGo.
- KataGo compiled as a static library (`libkatago.a`) for arm64
- Define a C interop layer that calls `KataGo::initialize()` and routes stdin/stdout through a pipe
- Use `kotlinx.cinterop` to bridge

**Option B:** Use CoreML / ANE with a converted KataGo model. Less compatible (KataGo's architecture doesn't map directly).

For the plan, we target Option A with a note that the KataGo binary compilation is a separate project:

```kotlin
class IosLocalEngine : Engine {
    // Uses cinterop to katago_c_bridge
    // Pipe-based GTP communication
    // Same interface as AndroidLocalEngine
}
```

### Task 3.6: Port `GameInfo.java` → `analysis/GameInfo.kt`

**File:** `shared/src/commonMain/kotlin/com/lizzie/analysis/GameInfo.kt`

```kotlin
data class GameInfo(
    val playerBlack: String = "",
    val playerWhite: String = "",
    val komi: Double = 6.5,
    val handicap: Int = 0,
    val ruleSet: String = "jp",
    val gameName: String = "",
    val gameDate: String = "",
    val result: String = "",
)
```

### Task 3.7: Port config data model (commonMain)

**File:** `shared/src/commonMain/kotlin/com/lizzie/config/LizzieConfig.kt`

Port the config data model from `Config.java`, stripping all UI references (Color, Font, WindowPosition, etc.):

```kotlin
@Serializable
data class LizzieConfig(
    // Board display
    val showMoveNumber: Boolean = false,
    val showCoordinates: Boolean = false,
    val showWinrate: Boolean = true,
    val showScoreMean: Boolean = true,
    val boardSize: Int = 19,

    // Analysis display
    val showBestMoves: Boolean = true,
    val showVariationGraph: Boolean = true,
    val limitBestMoveNum: Int = 0,
    val limitBranchLength: Int = 0,

    // Engine
    val engineMode: EngineMode = EngineMode.Local,
    val engineCommand: String = "",
    val weightsPath: String = "",
    val remoteHost: String = "",
    val remotePort: Int = 9000,
    val maxAnalyzeTimeMinutes: Int = 99999,
)

enum class EngineMode { Local, Remote, None }
```

---

## Phase 4: Android UI (Jetpack Compose)

### Task 4.1: Create Android app scaffold

**Files:**
- `composeApp/build.gradle.kts`
- `composeApp/src/main/kotlin/com/lizzie/android/MainActivity.kt`
- `composeApp/src/main/AndroidManifest.xml`

Set up Compose Multiplatform app module with navigation (Voyager or compose-nav).

### Task 4.2: Board Canvas renderer

**File:** `composeApp/src/main/kotlin/com/lizzie/android/ui/board/BoardCanvas.kt`

Implement Go board rendering using Jetpack Compose Canvas:

```kotlin
@Composable
fun BoardView(
    boardData: BoardData,
    bestMoves: List<MoveData>,
    showCoordinates: Boolean,
    onIntersectionClick: (x: Int, y: Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val density = LocalDensity.current

    Canvas(modifier = modifier.aspectRatio(1f).pointerInput(Unit) {
        detectTapGestures { offset ->
            // Convert pixel offset to board coordinates
            val (x, y) = pixelToBoard(offset, size, boardSize, density)
            onIntersectionClick(x, y)
        }
    }) {
        val squareSize = size.width / (boardSize + marginFraction * 2)

        // 1. Draw board background (wood color)
        drawRect(color = Color(0xFFDEB887))

        // 2. Draw grid lines
        for (i in 0 until boardSize) {
            val x = px(i)
            drawLine(Color.Black, Offset(x, px(0)), Offset(x, px(boardSize - 1)))
        }

        // 3. Draw star points
        starPoints(boardSize).forEach { (x, y) ->
            drawCircle(Color.Black, starRadius, Offset(px(x), px(y)))
        }

        // 4. Draw stones with shadows
        for (y in 0 until boardSize) {
            for (x in 0 until boardSize) {
                when (boardData.stones[Board.getIndex(x, y)]) {
                    Stone.BLACK -> drawBlackStone(...)
                    Stone.WHITE -> drawWhiteStone(...)
                    Stone.EMPTY -> { /* draw move number if enabled */ }
                }
            }
        }

        // 5. Draw last move marker
        boardData.lastMove?.let { (x, y) ->
            drawCircle(Color.Red, markerRadius, Offset(px(x), px(y)))
        }

        // 6. Draw analysis overlay (winrate labels, best move indicators)
        if (showAnalysis) {
            drawAnalysisOverlay(bestMoves, boardData)
        }
    }
}
```

Create sub-composables:
- `StoneComponent` — single stone with 3D gradient effect
- `AnalysisOverlay` — winrate labels, heatmap, move suggestions
- `StarPointIndicator` — standard star points for board size

### Task 4.3: Move number display

**File:** `composeApp/src/main/kotlin/com/lizzie/android/ui/board/MoveNumberOverlay.kt`

Render move numbers on stones when enabled. Use DrawScope.drawText() or layered Text composables.

### Task 4.4: Winrate graph

**File:** `composeApp/src/main/kotlin/com/lizzie/android/ui/analysis/WinrateGraph.kt`

Line chart showing winrate over move history:

```kotlin
@Composable
fun WinrateGraph(
    history: BoardHistoryList,
    modifier: Modifier = Modifier,
) {
    // Canvas with Path for winrate line
    // Color gradient (blue→red for black, reversed for white)
    // Horizontal/vertical grid lines
}
```

### Task 4.5: Best moves panel

**File:** `composeApp/src/main/kotlin/com/lizzie/android/ui/analysis/BestMovesPanel.kt`

Column listing top moves with winrate, playouts, score mean. Tapping a move shows its variation. Swipe to show sub-board analysis.

### Task 4.6: Variation tree

**File:** `composeApp/src/main/kotlin/com/lizzie/android/ui/analysis/VariationTree.kt`

Horizontal scrollable tree showing move branches. Tap to navigate. Compact layout for mobile.

### Task 4.7: GTP console

**File:** `composeApp/src/main/kotlin/com/lizzie/android/ui/console/GtpConsole.kt`

Scrollable log view with command/response coloring. Input field for raw GTP. Collapsible panel.

### Task 4.8: SGF browser

**File:** `composeApp/src/main/kotlin/com/lizzie/android/ui/sgf/SgfBrowser.kt`

File picker to load SGF files. Parsed game list with metadata (players, date, result). Quick preview of first few moves.

### Task 4.9: Settings screen

**File:** `composeApp/src/main/kotlin/com/lizzie/android/ui/settings/SettingsScreen.kt`

- Engine type selector (Local / Remote)
- Local engine: binary path, weights file, config file (file pickers)
- Remote engine: host, port fields
- Display options: coordinates, move numbers, winrate display
- Theme: light/dark
- Board size selector (9, 13, 19)

### Task 4.10: Main screen composition

**File:** `composeApp/src/main/kotlin/com/lizzie/android/ui/MainGameScreen.kt`

Assemble all components in a mobile-friendly layout:

```
┌─────────────────────┐
│  Toolbar (SGF, ⚙)   │
├─────────────────────┤
│                     │
│   Board (takes      │
│   most of screen)   │
│                     │
├─────────────────────┤
│ Winrate Graph (tap  │
│ to expand/collapse) │
├─────────────────────┤
│ Best Moves Panel    │
│ (scrollable chips)  │
└─────────────────────┘
```

Landscape mode: board on left, analysis panels on right.

### Task 4.11: Game state ViewModel

**File:** `composeApp/src/main/kotlin/com/lizzie/android/viewmodel/GameViewModel.kt`

```kotlin
class GameViewModel(
    private val engine: Engine,
) : ViewModel() {
    private val _gameState = MutableStateFlow(BoardState.empty())
    val gameState: StateFlow<BoardState> = _gameState.asStateFlow()

    private val _engineStatus = MutableStateFlow<EngineStatus>(EngineStatus.Disconnected)
    val engineStatus: StateFlow<EngineStatus> = _engineStatus.asStateFlow()

    fun onIntersectionClick(x: Int, y: Int) {
        viewModelScope.launch {
            history.place(x, y, currentColor)
            engine.playMove(currentColor, toGtpCoord(x, y))
            engine.startPonder()
        }
    }

    fun loadSgf(content: String) {
        viewModelScope.launch {
            val game = SGFParser.parseSgf(content)
            history = game.history
            engine.initGame(boardSize, game.info.komi)
            // Sync engine board state
            syncEngineBoard()
            engine.startPonder()
        }
    }
}
```

---

## Phase 5: iOS UI (SwiftUI)

### Task 5.1: Create iOS app scaffold

**Files:**
- `iosApp/iosApp/LizzieApp.swift`
- `iosApp/iosApp/ContentView.swift`
- `iosApp/iosApp.xcodeproj/` — via Xcode or `./gradlew :shared:podInstall`

The iOS app loads the `shared` framework (KMP framework output) and uses SwiftUI for all UI.

### Task 5.2: Board view with SwiftUI Canvas

**File:** `iosApp/iosApp/Views/BoardView.swift`

```swift
import SwiftUI
import shared

struct BoardView: View {
    let boardData: BoardData
    let bestMoves: [MoveData]
    let showCoordinates: Bool
    let onIntersectionTap: (Int32, Int32) -> Void

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            Canvas { context, canvasSize in
                let squareSize = canvasSize.width / CGFloat(boardSize + marginFraction * 2)

                // Draw background
                context.fill(
                    Path(CGRect(origin: .zero, size: canvasSize)),
                    with: .color(Color(red: 0.87, green: 0.72, blue: 0.53))
                )

                // Draw grid lines
                for i in 0..<boardSize {
                    let px = squareSize * (CGFloat(i) + margin)
                    var linePath = Path()
                    linePath.move(to: CGPoint(x: px, y: squareSize * margin))
                    linePath.addLine(to: CGPoint(x: px, y: squareSize * (CGFloat(boardSize - 1) + margin)))
                    context.stroke(linePath, with: .color(.black), lineWidth: 1)
                    // horizontal lines...
                }

                // Draw stones
                for y in 0..<boardSize {
                    for x in 0..<boardSize {
                        let stone = boardData.stones.values[Int(Board.companion.getIndex(x: x, y: y))]
                        // Draw stone with gradient
                    }
                }
            }
            .gesture(TapGesture().onEnded {
                // convert tap location to board coordinates
            })
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
```

### Task 5.3: Analysis panels (SwiftUI)

**Files:**
- `iosApp/iosApp/Views/WinrateGraphView.swift`
- `iosApp/iosApp/Views/BestMovesView.swift`
- `iosApp/iosApp/Views/VariationTreeView.swift`

SwiftUI equivalents of the Jetpack Compose panels. Use Swift Charts for winrate graph.

### Task 5.4: Main game view

**File:** `iosApp/iosApp/Views/GameView.swift`

```
VStack {
    HStack {
        BoardView(...)
        if horizontalSizeClass == .regular {
            BestMovesView(...)
        }
    }
    WinrateGraphView(...)
    BestMovesView(...) // in compact width
}
```

### Task 5.5: SGF browser (iOS)

**File:** `iosApp/iosApp/Views/SgfBrowserView.swift`

Use `UIDocumentPickerViewController` wrapped in `UIViewControllerRepresentable`.

### Task 5.6: Settings (iOS)

**File:** `iosApp/iosApp/Views/SettingsView.swift`

SwiftUI Form with sections for engine config and display options.

---

## Phase 6: Integration & Polish

### Task 6.1: Engine lifecycle management

- ViewModel/Controller starts engine on app launch
- Handle reconnect for remote engine
- Graceful degradation: if local engine fails, prompt for remote config
- Background/foreground handling: pause pondering when app is backgrounded

### Task 6.2: Error handling

- Engine crash → toast + reconnect button
- Network timeout → retry with backoff
- SGF parse failure → show error message with line number
- Board state mismatch between UI and engine → resync

### Task 6.3: Touch optimizations

- Haptic feedback on stone placement
- Long press on intersection → show variation preview
- Pinch to zoom on board (optional)
- Swipe left/right on board → navigate move history
- Two-finger tap → toggle coordinate display

### Task 6.4: Performance

- Limit kata-analyze output frequency on mobile (lower playouts than desktop)
- Stone rendering using bitmap cache (render once, cache as image)
- Analysis overlay update throttling (max 4 updates/sec)
- Memory: prune old analysis data from BoardHistoryList

### Task 6.5: KataGo compilation for mobile

**Android:** Cross-compile KataGo using Android NDK:
```bash
# Using Android NDK CMake toolchain
cmake -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a \
      -DCMAKE_BUILD_TYPE=Release \
      -DUSE_OPENCL=OFF \
      -DUSE_CUDA=OFF \
      -DUSE_TENSORRT=OFF \
      -DUSE_BACKEND=EIGEN \
      ..
make -j8
```

**iOS:** Cross-compile KataGo as a static library:
```bash
# Using apple toolchain for arm64-apple-ios
cmake -DCMAKE_TOOLCHAIN_FILE=cmake/ios.toolchain.cmake \
      -DPLATFORM=OS64 \
      -DCMAKE_BUILD_TYPE=Release \
      -DUSE_OPENCL=OFF \
      -DUSE_CUDA=OFF \
      -DUSE_TENSORRT=OFF \
      -DUSE_BACKEND=EIGEN \
      ..
make -j8
# Produces libkatago.a
```

Bundle the binary in the app's assets (Android) or framework bundle (iOS).

For first release, bundle a small-to-medium KataGo network file (~20MB) for reasonable mobile performance.

---

## Implementation Order

```
Phase 1: Project scaffold
  │
  ▼
Phase 2: commonMain game logic
  │
  ▼
Phase 3: Engine abstraction + RemoteEngine (can test with desktop KataGo)
  │
  ▼
Phase 4: Android UI (Compose) — can test with RemoteEngine first
  │
  ▼
Phase 5: iOS UI (SwiftUI) — can test with RemoteEngine first
  │
  ▼
Phase 6: Local engine + KataGo compilation + polish
```

---

## Key Risks & Mitigations

| Risk | Mitigation |
|---|---|
| KataGo binary size (50MB+) | Offer smaller network files; download on first launch |
| iOS cannot spawn processes | Use static library linking (Option A) or CoreML (Option B) |
| Mobile CPU/thermal throttling | Limit playouts; auto-pause when not on screen; prefer remote engine for serious analysis |
| GTP protocol differences | Test against KataGo 1.15+; keep the `isKataGo` flag logic |
| SGF encoding issues | Port EncodingDetector or default to UTF-8 |
| KMP Compose Multiplatform maturity | Android-first. iOS can use pure SwiftUI if Compose Multiplatform iOS is unstable |

---

## Verification Milestones

1. **M1**: `:shared:build` passes, core game logic unit tests pass (stone placement, captures, ko, SGF round-trip)
2. **M2**: RemoteEngine connects to a desktop KataGo instance, analysis flow emits MoveData updates
3. **M3**: Android app renders a 19x19 board, stones appear on tap, winrate graph shows
4. **M4**: Android app loads SGF, navigates moves, displays analysis from remote KataGo
5. **M5**: iOS app matches Android feature set
6. **M6**: AndroidLocalEngine works with bundled KataGo
7. **M7**: IosLocalEngine works with compiled libkatago.a
8. **M8**: Play store / TestFlight release