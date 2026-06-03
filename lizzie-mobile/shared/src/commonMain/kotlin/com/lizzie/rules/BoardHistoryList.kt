package com.lizzie.rules

import com.lizzie.rules.GameInfo

/**
 * Linked-list data structure storing board history with branch support.
 *
 * Ported from Lizzie's BoardHistoryList.java and Board.java instance methods.
 */
class BoardHistoryList(data: BoardData?) {
    private var head: BoardHistoryNode? = if (data != null) BoardHistoryNode(data) else null

    var gameInfo: GameInfo = GameInfo()
        private set

    fun setGameInfo(info: GameInfo) {
        gameInfo = info
    }

    fun getCurrentNode(): BoardHistoryNode? = head

    fun getData(): BoardData = head?.data ?: BoardData.empty()

    // ---- Navigation ----

    fun previous(): BoardData? {
        val prev = head?.previous() ?: return null
        head = prev
        return head?.data
    }

    fun toStart() {
        while (previous() != null) { /* loop until no more previous */ }
    }

    fun toBranchTop() {
        var start = head
        while (start?.previous() != null) {
            val pre = start.previous()
            if (pre?.getVariations()?.firstOrNull() != start) {
                previous()
                break
            }
            previous()
            start = pre
        }
    }

    fun next(includeDummy: Boolean = false): BoardData? {
        val n = head?.next(includeDummy) ?: return null
        head = n
        return head?.data
    }

    fun getNext(includeDummy: Boolean = false): BoardData? {
        return head?.next(includeDummy)?.data
    }

    fun getPrevious(): BoardData? {
        return head?.previous()?.data
    }

    fun nextVariation(idx: Int): BoardData? {
        val n = head?.getVariation(idx) ?: return null
        head = n
        return head?.data
    }

    fun getNexts(): List<BoardHistoryNode> = head?.getVariations() ?: emptyList()

    // ---- Mutations ----

    fun add(data: BoardData) {
        val newNode = BoardHistoryNode(data)
        head = head?.add(newNode) ?: newNode
    }

    fun addOrGoto(data: BoardData, newBranch: Boolean = false, changeMove: Boolean = false) {
        head = head?.addOrGoto(data, newBranch, changeMove) ?: BoardHistoryNode(data)
    }

    fun clear() {
        head?.clear()
    }

    // ---- Board state queries ----

    fun getStones(): StoneArray = head?.data?.stones ?: StoneArray.empty(Board.DEFAULT_SIZE * Board.DEFAULT_SIZE)

    fun getLastMove(): Pair<Int, Int>? = head?.data?.lastMove

    fun getNextMove(): Pair<Int, Int>? = getNext()?.lastMove

    fun getLastMoveColor(): Stone = head?.data?.lastMoveColor ?: Stone.EMPTY

    fun isBlacksTurn(): Boolean = head?.data?.blackToPlay ?: true

    fun getZobrist(): Zobrist = head?.data?.zobrist ?: Zobrist()

    fun getMoveNumber(): Int = head?.data?.moveNumber ?: 0

    fun getMoveMNNumber(): Int = head?.data?.moveMNNumber ?: -1

    fun getMoveNumberList(): IntArray = head?.data?.moveNumberList ?: IntArray(0)

    fun currentBranchLength(): Int = getMoveNumber() + (head?.getDepth() ?: 0)

    fun mainTrunkLength(): Int = root()?.getDepth() ?: 0

    fun root(): BoardHistoryNode? {
        var node = head
        while (node?.previous() != null) {
            node = node.previous()
        }
        return node
    }

    fun getEnd(): BoardHistoryNode? {
        var node = head
        while (node?.next() != null) {
            node = node.next()
        }
        return node
    }

    // ---- Move execution ----

