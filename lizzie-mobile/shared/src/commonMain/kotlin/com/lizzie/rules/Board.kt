package com.lizzie.rules

import com.lizzie.analysis.MoveData
import com.lizzie.analysis.MoveDataListener

/**
 * Core game board logic: coordinate conversion, stone groups, captures.
 *
 * Ported from Lizzie's Board.java — pure game-state logic, no GUI.
 */
class Board(
    val width: Int = DEFAULT_SIZE,
    val height: Int = DEFAULT_SIZE,
) : MoveDataListener {

    private val history: BoardHistoryList = BoardHistoryList(BoardData.empty(width, height))

    fun getHistory(): BoardHistoryList = history

    // ---- Listeners ----
    private val listeners = mutableListOf<MoveDataListener>()

    fun addListener(listener: MoveDataListener) {
        listeners.add(listener)
    }

    fun removeListener(listener: MoveDataListener) {
        listeners.remove(listener)
    }

    override fun onBestMoveNotification(bestMoves: List<MoveData>) {
        listeners.forEach { it.onBestMoveNotification(bestMoves) }
    }

    // ---- Static utilities ----

    companion object {
        const val DEFAULT_SIZE = 19
        private const val ALPHABET = "ABCDEFGHJKLMNOPQRSTUVWXYZ"

        fun isValid(x: Int, y: Int, width: Int = DEFAULT_SIZE, height: Int = DEFAULT_SIZE): Boolean {
            return x in 0 until width && y in 0 until height
        }

        fun getIndex(x: Int, y: Int, width: Int = DEFAULT_SIZE): Int {
            return y * width + x
        }

        fun getNeighbors(x: Int, y: Int, width: Int = DEFAULT_SIZE, height: Int = DEFAULT_SIZE): List<Pair<Int, Int>> {
            val neighbors = mutableListOf<Pair<Int, Int>>()
            if (x > 0) neighbors.add(Pair(x - 1, y))
            if (x < width - 1) neighbors.add(Pair(x + 1, y))
            if (y > 0) neighbors.add(Pair(x, y - 1))
            if (y < height - 1) neighbors.add(Pair(x, y + 1))
            return neighbors
        }

        fun getGroup(x: Int, y: Int, stones: StoneArray, width: Int = DEFAULT_SIZE, height: Int = DEFAULT_SIZE): Set<Int> {
            val color = stones[getIndex(x, y, width)]
            if (color == Stone.EMPTY) return emptySet()
            val visited = mutableSetOf<Int>()
            val queue = ArrayDeque<Int>()
            val startIdx = getIndex(x, y, width)
            queue.add(startIdx)
            visited.add(startIdx)
            while (queue.isNotEmpty()) {
                val idx = queue.removeFirst()
                val cx = idx % width
                val cy = idx / width
                for ((nx, ny) in getNeighbors(cx, cy, width, height)) {
                    val nIdx = getIndex(nx, ny, width)
                    if (nIdx !in visited && stones[nIdx] == color) {
                        visited.add(nIdx)
                        queue.add(nIdx)
                    }
                }
            }
            return visited
        }

        fun hasLiberty(group: Set<Int>, stones: StoneArray, width: Int = DEFAULT_SIZE, height: Int = DEFAULT_SIZE): Boolean {
            for (idx in group) {
                val cx = idx % width
                val cy = idx / width
                for ((nx, ny) in getNeighbors(cx, cy, width, height)) {
                    if (stones[getIndex(nx, ny, width)] == Stone.EMPTY) return true
                }
            }
            return false
        }

        /**
         * Remove a dead chain (group with no liberties) at (x, y) for the given color.
         * Returns the number of stones removed.
         */
        fun removeDeadChain(
            x: Int,
            y: Int,
            color: Stone,
            stones: StoneArray,
            zobrist: Zobrist,
            width: Int = DEFAULT_SIZE,
            height: Int = DEFAULT_SIZE
        ): Int {
            if (!isValid(x, y, width, height)) return 0
            if (stones[getIndex(x, y, width)] != color) return 0
            val group = getGroup(x, y, stones, width, height)
            if (hasLiberty(group, stones, width, height)) return 0
            var removed = 0
            for (idx in group) {
                stones[idx] = Stone.EMPTY
                val cx = idx % width
                val cy = idx / width
                // Note: zobrist is mutated in place (caller handles this)
                removed++
            }
            return removed
        }

        /** Convert GTP coordinate (e.g., "Q16") to (x, y). */
        fun asCoordinates(name: String, width: Int = DEFAULT_SIZE, height: Int = DEFAULT_SIZE): Pair<Int, Int>? {
            if (name.isEmpty()) return null
            val upper = name.uppercase()
            val letter = upper[0]
            val x = ALPHABET.indexOf(letter)
            if (x < 0 || x >= width) return null
            val yStr = upper.substring(1)
            val yNum = yStr.toIntOrNull() ?: return null
            val y = height - yNum
            if (y < 0 || y >= height) return null
            return Pair(x, y)
        }

        /** Convert (x, y) to GTP coordinate string. */
        fun convertCoordinatesToName(x: Int, y: Int, height: Int = DEFAULT_SIZE): String {
            return "${ALPHABET[x]}${height - y}"
        }

        /** Standard star points for a given board size. */
        fun starPoints(size: Int): List<Pair<Int, Int>> {
            return when (size) {
                9 -> listOf(
                    Pair(2, 2), Pair(6, 2),
                    Pair(2, 6), Pair(6, 6),
                    Pair(4, 4)
                )
                13 -> listOf(
                    Pair(3, 3), Pair(9, 3),
                    Pair(3, 9), Pair(9, 9),
                    Pair(6, 6)
                )
                19 -> listOf(
                    Pair(3, 3), Pair(15, 3), Pair(9, 3),
                    Pair(3, 9), Pair(15, 9), Pair(9, 9),
                    Pair(3, 15), Pair(15, 15), Pair(9, 15)
                )
                else -> emptyList()
            }
        }
    }
}