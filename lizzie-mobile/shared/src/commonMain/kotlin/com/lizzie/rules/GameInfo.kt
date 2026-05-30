package com.lizzie.rules

/**
 * Metadata about a Go game (players, komi, result, etc.)
 */
data class GameInfo(
    val playerBlack: String = "",
    val playerWhite: String = "",
    val komi: Double = 6.5,
    val handicap: Int = 0,
    val ruleSet: String = "jp",
    val gameName: String = "",
    val gameDate: String = "",
    val result: String = "",
) {
    fun isComplete(): Boolean = result.isNotEmpty()

    companion object {
        /** Parse a GTP komi response string to double. */
        fun parseKomi(value: String): Double = value.toDoubleOrNull() ?: 6.5
    }
}