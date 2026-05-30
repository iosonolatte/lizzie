package com.lizzie.rules

enum class Stone(val value: Int) {
    EMPTY(0),
    BLACK(1),
    WHITE(2);

    fun opposite(): Stone = when (this) {
        BLACK -> WHITE
        WHITE -> BLACK
        EMPTY -> EMPTY
    }

    fun isBlack(): Boolean = this == BLACK
    fun isWhite(): Boolean = this == WHITE
    fun isNotEmpty(): Boolean = this != EMPTY
    fun isStone(): Boolean = this == BLACK || this == WHITE

    companion object {
        fun fromValue(value: Int): Stone = when (value) {
            0 -> EMPTY
            1 -> BLACK
            2 -> WHITE
            else -> throw IllegalArgumentException("Invalid stone value: $value")
        }
    }
}