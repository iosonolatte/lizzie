package com.lizzie.android

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.lizzie.android.ui.board.BoardView
import com.lizzie.android.ui.analysis.BestMovesPanel
import com.lizzie.android.ui.analysis.WinrateGraph
import com.lizzie.android.viewmodel.GameViewModel

@Composable
fun LizzieMobileApp() {
    val viewModel = remember { GameViewModel() }
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