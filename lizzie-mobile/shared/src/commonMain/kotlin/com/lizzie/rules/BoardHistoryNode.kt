package com.lizzie.rules

/**
 * A single node in the board history linked list.
 * Supports branching (multiple children for variations).
 */
class BoardHistoryNode(
    val data: BoardData
) {
    private var _previous: BoardHistoryNode? = null
    private val _next = mutableListOf<BoardHistoryNode>()
    private var _parent: BoardHistoryNode? = null

    fun previous(): BoardHistoryNode? = _previous

    fun setPrevious(node: BoardHistoryNode?) {
        _previous = node
    }

    fun next(): BoardHistoryNode? = _next.firstOrNull { !it.data.dummy }

    fun next(includeDummy: Boolean): BoardHistoryNode? {
        return if (includeDummy) _next.firstOrNull() else _next.firstOrNull { !it.data.dummy }
    }

    fun getVariations(): List<BoardHistoryNode> = _next.filter { !it.data.dummy }

    fun getVariation(idx: Int): BoardHistoryNode? {
        val variations = getVariations()
        return if (idx in variations.indices) variations[idx] else null
    }

    fun numberOfChildren(): Int = _next.size

    fun isFirstChild(): Boolean {
        if (_previous == null) return true
        val siblings = _previous!!._next.filter { !it.data.dummy }
        return siblings.firstOrNull() == this
    }

    fun add(child: BoardHistoryNode): BoardHistoryNode {
        child._parent = this
        child._previous = this
        // New nodes always go at the end
        _next.add(child)
        return child
    }

    fun addOrGoto(data: BoardData, newBranch: Boolean = false): BoardHistoryNode {
        return addOrGoto(data, newBranch, false)
    }

    fun addOrGoto(data: BoardData, newBranch: Boolean, changeMove: Boolean): BoardHistoryNode {
        if (!newBranch && !changeMove) {
            val nextNode = next()
            if (nextNode != null) return nextNode
        }

        if (changeMove) {
            // Replace the first variation
            val variations = _next.filter { !it.data.dummy }
            if (variations.isNotEmpty()) {
                val newNode = BoardHistoryNode(data)
                newNode._previous = this
                newNode._parent = this
                val idx = _next.indexOf(variations[0])
                _next[idx] = newNode
                return newNode
            }
        }

        val newNode = BoardHistoryNode(data)
        newNode._previous = this
        newNode._parent = this
        _next.add(newNode)
        return newNode
    }

    fun replaceWith(newNode: BoardHistoryNode) {
        // Replace this node's data (used for flatten/update)
        // In a linked list we'd need to update pointers, but for simplicity
        // we can't easily replace self. The caller should manage this.
    }

    fun getDepth(): Int {
        var depth = 0
        var current: BoardHistoryNode? = this
        while (current?.next() != null) {
            depth++
            current = current.next()
        }
        return depth
    }

    fun clear() {
        _next.clear()
    }

    override fun toString(): String {
        return "BoardHistoryNode(move=$moveNumber, children=${_next.size})"
    }

    val moveNumber: Int get() = data.moveNumber
}