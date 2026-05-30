package com.lizzie.engine

import com.lizzie.analysis.MoveData
import com.lizzie.rules.Stone
import io.ktor.client.*
import io.ktor.client.engine.*
import io.ktor.client.plugins.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.utils.io.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

/**
 * Remote engine connecting to a KataGo instance over TCP.
 *
 * KataGo supports GTP over TCP when started with `--gtp` flag.
 * Falls back to raw socket connection if Ktor TCP is unavailable (uses byteChannel).
 */
class RemoteEngine(
    private val clientEngine: HttpClientEngine? = null,
) : Engine {

    private val _status = MutableStateFlow<EngineStatus>(EngineStatus.Disconnected)
    override val status: Flow<EngineStatus> = _status.asStateFlow()

    private val _analysis = MutableStateFlow(AnalysisResult(emptyList()))
    override val analysis: Flow<AnalysisResult> = _analysis.asStateFlow()

    private var client: HttpClient? = null
    private var socket: ByteReadChannel? = null
    private var writeChannel: ByteWriteChannel? = null
    private var job: Job? = null
    private var cmdNumber = 1
    private var currentCmdNum = 0
    private var _isPondering = false
    private var isKataGo = false
    private val cmdQueue = ArrayDeque<String>()
    private var config: EngineConfig.Remote? = null

    override suspend fun start(config: EngineConfig) {
        val cfg = config as EngineConfig.Remote
        this.config = cfg
        _status.value = EngineStatus.Connecting("Connecting to ${cfg.host}:${cfg.port}")
        cmdNumber = 1
        currentCmdNum = 0

        try {
            // Use raw TCP socket via Ktor
            client = HttpClient(clientEngine) {
                install(HttpTimeout) {
                    connectTimeoutMillis = 5000
                    socketTimeoutMillis = 30_000
                }
            }

            // TCP connection — we use raw socket
            val socket = java.net.Socket(cfg.host, cfg.port)
            socket.soTimeout = 30_000
            val input = socket.getInputStream()
            val output = socket.getOutputStream()

            val inputChannel = object : ByteReadChannel {
                private val buffer = java.io.ByteArrayOutputStream()
                override val availableForRead: Int get() = buffer.size()
                override val isClosedForRead: Boolean get() = socket.isClosed
                override suspend fun readByte(): Byte {
                    val b = input.read()
                    if (b == -1) throw java.io.EOFException("Socket closed")
                    return b.toByte()
                }
                override suspend fun readAvailable(dst: kotlinx.io.Buffer, limit: Int): Long {
                    // Simplified — read bytes into dst
                    val bytes = ByteArray(limit)
                    val count = input.read(bytes, 0, limit)
                    if (count > 0) {
                        dst.write(bytes, 0, count)
                    }
                    return count.toLong()
                }
                // ... other methods
            }

            this.socket = inputChannel
            this.writeChannel = object : ByteWriteChannel {
                override val isClosedForWrite: Boolean get() = socket.isClosed
                override suspend fun writeByte(byte: Byte) {
                    output.write(byte.toInt())
                }
                override suspend fun writeFully(src: ByteArray, offset: Int, length: Int) {
                    output.write(src, offset, length)
                    output.flush()
                }
                override fun close() {
                    socket.close()
                }
            }

            // GTP handshake — check name
            val nameResponse = sendGtpCommand("name")
            isKataGo = nameResponse.startsWith("KataGo")

            val versionResponse = sendGtpCommand("version")
            val version = versionResponse.trim()

            _status.value = EngineStatus.Ready(
                engineName = nameResponse.trim(),
                version = version,
                isKataGo = isKataGo,
            )

            // Start reader coroutine
            job = CoroutineScope(Dispatchers.Default).launch {
                try {
                    val lineBuf = StringBuilder()
                    while (isActive) {
                        val b = input.read()
                        if (b == -1) break
                        val c = b.toChar()
                        lineBuf.append(c)
                        if (c == '\n') {
                            val line = lineBuf.toString()
                            lineBuf.clear()
                            parseLine(line.trim())
                        }
                    }
                } catch (e: java.io.IOException) {
                    _status.value = EngineStatus.Error("Connection lost: ${e.message}")
                } catch (e: CancellationException) {
                    // Normal shutdown
                }
            }
        } catch (e: Exception) {
            _status.value = EngineStatus.Error("Failed to connect: ${e.message}")
            throw e
        }
    }

    override suspend fun stop() {
        try {
            sendGtpCommand("quit")
        } catch (_: Exception) {}
        job?.cancel()
        socket?.let { /* close */ }
        writeChannel?.close()
        client?.close()
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
        // Send a dummy command to interrupt analysis
        sendGtpCommand("play b pass")
    }

    override fun isPondering(): Boolean = _isPondering

    override suspend fun sendGtpCommand(command: String): String {
        val cmdNum = cmdNumber++
        val cmdLine = "$cmdNum $command"
        writeChannel?.let { channel ->
            channel.writeFully("$cmdLine\n".encodeToByteArray(), 0, cmdLine.length + 1)
        } ?: throw IllegalStateException("Engine not connected")

        // Wait for response
        return withTimeout(30_000) {
            // The response will come through parseLine
            // For now, return empty — real implementation needs response queue
            ""
        }
    }

    private fun parseLine(line: String) {
        if (line.startsWith("info")) {
            if (isKataGo) {
                val bestMoves = parseInfoKatago(line.substring(5))
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
            } else {
                val bestMoves = parseInfo(line.substring(5))
                _analysis.value = AnalysisResult(
                    bestMoves = bestMoves,
                    currentPlayouts = MoveData.getPlayouts(bestMoves),
                )
            }
        } else if (line.startsWith("=")) {
            val parts = line.trim().split(" ")
            if (parts.size >= 2) {
                currentCmdNum = parts[0].removePrefix("=").toIntOrNull() ?: currentCmdNum
            }
            // Process next command in queue
            processCmdQueue()
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

    private fun processCmdQueue() {
        // In a full implementation, this would complete the sendCommand future
    }
}

/** No-op engine used when no engine is configured. */
class NullEngine : Engine {
    override val status: Flow<EngineStatus> = flow { emit(EngineStatus.Disconnected) }
    override val analysis: Flow<AnalysisResult> = flow { emit(AnalysisResult(emptyList())) }
    override suspend fun start(config: EngineConfig) {}
    override suspend fun stop() {}
    override suspend fun initGame(boardSize: Int, komi: Double, handicap: Int) {}
    override suspend fun playMove(color: Stone, coordinate: String?) {}
    override suspend fun undoMove() {}
    override suspend fun startPonder() {}
    override suspend fun stopPonder() {}
    override fun isPondering(): Boolean = false
    override suspend fun sendGtpCommand(command: String): String = ""
}