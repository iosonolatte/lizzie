package com.lizzie.rules

/** Type-safe array wrapper for stones. */
@JvmInline
value class StoneArray(val values: IntArray) {
    operator fun get(index: Int): Stone = Stone.fromValue(values[index])
    operator fun set(index: Int, stone: Stone) {
        values[index] = stone.value
    }

    fun clone(): StoneArray = StoneArray(values.copyOf())
    val size: Int get() = values.size

    companion object {
        fun empty(size: Int): StoneArray = StoneArray(IntArray(size) { Stone.EMPTY.value })
    }
}