package com.lizzie.analysis

import kotlinx.serialization.Serializable

/**
 * Holds analysis data for a single move, parsed from KataGo / Leela Zero GTP output.
 */
@Serializable
data class MoveData(
    val coordinate: String,
    val playouts: Int = 0,
    val winrate: Double = 0.0,
    val scoreMean: Double = 0.0,
    val scoreStdev: Double = 0.0,
    val policy: Double = 0.0,
    val lcb: Double = 0.0,
    val utility: Double = 0.0,
    val order: Int = 0,
    val variation: List<String> = emptyList(),
) {
    companion object {
        /**
         * Parses a single info line from KataGo output.
         * Format: info move Q5 visits 9 utility -0.145503 winrate 0.430823 scoreMean -1.88438 scoreStdev 23.8437 prior 0.000681463 lcb 0.420129 order 15 pv Q5 D16 D4
         */
        fun fromInfoKatago(line: String): MoveData {
            val data = line.trim().split(" ")
            var coordinate = ""
            var playouts = 0
            var winrate = 0.0
            var scoreMean = 0.0
            var scoreStdev = 0.0
            var policy = 0.0
            var lcb = 0.0
            var utility = 0.0
            var order = 0
            val variation = mutableListOf<String>()
            var i = 0
            while (i < data.size) {
                when (data[i]) {
                    "move" -> if (i + 1 < data.size) { coordinate = data[i + 1]; i += 2 }
                    "visits" -> if (i + 1 < data.size) { playouts = data[i + 1].toIntOrNull() ?: 0; i += 2 }
                    "winrate" -> if (i + 1 < data.size) { winrate = data[i + 1].toDoubleOrNull() ?: 0.0; i += 2 }
                    "scoreMean" -> if (i + 1 < data.size) { scoreMean = data[i + 1].toDoubleOrNull() ?: 0.0; i += 2 }
                    "scoreStdev" -> if (i + 1 < data.size) { scoreStdev = data[i + 1].toDoubleOrNull() ?: 0.0; i += 2 }
                    "prior" -> if (i + 1 < data.size) { policy = data[i + 1].toDoubleOrNull() ?: 0.0; i += 2 }
                    "lcb" -> if (i + 1 < data.size) { lcb = data[i + 1].toDoubleOrNull() ?: 0.0; i += 2 }
                    "utility" -> if (i + 1 < data.size) { utility = data[i + 1].toDoubleOrNull() ?: 0.0; i += 2 }
                    "order" -> if (i + 1 < data.size) { order = data[i + 1].toIntOrNull() ?: 0; i += 2 }
                    "pv" -> {
                        i += 1
                        while (i < data.size) {
                            variation.add(data[i])
                            i++
                        }
                    }
                    else -> i++
                }
            }
            return MoveData(
                coordinate = coordinate,
                playouts = playouts,
                winrate = winrate,
                scoreMean = scoreMean,
                scoreStdev = scoreStdev,
                policy = policy,
                lcb = lcb,
                utility = utility,
                order = order,
                variation = variation
            )
        }

        /**
         * Parses a Leela Zero info line (non-KataGo format).
         * Format: info move R5 visits 38 winrate 5404 order 0 pv R5 Q5 R6 S4
         */
        fun fromInfo(line: String): MoveData {
            val data = line.trim().split(" ")
            var coordinate = ""
            var playouts = 0
            var winrate = 0.0
            val variation = mutableListOf<String>()
            var i = 0
            while (i < data.size) {
                when (data[i]) {
                    "move" -> if (i + 1 < data.size) { coordinate = data[i + 1]; i += 2 }
                    "visits" -> if (i + 1 < data.size) { playouts = data[i + 1].toIntOrNull() ?: 0; i += 2 }
                    "winrate" -> if (i + 1 < data.size) { winrate = (data[i + 1].toDoubleOrNull() ?: 0.0) / 100.0; i += 2 }
                    "pv" -> {
                        i += 1
                        while (i < data.size) {
                            variation.add(data[i])
                            i++
                        }
                    }
                    else -> i++
                }
            }
            return MoveData(
                coordinate = coordinate,
                playouts = playouts,
                winrate = winrate,
                variation = variation
            )
        }

        /**
         * Parses a summary line: "R5 -> 1234 visits, 45.6% winrate"
         */
        fun fromSummary(line: String): MoveData? {
            return try {
                val parts = line.split(" -> ")
                if (parts.size < 2) return null
                val coordinate = parts[0].trim()
                val rest = parts[1]
                val visitsMatch = Regex("(\\d+) visits?").find(rest)
                val winrateMatch = Regex("([\\d.]+)%").find(rest)
                MoveData(
                    coordinate = coordinate,
                    playouts = visitsMatch?.groupValues?.get(1)?.toIntOrNull() ?: 0,
                    winrate = winrateMatch?.groupValues?.get(1)?.toDoubleOrNull()?.div(100.0) ?: 0.0
                )
            } catch (e: Exception) {
                null
            }
        }

        fun getPlayouts(moves: List<MoveData>): Int = moves.sumOf { it.playouts }

        fun getWinrateFromBestMoves(moves: List<MoveData>): Double {
            val totalPlayouts = getPlayouts(moves)
            if (totalPlayouts == 0) return 0.0
            return moves.sumOf { it.winrate * it.playouts } / totalPlayouts
        }

        fun getScoreMeanFromBestMoves(moves: List<MoveData>): Double {
            val totalPlayouts = getPlayouts(moves)
            if (totalPlayouts == 0) return 0.0
            return moves.sumOf { it.scoreMean * it.playouts } / totalPlayouts
        }
    }
}