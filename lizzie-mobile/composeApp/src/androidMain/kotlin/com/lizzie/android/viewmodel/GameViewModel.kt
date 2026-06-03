package com.lizzie.android.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.lizzie.analysis.MoveData
import com.lizzie.engine.AndroidLocalEngine
import com.lizzie.engine.EngineConfig
import com.lizzie.engine.EngineStatus
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

class GameViewModel(application: Application) : AndroidViewModel(application) {

    private val _gameState = MutableStateFlow(
        BoardState(
            boardData = BoardData.empty(),
            history = BoardHistoryList(BoardData.empty()),
            bestMoves = emptyList(),
        )
    )
    val gameState: StateFlow<BoardState> = _gameState.asStateFlow()

    private val _engineStatus = MutableStateFlow<EngineStatus>(EngineStatus.Disconnected)
    val engineStatus: StateFlow<EngineStatus> = _engineStatus.asStateFlow()

    private val history = BoardHistoryList(BoardData.empty())
    private val engine = AndroidLocalEngine(application)

    init {
        startEngine()
        observeAnalysis()
    }

    private fun startEngine() {
        viewModelScope.launch {
            engine.status.collect { status ->
                _engineStatus.value = status
            }
        }
        viewModelScope.launch {
            engine.start(
                EngineConfig.Local(
                    engineCommand = "",
                    weightsPath = "",
                )
            )
            engine.initGame(19, 6.5)
            engine.startPonder()
        }
    }

    private fun observeAnalysis() {
        viewModelScope.launch {
            engine.analysis.collect { result ->
                val current = history.getData()
                val updated = current.withBestMoves(result.bestMoves)
                _gameState.value = _gameState.value.copy(
                    boardData = updated,
                    bestMoves = result.bestMoves,
                )
            }
        }
    }

    fun onIntersectionClick(x: Int, y: Int) {
        val currentData = history.getData()
        val color = if (currentData.blackToPlay) Stone.BLACK else Stone.WHITE
        val placed = history.place(x, y, color)
        if (placed) {
            viewModelScope.launch {
                engine.playMove(color, Board.convertCoordinatesToName(x, y))
            }
            emitState()
        }
    }

    fun onPass() {
        val color = if (history.isBlacksTurn()) Stone.BLACK else Stone.WHITE
        history.pass(color)
        viewModelScope.launch { engine.playMove(color, null) }
        emitState()
    }

    fun onUndo() {
        history.previous()
        viewModelScope.launch { engine.undoMove() }
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

    private fun emitState() {
        _gameState.value = _gameState.value.copy(
            boardData = history.getData(),
            history = history,
            bestMoves = history.getData().bestMoves,
        )
    }

    override fun onCleared() {
        super.onCleared()
        viewModelScope.launch { engine.stop() }
    }
}