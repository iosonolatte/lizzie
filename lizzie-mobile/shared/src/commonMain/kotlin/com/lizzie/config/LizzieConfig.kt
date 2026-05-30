package com.lizzie.config

import kotlinx.serialization.Serializable

@Serializable
enum class EngineMode {
    Local,
    Remote,
    None
}

/**
 * Mobile Lizzie configuration.
 * Stripped of Swing/desktop-specific settings.
 */
@Serializable
data class LizzieConfig(
    // Board display
    val showMoveNumber: Boolean = false,
    val showCoordinates: Boolean = false,
    val showWinrate: Boolean = true,
    val showScoreMean: Boolean = true,
    val showPlayouts: Boolean = true,
    val boardSize: Int = 19,
    val boardWidth: Int = 19,
    val boardHeight: Int = 19,

    // Analysis display
    val showBestMoves: Boolean = true,
    val showVariationGraph: Boolean = true,
    val limitBestMoveNum: Int = 5,
    val limitBranchLength: Int = 10,
    val minPlayoutRatioForStats: Double = 0.1,

    // Engine
    val engineMode: EngineMode = EngineMode.Local,
    val engineCommand: String = "",
    val weightsPath: String = "",
    val engineConfigPath: String = "",
    val remoteHost: String = "192.168.1.100",
    val remotePort: Int = 9000,
    val useTls: Boolean = false,
    val maxAnalyzeTimeMinutes: Int = 99999,
    val maxGameThinkingTimeSeconds: Int = 2,

    // KataGo specific
    val showKataGoEstimate: Boolean = false,
    val kataGoEstimateMode: String = "small+dead",
    val kataGoEstimateBlend: Boolean = true,

    // UI
    val theme: String = "system", // system, light, dark
    val hapticFeedback: Boolean = true,
    val autoSaveSgf: Boolean = true,
) {
    companion object {
        val Default = LizzieConfig()
    }
}