import 'dart:math';
import 'package:flutter/material.dart';
import '../../go/board_data.dart';
import '../../go/coords.dart';
import '../../go/move_data.dart';

/// Overlay painter that draws analysis information on top of the Go board.
///
/// Renders, in order (back to front):
/// 1. Ownership heatmap rectangles (greyscale, behind everything)
/// 2. Suggestion labels (colored circles with winrate/playouts text)
/// 3. PV ghost stones (semi-transparent principal variation stones)
///
/// Intended to be stacked above the board's [_BoardPainter] via a [Stack].
class BoardOverlayPainter extends CustomPainter {
  final BoardData boardData;
  final double cellSize;
  final List<MoveData> bestMoves;
  final List<double>? ownership;
  final int totalPlayouts;
  final bool blackToPlay;

  BoardOverlayPainter({
    required this.boardData,
    required this.cellSize,
    required this.bestMoves,
    this.ownership,
    this.totalPlayouts = 0,
    this.blackToPlay = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Ownership heatmap (back-most layer).
    _drawOwnership(canvas, size);

    // 2. Suggestion labels.
    _drawSuggestions(canvas, size);

    // 3. PV ghost stones (front-most layer).
    _drawGhostStones(canvas, size);
  }

  @override
  bool shouldRepaint(covariant BoardOverlayPainter oldDelegate) {
    return oldDelegate.boardData != boardData ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.bestMoves != bestMoves ||
        oldDelegate.ownership != ownership ||
        oldDelegate.totalPlayouts != totalPlayouts;
  }

  // ---------------------------------------------------------------------------
  // Ownership heatmap
  // ---------------------------------------------------------------------------

  void _drawOwnership(Canvas canvas, Size size) {
    if (ownership == null || ownership!.isEmpty) return;

    final w = boardData.width;
    final h = boardData.height;

    for (int x = 0; x < w; x++) {
      for (int y = 0; y < h; y++) {
        final idx = boardData.indexOf(x, y);
        if (idx >= ownership!.length) continue;

        final value = ownership![idx];
        // Skip near-zero values (less than 1% ownership).
        if (value.abs() < 0.01) continue;

        final cx = x * cellSize;
        final cy = y * cellSize;

        // Alpha proportional to absolute value, clamped 0-255.
        final alpha = (value.abs().clamp(0.0, 1.0) * 200).round().clamp(0, 200);

        // Positive = black territory, Negative = white territory.
        Color color;
        if (value > 0) {
          color = Color.fromARGB(alpha, 0, 0, 0); // black territory
        } else {
          color = Color.fromARGB(alpha, 255, 255, 255); // white territory
        }

        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: cellSize * 0.9,
            height: cellSize * 0.9,
          ),
          Paint()..color = color,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Suggestion labels
  // ---------------------------------------------------------------------------

  void _drawSuggestions(Canvas canvas, Size size) {
    if (bestMoves.isEmpty) return;

    final totalVisits = totalPlayouts > 0 ? totalPlayouts : MoveData.totalPlayouts(bestMoves);

    for (final move in bestMoves) {
      final xy = Coords.gtpToXY(move.coordinate, boardData.width, boardData.height);
      if (xy == null) continue;

      final x = xy[0];
      final y = xy[1];
      final cx = x * cellSize;
      final cy = y * cellSize;

      // Calculate color from winrate.
      final color = _suggestionColor(move.winrate);

      // Calculate alpha from playout fraction (log-based).
      final playoutFraction = totalVisits > 0 ? move.playouts / totalVisits : 0.0;
      final alpha = _playoutAlpha(playoutFraction);

      // Draw filled circle.
      final radius = cellSize * 0.38;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()..color = color.withValues(alpha: alpha),
      );

      // Draw circle border.
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = Colors.black38
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Draw text (winrate + playouts).
      _drawSuggestionText(canvas, cx, cy, move);
    }
  }

  /// Compute label color from winrate (0-100).
  ///
  /// Uses HSB gradient:
  /// - Best move → cyan (hue 180°)
  /// - Good → green (hue 120°)
  /// - Neutral → yellow (hue 60°)
  /// - Bad → red (hue 0°)
  ///
  /// The hue is mapped from winrate 50→0° (red) to 50→180° (cyan),
  /// so 50% winrate is yellow-green.
  Color _suggestionColor(double winrate) {
    // Map winrate 0-100 to hue 0-180.
    // Below 50%: red→yellow (0→60), above 50%: yellow→cyan (60→180).
    final hue = (winrate / 100.0 * 180.0).clamp(0.0, 180.0);
    return HSVColor.fromAHSV(1.0, hue, 0.9, 0.9).toColor();
  }

  /// Compute alpha from playout fraction using log scaling.
  ///
  /// A move with 1 playout among 1000 gets ~0.3 alpha;
  /// a move with 500 playouts among 1000 gets ~0.9 alpha.
  double _playoutAlpha(double fraction) {
    if (fraction <= 0) return 0.0;
    // log-based: alpha = 0.3 + 0.7 * log10(1 + 9 * fraction)
    return (0.3 + 0.7 * log(1.0 + 9.0 * fraction) / log(10)).clamp(0.0, 1.0);
  }

  void _drawSuggestionText(Canvas canvas, double cx, double cy, MoveData move) {
    final textStyle = TextStyle(
      color: Colors.black87,
      fontSize: cellSize * 0.22,
      fontWeight: FontWeight.bold,
      height: 1.0,
    );

    final winrateStr = '${move.winrate.toStringAsFixed(1)}%';
    final playoutsStr = '${move.playouts}';

    // Winrate line.
    final wrPainter = TextPainter(
      text: TextSpan(text: winrateStr, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    wrPainter.layout(maxWidth: cellSize * 0.7);
    wrPainter.paint(
      canvas,
      Offset(cx - wrPainter.width / 2, cy - cellSize * 0.14 - wrPainter.height),
    );

    // Playouts line.
    final plPainter = TextPainter(
      text: TextSpan(text: playoutsStr, style: textStyle.copyWith(
        fontSize: cellSize * 0.18,
        fontWeight: FontWeight.normal,
      )),
      textDirection: TextDirection.ltr,
    );
    plPainter.layout(maxWidth: cellSize * 0.7);
    plPainter.paint(
      canvas,
      Offset(cx - plPainter.width / 2, cy + cellSize * 0.02),
    );
  }

  // ---------------------------------------------------------------------------
  // PV ghost stones
  // ---------------------------------------------------------------------------

  void _drawGhostStones(Canvas canvas, Size size) {
    if (bestMoves.isEmpty) return;

    // Only draw PV for the top move (or first few).
    // Each move's variation lists GTP coordinates for the PV.
    for (final move in bestMoves) {
      if (move.variation.isEmpty) continue;

      // Skip the first coordinate — it's the move itself (already shown as suggestion).
      final pvStart = move.variation.length > 1 ? 1 : 0;

      // Only show PV for top 3 moves to avoid visual clutter.
      if (move.order > 2) continue;

      for (int i = pvStart; i < move.variation.length; i++) {
        final coord = move.variation[i];
        final xy = Coords.gtpToXY(coord, boardData.width, boardData.height);
        if (xy == null) continue;

        final x = xy[0];
        final y = xy[1];
        final cx = x * cellSize;
        final cy = y * cellSize;

        // Determine stone color from PV alternation.
        // The move itself is the suggestion (e.g. black to play).
        // Even indices in PV after start = opponent, odd = current player.
        final isBlack = blackToPlay ? (i % 2 == 0) : (i % 2 == 1);
        final radius = cellSize * 0.44;

        if (isBlack) {
          // Black ghost stone.
          canvas.drawCircle(
            Offset(cx, cy),
            radius,
            Paint()..color = Colors.black.withValues(alpha: 0.24),
          );
          // Border for definition.
          canvas.drawCircle(
            Offset(cx, cy),
            radius,
            Paint()
              ..color = Colors.black54
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
        } else {
          // White ghost stone.
          canvas.drawCircle(
            Offset(cx, cy),
            radius,
            Paint()..color = Colors.white.withValues(alpha: 0.24),
          );
          canvas.drawCircle(
            Offset(cx, cy),
            radius,
            Paint()
              ..color = Colors.black38
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0,
          );
        }
      }
    }
  }
}
