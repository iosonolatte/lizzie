import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../go/stone.dart';
import '../../state/providers.dart';

/// Mini board overview showing stone positions with move number labels.
///
/// Uses [CustomPainter] for compact rendering of grid, stones, and numbers.
class SubboardPanel extends ConsumerWidget {
  const SubboardPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(gameProvider);
    final data = board.data;
    final w = data.width;
    final h = data.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final cellSize = size / (w + 1); // leave a small margin

        return Center(
          child: CustomPaint(
            size: Size(cellSize * w, cellSize * h),
            painter: _SubboardPainter(
              stones: data.stones,
              moveNumberList: data.moveNumberList,
              width: w,
              height: h,
              cellSize: cellSize,
            ),
          ),
        );
      },
    );
  }
}

class _SubboardPainter extends CustomPainter {
  final List<Stone> stones;
  final List<int> moveNumberList;
  final int width;
  final int height;
  final double cellSize;

  _SubboardPainter({
    required this.stones,
    required this.moveNumberList,
    required this.width,
    required this.height,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = width;
    final h = height;

    // Background.
    canvas.drawRect(
      Rect.fromLTWH(
        -cellSize * 0.1,
        -cellSize * 0.1,
        size.width + cellSize * 0.2,
        size.height + cellSize * 0.2,
      ),
      Paint()..color = const Color(0xFFDCB35C),
    );

    // Grid lines.
    final linePaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 0.5;
    for (int i = 0; i < w; i++) {
      final x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, (h - 1) * cellSize), linePaint);
    }
    for (int i = 0; i < h; i++) {
      final y = i * cellSize;
      canvas.drawLine(Offset(0, y), Offset((w - 1) * cellSize, y), linePaint);
    }

    // Star points (small dots).
    final starPaint = Paint()..color = Colors.black54;
    final starPoints = _getStarPoints(w, h);
    for (final pt in starPoints) {
      canvas.drawCircle(
        Offset(pt[0] * cellSize, pt[1] * cellSize),
        cellSize * 0.08,
        starPaint,
      );
    }

    // Stones with move number labels.
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int x = 0; x < w; x++) {
      for (int y = 0; y < h; y++) {
        final idx = x * h + y;
        final stone = stones[idx];
        if (stone == Stone.empty) continue;
        if (stone == Stone.blackGhost || stone == Stone.whiteGhost) continue;

        final cx = x * cellSize;
        final cy = y * cellSize;
        final radius = cellSize * 0.42;

        // Draw stone.
        if (stone.isBlack) {
          canvas.drawCircle(
            Offset(cx, cy),
            radius,
            Paint()..color = Colors.black,
          );
        } else {
          canvas.drawCircle(
            Offset(cx, cy),
            radius,
            Paint()..color = Colors.white,
          );
          canvas.drawCircle(
            Offset(cx, cy),
            radius,
            Paint()
              ..color = Colors.grey[400]!
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.5,
          );
        }

        // Move number label.
        final mn = moveNumberList[idx];
        if (mn > 0) {
          final labelColor = stone.isBlack ? Colors.white : Colors.black;
          final fontSize = cellSize * 0.3;
          textPainter.text = TextSpan(
            text: '$mn',
            style: TextStyle(
              color: labelColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SubboardPainter oldDelegate) {
    return oldDelegate.stones != stones ||
        oldDelegate.moveNumberList != moveNumberList ||
        oldDelegate.cellSize != cellSize;
  }

  static List<List<int>> _getStarPoints(int w, int h) {
    if (w == 19 && h == 19) {
      return [
        [3, 3],
        [3, 9],
        [3, 15],
        [9, 3],
        [9, 9],
        [9, 15],
        [15, 3],
        [15, 9],
        [15, 15],
      ];
    }
    if (w == 13 && h == 13) {
      return [
        [3, 3],
        [3, 6],
        [3, 9],
        [6, 3],
        [6, 6],
        [6, 9],
        [9, 3],
        [9, 6],
        [9, 9],
      ];
    }
    if (w == 9 && h == 9) {
      return [
        [2, 2],
        [2, 6],
        [4, 4],
        [6, 2],
        [6, 6],
      ];
    }
    return [];
  }
}
