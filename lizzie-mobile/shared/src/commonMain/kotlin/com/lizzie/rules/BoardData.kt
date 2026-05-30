package com.lizzie.rules

import com.lizzie.analysis.MoveData

/**
 * Holds the full state of a single board position, including stones,
 * analysis data, and move metadata.
 */
data class BoardData(
    val stones: StoneArray,
    val lastMove: Pair<Int, Int>?,
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
    val komi: Double = 6.5,
    val bestMoves: List<MoveData> = emptyList(),
    val comment: String = "",
    val properties: Map<String, String> = emptyMap(),
    val dummy: Boolean = false,
) {
    fun withBestMoves(moves: List<MoveData>): BoardData {
        val p = MoveData.getPlayouts(moves)
        if (p > playouts) {
            return copy(
                bestMoves = moves,
                playouts = p,
                winrate = MoveData.getWinrateFromBestMoves(moves),
                scoreMean = MoveData.getScoreMeanFromBestMoves(moves)
            )
        }
        return this
    }

    fun withClearedBestMoves(engineIndex: Int, komi: Double): BoardData {
        return copy(
            bestMoves = emptyList(),
            playouts = 0,
            engineIndex = engineIndex,
            komi = komi,
        )
    }

    fun getDisplayWinrate(alwaysBlackWinrate: Boolean): Double {
        return if (!blackToPlay || !alwaysBlackWinrate) {
            winrate
        } else {
            100.0 - winrate
        }
    }

    fun getDisplayScoreMean(): Double {
        return if (blackToPlay) scoreMean else -scoreMean
    }

    fun isSameCoord(coord: Pair<Int, Int>?): Boolean {
        if (coord == null || lastMove == null) return false
        return lastMove == coord
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is BoardData) return false
        return zobrist == other.zobrist &&
                comment == other.comment &&
                blackToPlay == other.blackToPlay
    }

    override fun hashCode(): Int = zobrist.hashCode()

    companion object {
        fun empty(width: Int = 19, height: Int = 19): BoardData {
            val size = width * height
            return BoardData(
                stones = StoneArray.empty(size),
                lastMove = null,
                lastMoveColor = Stone.EMPTY,
                blackToPlay = true,
                zobrist = Zobrist(),
                moveNumber = 0,
                moveNumberList = IntArray(size),
                blackCaptures = 0,
                whiteCaptures = 0,
                winrate = 50.0,
                playouts = 0,
                scoreMean = 0.0,
            )
        }
    }
}