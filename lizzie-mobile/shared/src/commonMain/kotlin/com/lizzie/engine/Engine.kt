package com.lizzie.engine

import com.lizzie.analysis.MoveData
import com.lizzie.config.EngineMode
import com.lizzie.config.LizzieConfig
import com.lizzie.rules.Stone
import kotlinx.coroutines.flow.Flow

/**
 * Full analysis result from the engine.
 */
data class AnalysisResult(
    val bestMoves: List<MoveData>,
    val ownership: List<Double>? = null,
    val scoreMean: Double = 0.0,
    val scoreStdev: Double = 0.0,
    val currentPlayouts: Int = 0,
)

/**
 * Engine connection status.
 */
sealed interface EngineStatus {
    data object Disconnected : EngineStatus
    data class Connecting(val info: String) : EngineStatus
    data class Ready(
        val engineName: String,
        val version: String,
        val isKataGo: Boolean,
    ) : EngineStatus
    data class Error(val message: String) : EngineStatus
}

/**
 * Engine configuration resolved from [LizzieConfig].
 */
sealed interface EngineConfig {
    data class Local(
        val engineCommand: String,
        val weightsPath: String,
        val configPath: String? = null,
        val maxPlayouts: Int = 0, // 0 = unlimited
    ) : EngineConfig

    data class Remote(
        val host: String,
        val port: Int,
        val useTls: Boolean = false,
    ) : EngineConfig

    data object None : EngineConfig
}

fun LizzieConfig.toEngineConfig(): EngineConfig = when (engineMode) {
    EngineMode.Local -> EngineConfig.Local(
        engineCommand = engineCommand,
        weightsPath = weightsPath,
        configPath = engineConfigPath.ifBlank { null },
    )
    EngineMode.Remote -> EngineConfig.Remote(
        host = remoteHost,
        port = remotePort,
        useTls = useTls,
    )
    EngineMode.None -> EngineConfig.None
}

/**
 * Core engine interface for Go analysis.
 *
 * Implementations: [RemoteEngine] (commonMain), AndroidLocalEngine, IosLocalEngine.
 */
interface Engine {
    /** Engine connection status flow. */
    val status: Flow<EngineStatus>

    /** Analysis results flow — emits every time the engine updates. */
    val analysis: Flow<AnalysisResult>

    /** Start the engine with given configuration. */
    suspend fun start(config: EngineConfig)

    /** Gracefully stop the engine. */
    suspend fun stop()

    /** Initialize a new game (board size, komi, handicap). */
    suspend fun initGame(boardSize: Int, komi: Double = 6.5, handicap: Int = 0)

    /** Play a move on the engine's internal board. */
    suspend fun playMove(color: Stone, coordinate: String?)

    /** Undo the last move on the engine's internal board. */
    suspend fun undoMove()

    /** Start pondering (continuous analysis) on current position. */
    suspend fun startPonder()

    /** Stop pondering. */
    suspend fun stopPonder()

    /** Check if engine is currently pondering. */
    fun isPondering(): Boolean

    /** Send a raw GTP command and get the response. */
    suspend fun sendGtpCommand(command: String): String
}