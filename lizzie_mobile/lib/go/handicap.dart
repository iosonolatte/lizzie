/// Standard Go handicap stone placement tables.
///
/// Lizzie's Java code doesn't have a built-in handicap placement table
/// (handicap enters only via SGF AB[] + flatten()). This Dart port adds
/// the standard fixed_handicap coordinate tables for the common board sizes.
class Handicap {
  /// Returns the list of `[x, y]` coordinates for `n` handicap stones
  /// (2..9) on a `size` × `size` board.
  ///
  /// Returns an empty list for unsupported sizes or invalid `n`.
  ///
  /// Follows the standard GTP `fixed_handicap` convention used by
  /// KataGo and Leela Zero.
  static List<List<int>> placement(int n, int size) {
    if (size != 19 && size != 13 && size != 9) return [];
    if (n < 2 || n > 9) return [];

    switch (size) {
      case 19:
        return _placement19(n);
      case 13:
        return _placement13(n);
      case 9:
        return _placement9(n);
      default:
        return [];
    }
  }

  /// 19×19 star points (0-indexed):
  ///   (3,3), (15,15)      — diagonal corners, n=2
  ///   + (9,9)             — tengen, n=3
  ///   + (3,15), (15,3)    — remaining corners, n=4,5
  ///   + (3,9), (15,9)     — side centers, n=6,7
  ///   + (9,3), (9,15)     — remaining sides, n=8,9
  static List<List<int>> _placement19(int n) {
    const corners = [
      [3, 3], [15, 15], // diagonal
      [9, 9], // tengen
      [3, 15], [15, 3], // other corners
      [3, 9], [15, 9], // left/right side
      [9, 3], [9, 15], // top/bottom side
    ];
    return corners.take(n).toList();
  }

  /// 13×13 star points:
  static List<List<int>> _placement13(int n) {
    const points = [
      [3, 3], [9, 9],
      [6, 6], // tengen
      [3, 9], [9, 3],
      [3, 6], [9, 6],
      [6, 3], [6, 9],
    ];
    return points.take(n).toList();
  }

  /// 9×9 star points:
  static List<List<int>> _placement9(int n) {
    const points = [
      [2, 2], [6, 6],
      [4, 4], // tengen
      [2, 6], [6, 2],
      [2, 4], [6, 4],
      [4, 2], [4, 6],
    ];
    return points.take(n).toList();
  }
}
