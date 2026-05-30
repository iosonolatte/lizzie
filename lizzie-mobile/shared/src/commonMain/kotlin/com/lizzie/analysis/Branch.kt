package com.lizzie.analysis

/**
 * Branch data for variation tree display.
 */
data class Branch(
    val moves: List<String> = emptyList(),
    val winrate: Double = 0.0,
    val scoreMean: Double = 0.0,
    val playouts: Int = 0,
) {
    companion object {
        fun fromMoveData(
            bestMoves: List<MoveData>,
            limit: Int = 5
        ): List<Branch> {
            return bestMoves.take(limit).map { move ->
                Branch(
                    moves = move.variation,
                    winrate = move.winrate,
                    scoreMean = move.scoreMean,
                    playouts = move.playouts
                )
            }
        }
    }
}