    @Synchronized
    fun place(
        x: Int,
        y: Int,
        color: Stone,
        newBranch: Boolean = false,
        changeMove: Boolean = false,
        width: Int = Board.DEFAULT_SIZE,
        height: Int = Board.DEFAULT_SIZE
    ): Boolean {
        if (!Board.isValid(x, y, width, height)) return false
        val currentData = getData()
        if (currentData.stones[Board.getIndex(x, y, width)] != Stone.EMPTY && !newBranch) return false

        // Check if replaying history
        val nextLast = getNext()?.lastMove
        if (nextLast != null && nextLast.first == x && nextLast.second == y && !newBranch && !changeMove) {
            next()
            return true
        }

        val stones = currentData.stones.clone()
        val zobrist = currentData.zobrist.clone()
        val lastMove: Pair<Int, Int>? = Pair(x, y)
        val moveNumber = currentData.moveNumber + 1
        val moveMNNumber = if (currentData.moveMNNumber > -1 && !newBranch) currentData.moveMNNumber + 1 else -1
        val moveNumberList = if (newBranch && getNext(includeDummy = true) != null) {
            IntArray(width * height)
        } else {
            currentData.moveNumberList.copyOf()
        }

        moveNumberList[Board.getIndex(x, y, width)] = if (moveMNNumber > -1) moveMNNumber else moveNumber

        // Place stone
        stones[Board.getIndex(x, y, width)] = color
        var currentZobrist = zobrist.toggleStone(x, y, color)

        // Remove captured enemy stones
        var capturedStones = 0
        capturedStones += Board.removeDeadChain(x + 1, y, color.opposite(), stones, currentZobrist, width, height)
        capturedStones += Board.removeDeadChain(x, y + 1, color.opposite(), stones, currentZobrist, width, height)
        capturedStones += Board.removeDeadChain(x - 1, y, color.opposite(), stones, currentZobrist, width, height)
        capturedStones += Board.removeDeadChain(x, y - 1, color.opposite(), stones, currentZobrist, width, height)

        // Check for suicide
        val isSuicidal = Board.removeDeadChain(x, y, color, stones, currentZobrist, width, height)

        // Clear move numbers for empty positions
        for (i in 0 until width * height) {
            if (stones[i] == Stone.EMPTY) {
                moveNumberList[i] = 0
            }
        }

        val bc = currentData.blackCaptures + if (color.isBlack()) capturedStones else 0
        val wc = currentData.whiteCaptures + if (color.isWhite()) capturedStones else 0

        val newState = BoardData(
            stones = stones,
            lastMove = lastMove,
            lastMoveColor = color,
            blackToPlay = color == Stone.WHITE,
            zobrist = currentZobrist,
            moveNumber = moveNumber,
            moveMNNumber = moveMNNumber,
            moveNumberList = moveNumberList,
            blackCaptures = bc,
            whiteCaptures = wc,
            winrate = currentData.winrate,
            scoreMean = currentData.scoreMean,
            komi = currentData.komi,
        )

        // Check ko and superko
        if (isSuicidal > 0 || violatesKoRule(newState)) return false

        addOrGoto(newState, newBranch, changeMove)
        return true
    }

    @Synchronized
    fun pass(
        color: Stone,
        newBranch: Boolean = false,
        dummy: Boolean = false,
        changeMove: Boolean = false,
        width: Int = Board.DEFAULT_SIZE,
        height: Int = Board.DEFAULT_SIZE
    ) {
        val currentData = getData()

        // Check if replaying pass in history
        val nextData = getNext()
        if (nextData?.lastMove == null && !newBranch) {
            next()
            return
        }

        val stones = currentData.stones.clone()
        val zobrist = currentData.zobrist.clone()
        val moveNumber = currentData.moveNumber + 1
        val moveNumberList = if (newBranch && getNext(includeDummy = true) != null) {
            IntArray(width * height)
        } else {
            currentData.moveNumberList.copyOf()
        }

        val newState = BoardData(
            stones = stones,
            lastMove = null,
            lastMoveColor = color,
            blackToPlay = color == Stone.WHITE,
            zobrist = zobrist,
            moveNumber = moveNumber,
            moveNumberList = moveNumberList,
            blackCaptures = currentData.blackCaptures,
            whiteCaptures = currentData.whiteCaptures,
            winrate = currentData.winrate,
            scoreMean = currentData.scoreMean,
            komi = currentData.komi,
            dummy = dummy,
        )

        addOrGoto(newState, newBranch, changeMove)
    }

    // ---- Ko / Superko ----

    fun violatesSuperko(data: BoardData): Boolean {
        var node: BoardHistoryNode? = head
        while (node?.previous() != null) {
            node = node.previous()
            if (node?.data?.zobrist == data.zobrist && node?.data?.blackToPlay == data.blackToPlay) {
                return true
            }
        }
        return false
    }

    fun violatesKoRule(data: BoardData): Boolean {
        val prev = head?.previous() ?: return false
        return data.zobrist == prev.data.zobrist
    }

    // ---- Stone manipulation ----

