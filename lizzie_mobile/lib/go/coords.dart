/// Coordinate conversion utilities for Go board coordinates.
///
/// Lizzie supports two coordinate schemes:
/// - **GTP** (A-T skipping I, base-25 letters): used by KataGo/Leela Zero
/// - **SGF** (a-z including i, lowercase): used in .sgf files
///
/// Ported from `Board.java` (GTP) and `SGFParser.java` (SGF).
class Coords {
  /// GTP alphabet: A-T skipping I (25 chars).
  static const _gtpAlpha = 'ABCDEFGHJKLMNOPQRSTUVWXYZ';

  /// SGF alphabet: lowercase a-z, uppercase A-Z (52 chars, includes i).
  static const _sgfAlpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

  // ---------------------------------------------------------------------------
  // GTP ↔ (x, y)
  // ---------------------------------------------------------------------------

  /// Parse a GTP-style coordinate string like "C16" or "PASS" (case-insensitive).
  /// Returns `[x, y]` or `null` for pass/resign.
  static List<int>? gtpToXY(String coord, int boardWidth, int boardHeight) {
    final upper = coord.trim().toUpperCase();
    if (upper == 'PASS' || upper == 'RESIGN') return null;

    final match = RegExp(r'^([A-HJ-Z]+)(\d+)$').firstMatch(upper);
    if (match == null) return null;

    final letters = match.group(1)!;
    final digits = match.group(2)!;

    final x = _gtpLetterToIndex(letters);
    final y = boardHeight - int.parse(digits);
    if (x < 0 || x >= boardWidth || y < 0 || y >= boardHeight) return null;
    return [x, y];
  }

  /// Convert [x, y] to a GTP coordinate string like "C16".
  /// Returns "pass" for null/out-of-bounds? No — caller chooses.
  static String? xyToGtp(int x, int y, int boardWidth, int boardHeight) {
    if (boardWidth > 25 || boardHeight > 25) {
      return '($x,$y)';
    }
    return '${_gtpIndexToLetter(x)}${boardHeight - y}';
  }

  /// Base-25 letter(s) to x index. Supports multi-letter for boards > 25 wide.
  static int _gtpLetterToIndex(String letters) {
    int x = 0;
    for (int i = 0; i < letters.length; i++) {
      final c = _gtpAlpha.indexOf(letters[i]);
      if (c < 0) return -1;
      x = x * 25 + c;
    }
    return x;
  }

  /// x index to base-25 letter(s).
  static String _gtpIndexToLetter(int x) {
    if (x < 25) return _gtpAlpha[x];
    // Multi-letter for boards > 25.
    final sb = StringBuffer();
    while (x >= 0) {
      sb.write(_gtpAlpha[x % 25]);
      x = x ~/ 25 - 1;
    }
    return sb.toString().split('').reversed.join();
  }

  // ---------------------------------------------------------------------------
  // SGF ↔ (x, y)
  // ---------------------------------------------------------------------------

  /// Parse an SGF coordinate string like "cd" (two lowercase letters).
  /// Returns `[x, y]` or `null` for pass (empty string, "tt", or "pass").
  static List<int>? sgfToXY(String coord, int boardWidth, int boardHeight) {
    final c = coord.trim().toLowerCase();
    if (c.isEmpty || c == 'tt' || c == 'pass') return null;

    final x = _sgfAlpha.indexOf(c[0]);
    final y = _sgfAlpha.indexOf(c[1]);
    if (x < 0 || y < 0 || x >= boardWidth || y >= boardHeight) return null;
    return [x, y];
  }

  /// Convert [x, y] to an SGF coordinate string like "cd".
  static String xyToSgf(int x, int y) {
    return '${_sgfAlpha[x]}${_sgfAlpha[y]}';
  }

  /// Check if an SGF coordinate string represents a pass.
  static bool isSgfPass(String coord) {
    final c = coord.trim().toLowerCase();
    return c.isEmpty || c == 'tt' || c == 'pass';
  }
}
