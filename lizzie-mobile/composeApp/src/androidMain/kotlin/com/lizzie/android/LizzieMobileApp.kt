package com.lizzie.android

import androidx.compose.animation.*
import androidx.compose.foundation.background
import android.util.Log
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.lizzie.android.ui.board.BoardView
import com.lizzie.android.ui.analysis.BestMovesPanel
import com.lizzie.android.ui.analysis.WinrateGraph
import com.lizzie.android.viewmodel.GameViewModel
import com.lizzie.engine.EngineStatus

@Composable
fun LizzieMobileApp() {
    val viewModel = viewModel<GameViewModel>()
    val gameState by viewModel.gameState.collectAsState()
    val engineStatus by viewModel.engineStatus.collectAsState()

    MaterialTheme(
        colorScheme = if (true) lightColorScheme() else darkColorScheme()
    ) {
        Scaffold(
            topBar = {
                GameTopBar(
                    engineStatus = engineStatus,
                    onSettingsClick = { /* TODO */ },
                    onSgfClick = { /* TODO */ },
                )
            },
            bottomBar = {
                GameBottomBar(
                    // Pass viewModel actions
                )
            }
        ) { padding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
            ) {
                // Engine status indicator
                EngineStatusBar(engineStatus)

                // Board takes the most space
                BoardView(
                    boardData = gameState.boardData,
                    bestMoves = gameState.bestMoves,
                    showCoordinates = gameState.showCoordinates,
                    onIntersectionClick = { x, y ->
                        viewModel.onIntersectionClick(x, y)
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                )

                // Winrate graph
                WinrateGraph(
                    history = gameState.history,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(80.dp),
                )

                // Best moves panel
                BestMovesPanel(
                    bestMoves = gameState.bestMoves,
                    onMoveTap = { move ->
                        viewModel.onBestMoveTap(move)
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 120.dp),
                )
            }
        }
    }
}

@Composable
private fun EngineStatusBar(status: EngineStatus) {
    val (text, color) = when (status) {
        is EngineStatus.Disconnected -> "Engine: Disconnected" to MaterialTheme.colorScheme.error
        is EngineStatus.Connecting -> "Engine: Connecting (${status.info})" to MaterialTheme.colorScheme.tertiary
        is EngineStatus.Ready -> "Engine: ${status.engineName} v${status.version}" to MaterialTheme.colorScheme.primary
        is EngineStatus.Error -> "Engine Error: ${status.message}" to MaterialTheme.colorScheme.error
    }
    Surface(
        color = color.copy(alpha = 0.15f),
        modifier = Modifier.fillMaxWidth()
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GameTopBar(
    engineStatus: com.lizzie.engine.EngineStatus,
    onSettingsClick: () -> Unit,
    onSgfClick: () -> Unit,
) {
    TopAppBar(
        title = { Text("Lizzie Mobile") },
        actions = {
            IconButton(onClick = onSgfClick) {
                // SGF folder icon
            }
            IconButton(onClick = onSettingsClick) {
                // Settings gear icon
            }
        },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant,
        )
    )
}

@Composable
fun GameBottomBar() {
    // Pass / resign / undo buttons
}