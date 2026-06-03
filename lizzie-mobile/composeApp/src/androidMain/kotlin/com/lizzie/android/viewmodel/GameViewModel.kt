package com.lizzie.android.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.lizzie.analysis.MoveData
import com.lizzie.rules.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class BoardState(
    val boardData: BoardData,
    val history: BoardHistoryList,
    val bestMoves: List<MoveData>,
    val showCoordinates: Boolean = false,
    val showWinrate: Boolean = true,
    val boardSize: Int = 19,
)

class GameViewModel : ViewModel() {

    private val _gameState = MutableStateFlow(
        BoardState(
            boardData = BoardData.empty(),
            history = BoardHistoryList(BoardData.empty()),
            bestMoves = emptyList(),
        )
    )
    val gameState: StateFlow<BoardState> = _gameState.asStateFlow()

    private val _engineStatus = MutableStateFlow<com.lizzie.engine.EngineStatus>(
        com.lizzie.engine.EngineStatus.Disconnected
    )
    val engineStatus: StateFlow<com.lizzie.engine.EngineStatus> = _engineStatus.asStateFlow()

    private val history = BoardHistoryList(BoardData.empty())

    fun onIntersectionClick(x: Int, y: Int) {
        val currentData = history.getData()
        val color = if (currentData.blackToPlay) Stone.BLACK else Stone.WHITE

        val placed = history.place(x, y, color)
        if (placed) {
            emitState()
        }
    }

    fun onPass() {
        val color = if (history.isBlacksTurn()) Stone.BLACK else Stone.WHITE
        history.pass(color)
        emitState()
    }

    fun onUndo() {
        history.previous()
        emitState()
    }

    fun onNavigateNext() {
        history.next()
        emitState()
    }

    fun onNavigatePrevious() {
        history.previous()
        emitState()
    }

    fun onBestMoveTap(move: MoveData) {
        if (move.coordinate.isEmpty()) return
        val coord = Board.asCoordinates(move.coordinate)
        if (coord != null) {
            onIntersectionClick(coord.first, coord.second)
        }
    }

    fun toggleCoordinates() {
        _gameState.value = _gameState.value.copy(
            showCoordinates = !_gameState.value.showCoordinates
        )
    }

    fun onEngineStatusChanged(status: com.lizzie.engine.EngineStatus) {
        _engineStatus.value = status
    }

    fun onAnalysisUpdated(bestMoves: List<MoveData>) {
        val current = _gameState.value.boardData
        val updated = current.withBestMoves(bestMoves)
        _gameState.value = _gameState.value.copy(
            boardData = updated,
            bestMoves = bestMoves,
        )
    }

    private fun emitState() {
        _gameState.value = _gameState.value.copy(
            boardData = history.getData(),
            history = history,
            bestMoves = history.getData().bestMoves,
        )
    }
}