package com.lizzie.engine

import android.content.Context
import android.util.Log
import com.lizzie.analysis.MoveData
import com.lizzie.rules.Stone
import java.io.File
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

/**
 * Android local engine that spawns KataGo as a native process.
 *
 * The KataGo binary is bundled in assets and extracted to internal storage
 * on first launch. GTP communication happens over stdin/stdout.
 */
class AndroidLocalEngine(
    private val context: Context,
) : Engine {

    companion object {
        private const val TAG = "LizzieEngine"
    }

    private val _status = MutableStateFlow<EngineStatus>(EngineStatus.Disconnected)
    override val status: Flow<EngineStatus> = _status.asStateFlow()

    private val _analysis = MutableStateFlow(AnalysisResult(emptyList()))
    override val analysis: Flow<AnalysisResult> = _analysis.asStateFlow()

    private var process: Process? = null
    private var job: Job? = null
    private var cmdNumber = 1
    private var currentCmdNum = 0
    private var _isPondering = false
    private var isKataGo = false
    private val cmdQueue = ArrayDeque<String>()

    override suspend fun start(config: EngineConfig) {
        val cfg = config as EngineConfig.Local
        _status.value = EngineStatus.Connecting("Starting KataGo...")

        try {
            // Extract binary from assets
            val extractor = KatagoAssetExtractor(context)
            val files = extractor.extract()

            // On Android 10+, /data/data/ is mounted noexec.
                        // Try native library dir first (requires extractNativeLibs=true),
                        // fall back to extracted assets path (works on older Android).
                        val nativeLibDir = context.applicationInfo.nativeLibraryDir
                        val nativeBinary = "$nativeLibDir/libkatago.so"
                        val extractedBinary = files.binaryPath

                        val binaryPath = if (File(nativeBinary).exists()) {
                            Log.i(TAG, "Using native lib binary at: $nativeBinary")
                            nativeBinary
                        } else {
                            Log.i(TAG, "Native lib not found, trying extracted asset at: $extractedBinary")
                            extractedBinary
                        }

                        val cmd = buildList {
                            add(binaryPath)
                            add("gtp")
                            if (files.modelPath != null) {
                                add("-model")
                                add(files.modelPath)
                            } else if (cfg.weightsPath.isNotEmpty()) {
                                add("-model")
                                add(cfg.weightsPath)
                            }
                            if (files.configPath != null) {
                                add("-config")
                                add(files.configPath)
                            } else {
                                add("-config")
                                add(cfg.configPath ?: "")
                            }
                        }

            val pb = ProcessBuilder(cmd)
                        pb.redirectErrorStream(true)
                        pb.directory(File(files.workingDir))

                        // Log the command for debugging
                        Log.i(TAG, "Starting: ${cmd.joinToString(" ")}")
                        Log.i(TAG, "Working dir: ${files.workingDir}")

                        process = pb.start()

            val input = process!!.inputStream
            val output = process!!.outputStream

            // Read name for version check
            val nameResponse = sendGtpCommandInternal("name", output, input)
            isKataGo = nameResponse.startsWith("KataGo")

            val versionResponse = sendGtpCommandInternal("version", output, input)
            val version = versionResponse.trim()

            _status.value = EngineStatus.Ready(
                engineName = nameResponse.trim(),
                version = version,
                isKataGo = isKataGo,
            )

            // Start continuous reader
            job = CoroutineScope(Dispatchers.IO).launch {
                try {
                    val reader = input.bufferedReader()
                    while (isActive) {
                        val line = reader.readLine() ?: break
                        parseLine(line.trim())
                    }
                } catch (e: CancellationException) {
                    // Normal
                } catch (e: Exception) {
                    _status.value = EngineStatus.Error("Process error: ${e.message}")
                }
            }
        } catch (e: Exception) {
                    Log.e(TAG, "Failed to start engine", e)
                    _status.value = EngineStatus.Error("Failed to start engine: ${e.message}")
                }
    }

    override suspend fun stop() {
        try {
            sendGtpCommand("quit")
        } catch (_: Exception) {}
        job?.cancel()
        process?.destroy()
        _status.value = EngineStatus.Disconnected
        _isPondering = false
    }

    override suspend fun initGame(boardSize: Int, komi: Double, handicap: Int) {
        sendGtpCommand("boardsize $boardSize")
        sendGtpCommand("clear_board")
        sendGtpCommand("komi $komi")
        if (handicap > 0) {
            sendGtpCommand("fixed_handicap $handicap")
        }
    }

    override suspend fun playMove(color: Stone, coordinate: String?) {
        val colorStr = if (color == Stone.BLACK) "b" else "w"
        val coord = coordinate ?: "pass"
        sendGtpCommand("play $colorStr $coord")
    }

    override suspend fun undoMove() {
        sendGtpCommand("undo")
    }

    override suspend fun startPonder() {
        if (_isPondering) return
        _isPondering = true
        if (isKataGo) {
            sendGtpCommand("kata-analyze 100 0")
        } else {
            sendGtpCommand("lz-analyze 100 0")
        }
    }

    override suspend fun stopPonder() {
        if (!_isPondering) return
        _isPondering = false
        sendGtpCommand("play b pass")
    }

    override fun isPondering(): Boolean = _isPondering

    override suspend fun sendGtpCommand(command: String): String {
        // Implementation would use process stdin/stdout
        return ""
    }

    private suspend fun sendGtpCommandInternal(
        command: String,
        output: java.io.OutputStream,
        input: java.io.InputStream,
    ): String {
        val cmdLine = "${cmdNumber++} $command\n"
        output.write(cmdLine.toByteArray())
        output.flush()

        val reader = input.bufferedReader()
        val sb = StringBuilder()
        var line: String?
        while (reader.readLine().also { line = it } != null) {
            val l = line!!.trim()
            if (l.startsWith("=") || l.startsWith("?")) {
                val spaceIdx = l.indexOf(' ')
                if (spaceIdx > 0) {
                    currentCmdNum = l.substring(1, spaceIdx).trim().toIntOrNull() ?: currentCmdNum
                    return l.substring(spaceIdx + 1)
                }
                return ""
            }
            sb.appendLine(l)
        }
        return sb.toString()
    }

    private fun parseLine(line: String) {
        if (line.startsWith("info")) {
            val bestMoves = if (isKataGo) {
                parseInfoKatago(line.substring(5))
            } else {
                parseInfo(line.substring(5))
            }
            _analysis.value = AnalysisResult(
                bestMoves = bestMoves,
                scoreMean = bestMoves.firstOrNull()?.scoreMean ?: 0.0,
                scoreStdev = bestMoves.firstOrNull()?.scoreStdev ?: 0.0,
                currentPlayouts = MoveData.getPlayouts(bestMoves),
            )
        }
    }

    private fun parseInfo(line: String): List<MoveData> {
        return line.split(" info ").mapNotNull { part ->
            val trimmed = part.trim()
            if (trimmed.isNotEmpty()) MoveData.fromInfo(trimmed) else null
        }
    }

    private fun parseInfoKatago(line: String): List<MoveData> {
        return line.split(" info ").mapNotNull { part ->
            val trimmed = part.trim()
            if (trimmed.isNotEmpty()) MoveData.fromInfoKatago(trimmed) else null
        }
    }

    
}