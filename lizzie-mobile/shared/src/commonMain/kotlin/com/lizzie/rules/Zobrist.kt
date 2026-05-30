package com.lizzie.rules

/**
 * Zobrist hashing for position superko detection.
 *
 * Each (x, y, stone) combination gets a random hash value.
 * XOR these together to get a position hash.
 */
class Zobrist {
    val hash: Long

    constructor() {
        hash = 0L
    }

    private constructor(hash: Long) {
        this.hash = hash
    }

    fun toggleStone(x: Int, y: Int, stone: Stone): Zobrist {
        if (stone == Stone.EMPTY) return this
        return Zobrist(hash xor getZobrist(x, y, stone))
    }

    fun toggleStone(x: Int, y: Int, oldStone: Stone, newStone: Stone): Zobrist {
        var h = hash
        if (oldStone.isStone()) h = h xor getZobrist(x, y, oldStone)
        if (newStone.isStone()) h = h xor getZobrist(x, y, newStone)
        return Zobrist(h)
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Zobrist) return false
        return hash == other.hash
    }

    override fun hashCode(): Int = hash.hashCode()

    override fun toString(): String = "Zobrist($hash)"

    fun clone(): Zobrist = Zobrist(hash)

    companion object {
        // Fixed-size: support up to 25x25 boards
        private const val MAX_SIZE = 25
        private val zobristTable: Array<LongArray> = Array(MAX_SIZE * MAX_SIZE) { LongArray(3) }

        init {
            val random = kotlin.random.Random(0x9E3779B97F4A7C15)
            for (i in zobristTable.indices) {
                for (j in 0 until 3) {
                    zobristTable[i][j] = random.nextLong()
                }
            }
        }

        fun getZobrist(x: Int, y: Int, stone: Stone): Long {
            val index = y * MAX_SIZE + x
            return zobristTable[index][stone.value]
        }
    }
}