package com.lizzie.android.ui.board

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.*
import androidx.compose.ui.unit.dp
import com.lizzie.analysis.MoveData
import com.lizzie.rules.Board
import com.lizzie.rules.BoardData
import com.lizzie.rules.Stone
import kotlin.math.min

/**
 * Go board rendered with Jetpack Compose Canvas.
 */
@Composable
fun BoardView(
    boardData: BoardData,
    bestMoves: List<MoveData>,
    showCoordinates: Boolean,
    onIntersectionClick: (Int, Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val boardSize = 19
    val boardWidth = boardSize
    val boardHeight = boardSize

    val textMeasurer = rememberTextMeasurer()

    Canvas(
        modifier = modifier
            .aspectRatio(1f)
            .background(Color(0xFFDCB35C)) // Wood background
            .pointerInput(boardData) {
                detectTapGestures { offset ->
                    val size = this.size
                    val marginFraction = if (showCoordinates) 0.07 else 0.04
                    val sqSize = size.width / (boardWidth + marginFraction * 2)
                    val margin = sqSize * marginFraction

                    val boardX = ((offset.x - margin) / sqSize + 0.5).toInt()
                    val boardY = ((offset.y - margin) / sqSize + 0.5).toInt()

                    if (boardX in 0 until boardWidth && boardY in 0 until boardHeight) {
                        onIntersectionClick(boardX, boardY)
                    }
                }
            }
    ) {
        val canvasSize = min(size.width, size.height)
        val marginFraction = if (showCoordinates) 0.07 else 0.04
        val squareSize = canvasSize / (boardWidth + marginFraction * 2)
        val margin = squareSize * marginFraction

        // ---- Board background ----
        drawRect(
            color = Color(0xFFDCB35C),
            topLeft = Offset.Zero,
            size = Size(canvasSize, canvasSize),
        )

        // ---- Grid lines ----
        val gridColor = Color(0xFF333333)
        val lineWidth = 1.5f

        for (i in 0 until boardWidth) {
            val x = margin + i * squareSize
            // Vertical line
            drawLine(
                color = gridColor,
                start = Offset(x, margin),
                end = Offset(x, margin + (boardHeight - 1) * squareSize),
                strokeWidth = lineWidth,
            )
            // Horizontal line
            drawLine(
                color = gridColor,
                start = Offset(margin, x),
                end = Offset(margin + (boardWidth - 1) * squareSize, x),
                strokeWidth = lineWidth,
            )
        }

        // ---- Star points ----
        val starRadius = squareSize * 0.12f
        for ((sx, sy) in Board.starPoints(boardWidth)) {
            drawCircle(
                color = gridColor,
                radius = starRadius,
                center = Offset(margin + sx * squareSize, margin + sy * squareSize),
            )
        }

        // ---- Stones ----
        for (y in 0 until boardHeight) {
            for (x in 0 until boardWidth) {
                val stone = boardData.stones[Board.getIndex(x, y, boardWidth)]
                if (stone == Stone.EMPTY) continue

                val cx = margin + x * squareSize
                val cy = margin + y * squareSize
                val stoneRadius = squareSize * 0.44f

                when (stone) {
                    Stone.BLACK -> {
                        // Black stone with gradient
                        drawCircle(
                            brush = Brush.radialGradient(
                                colors = listOf(Color(0xFF555555), Color(0xFF111111), Color(0xFF000000)),
                                center = Offset(cx - stoneRadius * 0.3f, cy - stoneRadius * 0.3f),
                                radius = stoneRadius * 1.2f,
                            ),
                            radius = stoneRadius,
                            center = Offset(cx, cy),
                        )
                    }
                    Stone.WHITE -> {
                        // White stone with gradient
                        drawCircle(
                            brush = Brush.radialGradient(
                                colors = listOf(Color.White, Color(0xFFDDDDDD), Color(0xFFBBBBBB)),
                                center = Offset(cx - stoneRadius * 0.3f, cy - stoneRadius * 0.3f),
                                radius = stoneRadius * 1.2f,
                            ),
                            radius = stoneRadius,
                            center = Offset(cx, cy),
                        )
                        // Subtle border
                        drawCircle(
                            color = Color(0xFF999999),
                            radius = stoneRadius,
                            center = Offset(cx, cy),
                            style = Stroke(width = 1f),
                        )
                    }
                    else -> {}
                }
            }
        }

        // ---- Last move marker ----
        boardData.lastMove?.let { (lx, ly) ->
            val markerX = margin + lx * squareSize
            val markerY = margin + ly * squareSize
            val markerRadius = squareSize * 0.15f

            val markerColor = if (boardData.stones[Board.getIndex(lx, ly, boardWidth)] == Stone.BLACK) {
                Color.White
            } else {
                Color.Black
            }

            drawCircle(
                color = markerColor,
                radius = markerRadius,
                center = Offset(markerX, markerY),
                style = Stroke(width = 2f),
            )
        }

        // ---- Move numbers ----
        // ... (rendered if enabled)

        // ---- Best move overlays (winrate labels) ----
        if (bestMoves.isNotEmpty()) {
            drawBestMoveLabels(bestMoves, margin, squareSize, boardWidth)
        }

        // ---- Coordinates ----
        if (showCoordinates) {
            val coordColor = Color(0xFF555555)
            val coordStyle = TextStyle(
                color = coordColor,
                fontSize = androidx.compose.ui.unit.TextUnit(
                    squareSize * 0.35f,
                    androidx.compose.ui.unit.TextUnitType.Sp
                ),
            )

            val alphabet = "ABCDEFGHJKLMNOPQRSTUVWXYZ"
            // Column labels (letters)
            for (x in 0 until boardWidth) {
                val label = alphabet[x].toString()
                val result = textMeasurer.measure(
                    AnnotatedString(label),
                    style = coordStyle,
                )
                drawText(
                    textLayoutResult = result,
                    topLeft = Offset(
                        margin + x * squareSize - result.size.width / 2f,
                        margin - result.size.height - 4f,
                    ),
                )
                drawText(
                    textLayoutResult = result,
                    topLeft = Offset(
                        margin + x * squareSize - result.size.width / 2f,
                        margin + (boardHeight - 1) * squareSize + 4f,
                    ),
                )
            }
            // Row labels (numbers)
            for (y in 0 until boardHeight) {
                val label = "${boardHeight - y}"
                val result = textMeasurer.measure(
                    AnnotatedString(label),
                    style = coordStyle,
                )
                drawText(
                    textLayoutResult = result,
                    topLeft = Offset(
                        margin - result.size.width - 4f,
                        margin + y * squareSize - result.size.height / 2f,
                    ),
                )
                drawText(
                    textLayoutResult = result,
                    topLeft = Offset(
                        margin + (boardWidth - 1) * squareSize + 4f,
                        margin + y * squareSize - result.size.height / 2f,
                    ),
                )
            }
        }
    }
}

/**
 * Draw winrate labels and playout counts for the top best moves.
 */
private fun DrawScope.drawBestMoveLabels(
    bestMoves: List<MoveData>,
    margin: Float,
    squareSize: Float,
    boardWidth: Int,
) {
    val topMoves = bestMoves.take(3)

    for (move in topMoves) {
        if (move.coordinate.isEmpty() || move.coordinate.length < 2) continue
        val coord = Board.asCoordinates(move.coordinate)
        if (coord == null) continue

        val (x, y) = coord
        val cx = margin + x * squareSize
        val cy = margin + y * squareSize

        // Semi-transparent circle for best move
        drawCircle(
            color = Color(0x44000000),
            radius = squareSize * 0.48f,
            center = Offset(cx, cy),
        )

        // Winrate text
        val winrateText = "%.1f%%".format(move.winrate * 100)
        val labelStyle = TextStyle(
            color = Color.White,
            fontSize = androidx.compose.ui.unit.TextUnit(
                squareSize * 0.28f,
                androidx.compose.ui.unit.TextUnitType.Sp
            ),
        )
        // Draw text using drawContext.canvas
        // (Text rendering in Canvas requires textMeasurer)
    }
}

/** Light preview state for development. */
fun previewBoardData(): BoardData {
    val board = BoardData.empty()
    val stones = board.stones.clone()
    val zobrist = board.zobrist
    // Place a few stones for visual reference
    val indices = listOf(
        Pair(3, 3) to Stone.BLACK,
        Pair(15, 15) to Stone.WHITE,
        Pair(3, 15) to Stone.WHITE,
        Pair(15, 3) to Stone.BLACK,
        Pair(9, 9) to Stone.BLACK,
        Pair(9, 10) to Stone.WHITE,
    )
    for ((coord, color) in indices) {
        val idx = Board.getIndex(coord.first, coord.second)
        stones[idx] = color
        // zobrist toggle — simplified
    }
    return board.copy(
        stones = stones,
        lastMove = Pair(9, 9),
        lastMoveColor = Stone.BLACK,
        blackToPlay = false,
    )
}