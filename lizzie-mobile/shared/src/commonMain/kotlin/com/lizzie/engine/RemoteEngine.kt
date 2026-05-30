package com.lizzie.engine

import com.lizzie.analysis.MoveData
import com.lizzie.rules.Stone
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

/**
 * Remote engine connecting to a KataGo instance over TCP.
 *
 * Uses platform-specific [GtpSocket] for the actual connection.
 * KataGo should be started with `--gtp` flag for GTP-over-TCP mode.
 */
class RemoteEngine : Engine {

    private val _status = MutableStateFlow<EngineStatus>(EngineStatus.Disconnected)
    override val status: Flow<EngineStatus> = _status.asStateFlow()

    private val _analysis = MutableStateFlow(AnalysisResult(emptyList()))
    override val analysis: Flow<AnalysisResult> = _analysis.asStateFlow()

    private var socket: GtpSocket? = null
    private var readerJob: Job? = null
    private var cmdNumber = 1
    private var currentCmdNum = 0
    private var _isPondering = false
    private var isKataGo = false

    // Response tracking: maps cmdNumber -> CompletableDeferred<String>
    private val pendingResponses = mutableMapOf<Int, CompletableDeferred<String>>()
    private val pendingLock = Any()

    override suspend fun start(config: EngineConfig) {
        val cfg = config as EngineConfig.Remote
        _status.value = EngineStatus.Connecting("Connecting to ${cfg.host}:${cfg.port}")
        cmdNumber = 1
        currentCmdNum = 0

        try {
            val s = GtpSocket()
            s.connect(cfg.host, cfg.port)
            socket = s

            // GTP handshake
            val nameResponse = sendGtpCommand("name")
            isKataGo = nameResponse.startsWith("KataGo")

            val versionResponse = sendGtpCommand("version")
            val version = versionResponse.trim()

            _status.value = EngineStatus.Ready(
                engineName = nameResponse.trim(),
                version = version,
                isKataGo = isKataGo,
            )

            // Start continuous reader coroutine
            readerJob = CoroutineScope(Dispatchers.Default).launch {
                try {
                    while (isActive && socket?.isConnected == true) {
                        val line = socket?.readLine() ?: break
                        parseLine(line.trimEnd('\r'))
                    }
                } catch (e: CancellationException) {
                    // Normal shutdown
                } catch (e: Exception) {
                    _status.value = EngineStatus.Error("Connection lost: ${e.message}")
                }
            }
        } catch (e: Exception) {
            _status.value = EngineStatus.Error("Failed to connect: ${e.message}")
            throw e
        }
    }

    override suspend fun stop() {
        readerJob?.cancel()
        try { sendGtpCommand("quit") } catch (_: Exception) {}
        socket?.close()
        socket = null
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
        // Send a command to interrupt the continuous analysis
        // GTP doesn't have an interrupt, but sending a play command works
        // because kata-analyze is replaced by the next command
        sendGtpCommand("kata-analyze 1 0") // minimal analysis to replace the previous one
    }

    override fun isPondering(): Boolean = _isPondering

    override suspend fun sendGtpCommand(command: String): String {
        val s = socket ?: throw IllegalStateException("Engine not connected")
        val cmdNum = cmdNumber++
        val deferred = CompletableDeferred<String>()

        synchronized(pendingLock) {
            pendingResponses[cmdNum] = deferred
        }

        // Send command with GTP line numbering
        s.send("$cmdNum $command\n".encodeToByteArray())

        // Wait for response with timeout
        return withTimeout(30_000L) {
            deferred.await()
        }
    }

    private fun parseLine(line: String) {
        if (line.startsWith("info")) {
            val rest = line.substring(4).trimStart()
            val bestMoves = if (isKataGo) {
                parseInfoKatago(rest)
            } else {
                parseInfo(rest)
            }

            // Update analysis
            _analysis.value = AnalysisResult(
                bestMoves = bestMoves,
                scoreMean = bestMoves.firstOrNull()?.scoreMean ?: 0.0,
                scoreStdev = bestMoves.firstOrNull()?.scoreStdev ?: 0.0,
                currentPlayouts = MoveData.getPlayouts(bestMoves),
            )

            // Parse ownership if present
            val ownership = parseOwnership(line)
            if (ownership != null) {
                _analysis.value = _analysis.value.copy(ownership = ownership)
            }
        } else if (line.startsWith("=")) {
            // GTP success response: "=NNNN response_text"
            val rest = line.substring(1).trimStart()
            val spaceIdx = rest.indexOf(' ')
            val responseText: String
            val responseCmdNum: Int

            if (spaceIdx > 0) {
                val numStr = rest.substring(0, spaceIdx)
                responseCmdNum = numStr.toIntOrNull() ?: return
                responseText = rest.substring(spaceIdx + 1)
            } else {
                // Response without number
                responseCmdNum = rest.toIntOrNull() ?: return
                responseText = ""
            }

            currentCmdNum = responseCmdNum
            completePending(responseCmdNum, responseText)
        } else if (line.startsWith("?")) {
            // GTP error response
            val rest = line.substring(1).trimStart()
            val spaceIdx = rest.indexOf(' ')
            if (spaceIdx > 0) {
                val numStr = rest.substring(0, spaceIdx)
                val responseCmdNum = numStr.toIntOrNull()
                if (responseCmdNum != null) {
                    completePending(responseCmdNum, "? ${rest.substring(spaceIdx + 1)}")
                }
            }
        }
        // Other lines (stderr, tuning output, etc.) are ignored
    }

    private fun completePending(cmdNum: Int, response: String) {
        synchronized(pendingLock) {
            val deferred = pendingResponses.remove(cmdNum)
            if (deferred != null && !deferred.isCompleted) {
                deferred.complete(response)
            }
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

    private fun parseOwnership(line: String): List<Double>? {
        if (!line.contains("ownership")) return null
        val params = line.trim().split("ownership")
        if (params.size < 2) return null
        return params[1].trim().split(" ").mapNotNull { it.toDoubleOrNull() }
    }
}