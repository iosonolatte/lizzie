package com.lizzie.android.ui.analysis

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.lizzie.rules.BoardHistoryList
import com.lizzie.rules.BoardHistoryNode

/**
 * Winrate graph showing black winrate over move history.
 */
@Composable
fun WinrateGraph(
    history: BoardHistoryList,
    modifier: Modifier = Modifier,
) {
    val dataPoints = remember(history) { computeWinrateHistory(history) }

    Canvas(modifier = modifier.fillMaxWidth().height(60.dp)) {
        if (dataPoints.isEmpty()) return@Canvas

        val graphWidth = size.width
        val graphHeight = size.height
        val padding = 4f

        // Background
        drawRect(Color(0xFFF5F5F5))

        // 50% line
        drawLine(
            color = Color(0xFFCCCCCC),
            start = Offset(0f, graphHeight / 2),
            end = Offset(graphWidth, graphHeight / 2),
            strokeWidth = 1f,
        )

        if (dataPoints.size < 2) return@Canvas

        val maxMoves = dataPoints.size - 1
        val path = Path()
        val stepX = graphWidth / maxMoves.toFloat()

        dataPoints.forEachIndexed { i, winrate ->
            val x = i * stepX
            // winrate: 0-100, map to y (0 at bottom = 100%, height at top = 0%)
            val y = graphHeight - ((winrate / 100.0) * (graphHeight - 2.0 * padding)) - padding
            if (i == 0) path.moveTo(x, y.toFloat()) else path.lineTo(x, y.toFloat())
        }

        drawPath(
            path = path,
            color = Color(0xFF2196F3),
            style = Stroke(width = 2f),
        )

        // Fill under the curve
        val fillPath = Path()
        fillPath.addPath(path)
        fillPath.lineTo(graphWidth, graphHeight)
        fillPath.lineTo(0f, graphHeight)
        fillPath.close()

        drawPath(
            path = fillPath,
            color = Color(0x332196F3),
        )
    }
}

/**
 * Best moves analysis panel showing top candidate moves with winrates.
 */
@Composable
fun BestMovesPanel(
    bestMoves: List<com.lizzie.analysis.MoveData>,
    onMoveTap: (com.lizzie.analysis.MoveData) -> Unit,
    modifier: Modifier = Modifier,
) {
    if (bestMoves.isEmpty()) {
        // Empty state
        return
    }

    Column(modifier = modifier.padding(horizontal = 8.dp, vertical = 4.dp)) {
        Text(
            text = "Best Moves",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            val topMoves = bestMoves.take(5)
            for (move in topMoves) {
                BestMoveChip(
                    move = move,
                    index = topMoves.indexOf(move) + 1,
                    onTap = { onMoveTap(move) },
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun BestMoveChip(
    move: com.lizzie.analysis.MoveData,
    index: Int,
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    androidx.compose.material3.Card(
        onClick = onTap,
        modifier = modifier,
    ) {
        Column(
            modifier = Modifier.padding(4.dp),
            horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally,
        ) {
            Text(
                text = move.coordinate,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = "%.1f%%".format(move.winrate * 100),
                style = MaterialTheme.typography.labelSmall,
            )
            Text(
                text = "${move.playouts}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

private fun computeWinrateHistory(history: BoardHistoryList): List<Double> {
    val winrates = mutableListOf<Double>()
    var node: BoardHistoryNode? = history.root()
    while (node != null) {
        val w = node.data.getDisplayWinrate(true) // always black perspective
        winrates.add(w)
        node = node.next()
    }
    return winrates
}