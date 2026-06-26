import 'package:flutter/painting.dart' show Size, EdgeInsets;

/// Pure layout math for the Go board widget.
///
/// This exists as a separate class so the layout computation can be
/// unit-tested without spinning up a Flutter widget tree, and so the
/// build method and the tap handler in `BoardWidget` share the exact
/// same numbers.
///
/// Coordinates:
///
/// * `maxDim` is the smaller of the available width and height
///   (the board is always square).
/// * `cellSize` is the distance between two adjacent grid lines.
/// * `padding` is the outer margin for the coordinate labels.
/// * The SizedBox is `(boardSize.width, boardSize.height) = (cellSize * (w-1), cellSize * (h-1))`.
/// * The Padding around the SizedBox is `padding + cellSize*0.5` on each side.
///   The extra `cellSize*0.5` keeps the coordinate labels (which the
///   painter draws at SizedBox-relative `y = -cellSize*0.6`) inside the
///   LayoutBuilder.
/// * The grid is positioned at SizedBox-relative (0, 0) to
///   (cellSize*(w-1), cellSize*(h-1)).
/// * Stone (i, j) in the grid is at SizedBox-relative (i*cellSize, j*cellSize).
///   In LayoutBuilder-relative coordinates that's
///   `(padding + cellSize*0.5 + i*cellSize, padding + cellSize*0.5 + j*cellSize)`.
///
/// The [toBoardX] / [toBoardY] methods convert a LayoutBuilder-relative
/// touch position back to a board coordinate.
class BoardLayout {
  final int width;
  final int height;
  final double maxDim;
  final double padding;
  final double cellSize;

  const BoardLayout({
    required this.width,
    required this.height,
    required this.maxDim,
    required this.padding,
    required this.cellSize,
  });

  /// Compute a layout that fits exactly in [maxDim] (with a uniform
  /// outer padding for the coordinate labels).
  ///
  /// With `cellSize = (maxDim - 2*padding) / w` and a Padding of
  /// `padding + cellSize*0.5` on each side, the total footprint is
  /// `cellSize*(w-1) + 2*(padding + cellSize*0.5) = cellSize*w + 2*padding = maxDim`.
  /// So the SizedBox + Padding exactly fills the LayoutBuilder; no
  /// overflow on the edges.
  ///
  /// (The old formula used `cellSize = (maxDim - 2*padding) / (w-1)`,
  /// which made the SizedBox overflow the LayoutBuilder by `cellSize*0.5`
  /// on each side. The off-by-one in the tap handler at the edges
  /// was the visible symptom.)
  factory BoardLayout.compute({
    required int width,
    required int height,
    required double maxDim,
  }) {
    assert(width >= 2 && height >= 2, 'board must be at least 2x2');
    assert(maxDim > 0, 'maxDim must be positive');
    final padding = maxDim / (width + 2) * 0.5;
    final cellSize = (maxDim - 2 * padding) / width;
    return BoardLayout(
      width: width,
      height: height,
      maxDim: maxDim,
      padding: padding,
      cellSize: cellSize,
    );
  }

  /// The size of the SizedBox that holds the board.
  Size get boardSize => Size(cellSize * (width - 1), cellSize * (height - 1));

  /// The Padding around the SizedBox: outer margin for labels plus half a
  /// cell so the labels stay inside the LayoutBuilder.
  EdgeInsets get outerPadding => EdgeInsets.all(padding + cellSize * 0.5);

  /// The position of stone (x, y) in LayoutBuilder-relative coords.
  double stoneX(int x) => padding + cellSize * 0.5 + x * cellSize;
  double stoneY(int y) => padding + cellSize * 0.5 + y * cellSize;

  /// Convert a LayoutBuilder-relative x position to a board column.
  /// Returns null if the touch is outside the board.
  int? toBoardX(double dx) {
    final x = ((dx - stoneX(0)) / cellSize).round();
    if (x < 0 || x >= width) return null;
    return x;
  }

  /// Convert a LayoutBuilder-relative y position to a board row.
  /// Returns null if the touch is outside the board.
  int? toBoardY(double dy) {
    final y = ((dy - stoneY(0)) / cellSize).round();
    if (y < 0 || y >= height) return null;
    return y;
  }
}
