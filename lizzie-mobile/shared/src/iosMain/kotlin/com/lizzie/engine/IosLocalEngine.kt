package com.lizzie.engine

import com.lizzie.analysis.MoveData
import com.lizzie.rules.Stone
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

/**
 * iOS local engine using a statically-linked KataGo via C interop.
 *
 * KataGo is compiled as a static library (libkatago.a) and linked into the
 * iOS app. GTP communication happens through a C bridge that provides
 * stdin/stdout-like pipe functions.
 */
class IosLocalEngine : Engine {

    private val _status = MutableStateFlow<EngineStatus>(EngineStatus.Disconnected)
    override val status: Flow<EngineStatus> = _status.asStateFlow()

    private val _analysis = MutableStateFlow(AnalysisResult(emptyList()))
    override val analysis: Flow<AnalysisResult> = _analysis.asStateFlow()

    private var job: Job? = null
    private var cmdNumber = 1
    private var _isPondering = false
    private var isKataGo = false

    override suspend fun start(config: EngineConfig) {
        // TODO: Initialize KataGo via cinterop
        // This requires:
        // 1. Compile KataGo as a static library for arm64-apple-ios
        // 2. Define C interop functions:
        //    - katago_init(args) -> handle
        //    - katago_send(handle, command) -> response
        //    - katago_read_analysis(handle) -> analysis line
        //    - katago_destroy(handle)
        // 3. Call via kotlinx.cinterop

        _status.value = EngineStatus.Connecting("Initializing KataGo...")

        try {
            // Stub — will be implemented when libkatago.a is compiled
            _status.value = EngineStatus.Ready("KataGo", "1.15.0", isKataGo = true)
        } catch (e: Exception) {
            _status.value = EngineStatus.Error("Failed to initialize: ${e.message}")
        }
    }

    override suspend fun stop() {
        job?.cancel()
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
        sendGtpCommand("kata-analyze 100 0")
    }

    override suspend fun stopPonder() {
        if (!_isPondering) return
        _isPondering = false
        sendGtpCommand("play b pass")
    }

    override fun isPondering(): Boolean = _isPondering

    override suspend fun sendGtpCommand(command: String): String {
        // TODO: route through katago_send cinterop call
        return ""
    }
}