    fun setStone(coordinates: Pair<Int, Int>, stone: Stone, width: Int = Board.DEFAULT_SIZE) {
        if (!Board.isValid(coordinates.first, coordinates.second)) return
        val index = Board.getIndex(coordinates.first, coordinates.second, width)
        val data = getData()
        val newStones = data.stones.clone()
        val newZobrist = data.zobrist.toggleStone(coordinates.first, coordinates.second, data.stones[index], stone)
        newStones[index] = stone
        // We can't easily update data in place since it's immutable...
        // For handicap setup, we use add directly
        val newData = data.copy(
            stones = newStones,
            zobrist = newZobrist
        )
        // Can't mutate head directly in immutable design — caller should rebuild
    }

    fun addStone(x: Int, y: Int, color: Stone, width: Int = Board.DEFAULT_SIZE) {
        if (!Board.isValid(x, y) || getStones()[Board.getIndex(x, y, width)] != Stone.EMPTY) return
        val data = getData()
        val newStones = data.stones.clone()
        val newZobrist = data.zobrist.toggleStone(x, y, color)
        newStones[Board.getIndex(x, y, width)] = color
        // Same issue — would need a mutable approach for editing board state
    }

    fun removeStone(x: Int, y: Int, width: Int = Board.DEFAULT_SIZE) {
        if (!Board.isValid(x, y) || getStones()[Board.getIndex(x, y, width)] == Stone.EMPTY) return
        val data = getData()
        val originalColor = data.stones[Board.getIndex(x, y, width)]
        val newStones = data.stones.clone()
        val newZobrist = data.zobrist.toggleStone(x, y, originalColor, Stone.EMPTY)
        newStones[Board.getIndex(x, y, width)] = Stone.EMPTY
        val newMoveNumberList = data.moveNumberList.copyOf()
        newMoveNumberList[Board.getIndex(x, y, width)] = 0
    }

    // ---- Misc ----

    fun shallowCopy(): BoardHistoryList {
        val copy = BoardHistoryList(null)
        copy.head = head
        copy.gameInfo = gameInfo
        return copy
    }

    fun flatten(width: Int = Board.DEFAULT_SIZE, height: Int = Board.DEFAULT_SIZE) {
        val currentData = getData()
        val newData = BoardData(
            stones = currentData.stones.clone(),
            lastMove = null,
            lastMoveColor = Stone.EMPTY,
            blackToPlay = currentData.blackToPlay,
            zobrist = currentData.zobrist.clone(),
            moveNumber = 0,
            moveNumberList = IntArray(width * height),
            blackCaptures = 0,
            whiteCaptures = 0,
            winrate = 0.0,
            scoreMean = 0.0,
            komi = currentData.komi,
        )
        head = BoardHistoryNode(newData)
    }

    fun goToMoveNumber(targetMoveNumber: Int, withinBranch: Boolean = false): Boolean {
        val delta = targetMoveNumber - getMoveNumber()
        var moved = false
        for (i in 0 until kotlin.math.abs(delta)) {
            if (withinBranch && delta < 0) {
                val currentNode = head
                if (currentNode?.isFirstChild() == false) break
            }
            if (delta > 0) {
                if (next() == null) break
            } else {
                if (previous() == null) break
            }
            moved = true
        }
        return moved
    }

    /** Get the full move sequence as a flat list of coordinates (excluding passes). */
    fun getMoveList(): List<Pair<Int, Int>> {
        val moves = mutableListOf<Pair<Int, Int>>()
        val start = root()
        var node = start
        while (node != null) {
            val data = node.data
            if (data.lastMove != null && data.lastMoveColor != Stone.EMPTY) {
                moves.add(data.lastMove)
            }
            node = node.next()
        }
        return moves
    }

    /** Rebuild the entire tree from a flat list of moves (for SGF loading). */
    fun rebuildFromMoveList(
        moves: List<StoneMove>,
        width: Int = Board.DEFAULT_SIZE,
        height: Int = Board.DEFAULT_SIZE
    ) {
        flatten(width, height)
        for (move in moves) {
            if (move.isPass) {
                pass(move.color, width = width, height = height)
            } else {
                place(move.x, move.y, move.color, width = width, height = height)
            }
        }
    }
}

data class StoneMove(
    val x: Int,
    val y: Int,
    val color: Stone,
    val isPass: Boolean = false,
) {
    companion object {
        fun pass(color: Stone) = StoneMove(0, 0, color, isPass = true)
    }
}