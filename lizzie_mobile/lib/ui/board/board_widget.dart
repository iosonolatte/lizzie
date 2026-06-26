import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/analysis.dart';
import '../../go/board_data.dart';
import '../../go/stone.dart';
import '../../state/providers.dart';
import 'board_overlay_painter.dart';

/// A Go board widget that renders grid lines, star points, stones,
/// and analysis overlays (suggestions, ownership heatmap, PV ghost stones).
class BoardWidget extends ConsumerWidget {
  /// Callback when a point is tapped. Receives (x, y).
  final void Function(int x, int y)? onPointTap;

  /// Analysis data for overlays, or null to hide overlays.
  final AnalysisResult? analysis;

  /// Whether scoring mode is active (shows dead-stone markers).
  final bool scoringMode;

  const BoardWidget({super.key, this.onPointTap, this.analysis, this.scoringMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(gameProvider);
    final data = board.data;
    final w = data.width;
    final h = data.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate cell size to fit within available space.
        final maxDim = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        // Leave padding for coordinates.
        final padding = maxDim / (w + 2) * 0.5;
        final cellSize = (maxDim - padding * 2) / (w - 1);

        final boardSize = Size(cellSize * (w - 1), cellSize * (h - 1));

        return Padding(
          padding: EdgeInsets.all(padding + cellSize * 0.5),
          child: GestureDetector(
            onTapUp: (details) {
              _handleTap(details, context, data);
            },
            child: SizedBox(
              width: boardSize.width,
              height: boardSize.height,
              child: Stack(
                children: [
                  // Board grid, stones, coordinates.
                  CustomPaint(
                    size: boardSize,
                    painter: _BoardPainter(
                      data: data,
                      cellSize: cellSize,
                      showCoordinates: true,
                      scoringMode: scoringMode,
                    ),
                  ),
                  // Analysis overlays (suggestions, ownership, PV).
                  if (analysis != null)
                    CustomPaint(
                      size: boardSize,
                      painter: BoardOverlayPainter(
                        boardData: data,
                        cellSize: cellSize,
                        bestMoves: analysis!.bestMoves,
                        ownership: analysis!.ownership,
                        totalPlayouts: analysis!.currentPlayouts,
                        blackToPlay: data.blackToPlay,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(TapUpDetails details, BuildContext context, BoardData data) {
    if (onPointTap == null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final localPos = renderBox.globalToLocal(details.globalPosition);

    // The CustomPaint is sized at cellSize * (w-1) x cellSize * (h-1).
    // Padding around it is (padding + cellSize/2).
    final dx = localPos.dx;
    final dy = localPos.dy;

    // Convert pixel coordinates to board coordinates.
    final cellSize = (renderBox.size.width) / (data.width - 1);
    final x = (dx / cellSize).round();
    final y = (dy / cellSize).round();

    if (x >= 0 && x < data.width && y >= 0 && y < data.height) {
      onPointTap!(x, y);
    }
  }
}

/// Custom painter for the Go board.
class _BoardPainter extends CustomPainter {
  final BoardData data;
  final double cellSize;
  final bool showCoordinates;
  final bool scoringMode;

  _BoardPainter({
    required this.data,
    required this.cellSize,
    this.showCoordinates = true,
    this.scoringMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = data.width;
    final h = data.height;

    // Board background.
    final bgPaint = Paint()..color = const Color(0xFFDCB35C); // wood color
    canvas.drawRect(
      Rect.fromLTWH(-cellSize / 2, -cellSize / 2,
          size.width + cellSize, size.height + cellSize),
      bgPaint,
    );

    // Grid lines.
    final linePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.0;

    for (int i = 0; i < w; i++) {
      final x = i * cellSize;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, (h - 1) * cellSize),
        linePaint,
      );
    }
    for (int i = 0; i < h; i++) {
      final y = i * cellSize;
      canvas.drawLine(
        Offset(0, y),
        Offset((w - 1) * cellSize, y),
        linePaint,
      );
    }

    // Star points.
    final starPaint = Paint()..color = Colors.black87;
    final starPoints = _getStarPoints(w, h);
    for (final pt in starPoints) {
      canvas.drawCircle(
        Offset(pt[0] * cellSize, pt[1] * cellSize),
        cellSize * 0.1,
        starPaint,
      );
    }

    // Stones.
    for (int x = 0; x < w; x++) {
      for (int y = 0; y < h; y++) {
        final idx = x * h + y;
        final stone = data.stones[idx];
        if (stone == Stone.empty) continue;
        // Skip ghost stones (for now — they'll be rendered as semi-transparent in M4).
        if (stone == Stone.blackGhost || stone == Stone.whiteGhost) continue;

        final cx = x * cellSize;
        final cy = y * cellSize;
        final radius = cellSize * 0.44;

        // Determine visual color (dead stones still render as their original color).
        final isDead = stone == Stone.blackCaptured || stone == Stone.whiteCaptured;
        final visualBlack = isDead
            ? (stone == Stone.blackCaptured)
            : stone.isBlack;

        if (visualBlack) {
          // Black stone with 3D effect.
          final gradient = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 0.8,
            colors: [
              Colors.grey[700]!,
              Colors.black,
            ],
          );
          canvas.drawCircle(
            Offset(cx, cy),
            radius,
            Paint()..shader = gradient.createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius)),
          );
        } else {
          // White stone with 3D effect.
          final gradient = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 0.8,
            colors: [
              Colors.white,
              Colors.grey[300]!,
            ],
          );
          canvas.drawCircle(
            Offset(cx, cy),
            radius,
            Paint()..shader = gradient.createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius)),
          );
          // Border.
          canvas.drawCircle(
            Offset(cx, cy),
            radius,
            Paint()
              ..color = Colors.grey[400]!
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
        }

        // Dead stone marker (red X).
        if (isDead) {
          final xPaint = Paint()
            ..color = Colors.red
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
          final xSize = radius * 0.5;
          canvas.drawLine(
            Offset(cx - xSize, cy - xSize),
            Offset(cx + xSize, cy + xSize),
            xPaint,
          );
          canvas.drawLine(
            Offset(cx + xSize, cy - xSize),
            Offset(cx - xSize, cy + xSize),
            xPaint,
          );
        }

        // Last move marker (skip for dead stones).
        if (!isDead &&
            data.lastMove != null &&
            data.lastMove![0] == x &&
            data.lastMove![1] == y) {
          final markerColor = visualBlack ? Colors.white : Colors.black;
          canvas.drawCircle(
            Offset(cx, cy),
            radius * 0.25,
            Paint()..color = markerColor,
          );
        }
      }
    }

    // Coordinates.
    if (showCoordinates) {
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      for (int i = 0; i < w; i++) {
        final label = String.fromCharCode('A'.codeUnitAt(0) + i >= 'I'.codeUnitAt(0)
            ? 'A'.codeUnitAt(0) + i + 1
            : 'A'.codeUnitAt(0) + i);
        textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(color: Colors.black54, fontSize: 10),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(i * cellSize - textPainter.width / 2, -cellSize * 0.6),
        );
      }
      for (int i = 0; i < h; i++) {
        textPainter.text = TextSpan(
          text: '${h - i}',
          style: const TextStyle(color: Colors.black54, fontSize: 10),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(-cellSize * 0.6 - textPainter.width, i * cellSize - textPainter.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.scoringMode != scoringMode;
  }

  /// Return standard star point positions for a given board size.
  static List<List<int>> _getStarPoints(int w, int h) {
    if (w == 19 && h == 19) {
      return [
        [3, 3], [3, 9], [3, 15],
        [9, 3], [9, 9], [9, 15],
        [15, 3], [15, 9], [15, 15],
      ];
    }
    if (w == 13 && h == 13) {
      return [
        [3, 3], [3, 6], [3, 9],
        [6, 3], [6, 6], [6, 9],
        [9, 3], [9, 6], [9, 9],
      ];
    }
    if (w == 9 && h == 9) {
      return [
        [2, 2], [2, 6],
        [4, 4],
        [6, 2], [6, 6],
      ];
    }
    return [];
  }
}
