import 'board_data.dart';
import 'board_history_list.dart';
import 'coords.dart';
import 'handicap.dart';
import 'stone.dart';
import 'zobrist.dart';

/// Core Go board rules engine.
///
/// Ported from Lizzie's `Board.java`.
///
/// Handles: stone placement, capture (flood-fill + liberty check), ko
/// (grandparent zobrist), suicide rejection, pass, coordinate conversion,
/// handicap setup.
class Board {
  int width;
  int height;
  late final Zobrist _zobrist;

  final BoardHistoryList history;

  Board({int width = 19, int height = 19})
      : width = width,
        height = height,
        _zobrist = Zobrist.init(width, height, 0),
        history = BoardHistoryList(BoardData.empty(width: width, height: height));

  // ---------------------------------------------------------------------------
  // Coordinate utilities
  // ---------------------------------------------------------------------------

  int indexOf(int x, int y) => x * height + y;

  bool isValid(int x, int y) =>
      x >= 0 && x < width && y >= 0 && y < height;

  /// Parse a GTP coordinate string like "C16" → [x, y].
  List<int>? parseGtpCoord(String coord) =>
      Coords.gtpToXY(coord, width, height);

  /// Convert [x, y] to a GTP string like "C16".
  String? coordToGtp(int x, int y) =>
      Coords.xyToGtp(x, y, width, height);

  /// Convert [x, y] to an SGF string like "cd".
  String coordToSgf(int x, int y) => Coords.xyToSgf(x, y);

  // ---------------------------------------------------------------------------
  // Query current state
  // ---------------------------------------------------------------------------

  BoardData get data => history.data;

  List<Stone> get stones => data.stones;

  int get moveNumber => data.moveNumber;

  bool get blackToPlay => data.blackToPlay;

  // ---------------------------------------------------------------------------
  // Capture algorithm
  // ---------------------------------------------------------------------------

  /// Recursive flood-fill: check if the group at (x, y) has any liberties.
  /// MUTATES `stones` in place (marks visited cells with `*_RECURSED` variants).
  /// Caller MUST follow up with [cleanupHasLibertiesHelper].
  static bool _hasLibertiesHelper(
      int x, int y, Stone color, List<Stone> stones, int w, int h) {
    if (x < 0 || x >= w || y < 0 || y >= h) return false;
    final idx = x * h + y;
    final s = stones[idx];
    if (s == Stone.empty) return true; // found a liberty
    if (s != color) return false; // enemy or already visited
    stones[idx] = color.recursed; // mark visited
    return _hasLibertiesHelper(x + 1, y, color, stones, w, h) ||
        _hasLibertiesHelper(x, y + 1, color, stones, w, h) ||
        _hasLibertiesHelper(x - 1, y, color, stones, w, h) ||
        _hasLibertiesHelper(x, y - 1, color, stones, w, h);
  }

  /// Cleanup after [hasLibertiesHelper]: either restore stones or remove them.
  /// Returns number of stones removed.
  static int _cleanupHelper(int x, int y, Stone recursedColor,
      List<Stone> stones, Zobrist zobrist, int w, int h, bool remove) {
    if (x < 0 || x >= w || y < 0 || y >= h) return 0;
    final idx = x * h + y;
    if (stones[idx] != recursedColor) return 0;
    if (remove) {
      stones[idx] = Stone.empty;
      zobrist.toggleStone(x, y, w, h, recursedColor.unrecursed);
    } else {
      stones[idx] = recursedColor.unrecursed;
    }
    int removed = remove ? 1 : 0;
    removed += _cleanupHelper(x + 1, y, recursedColor, stones, zobrist, w, h, remove);
    removed += _cleanupHelper(x, y + 1, recursedColor, stones, zobrist, w, h, remove);
    removed += _cleanupHelper(x - 1, y, recursedColor, stones, zobrist, w, h, remove);
    removed += _cleanupHelper(x, y - 1, recursedColor, stones, zobrist, w, h, remove);
    return removed;
  }

  /// Remove a dead chain (group with no liberties) starting at (x, y).
  /// Returns number of stones removed.
  static int _removeDeadChain(int x, int y, Stone color, List<Stone> stones,
      Zobrist zobrist, int w, int h) {
    if (!(x >= 0 && x < w && y >= 0 && y < h)) return 0;
    final idx = x * h + y;
    if (stones[idx] != color) return 0;
    final hasLibs = _hasLibertiesHelper(x, y, color, stones, w, h);
    return _cleanupHelper(x, y, color.recursed, stones, zobrist, w, h, !hasLibs);
  }

  // ---------------------------------------------------------------------------
  // Place a stone
  // ---------------------------------------------------------------------------

  /// Place a stone at GTP coordinate [coord] (e.g. "C16" or "PASS").
  /// Returns true if the move was accepted, false if illegal.
  bool play(String coord) {
    final xy = parseGtpCoord(coord);
    if (xy == null) {
      // Pass
      return _doPass(blackToPlay ? Stone.black : Stone.white);
    }
    return place(xy[0], xy[1], blackToPlay ? Stone.black : Stone.white);
  }

  /// Place a stone at (x, y) of [color].
  /// Returns true if the move was accepted, false if illegal.
  bool place(int x, int y, Stone color, {bool newBranch = false, bool changeMove = false}) {
    if (!isValid(x, y)) return false;

    final stones = data.stones.toList(growable: false);
    final zobrist = _zobrist.clone();
    final lastMove = [x, y];
    final moveNumber = data.moveNumber + 1;
    final idx = indexOf(x, y);

    // If the point is occupied, only allow if creating a branch.
    if (stones[idx] != Stone.empty && !newBranch) return false;

    // Compute next winrate (flip perspective).
    final nextWinrate = 100.0 - data.winrate;
    final nextScoreMean = -data.scoreMean;

    // Clone moveNumberList.
    final moveNumberList = data.moveNumberList.toList(growable: false);
    moveNumberList[idx] = moveNumber;

    // Place the stone.
    stones[idx] = color;
    zobrist.toggleStone(x, y, width, height, color);

    // Capture opponent groups around the placed stone.
    int capturedStones = 0;
    capturedStones += _removeDeadChain(x + 1, y, color.opposite, stones, zobrist, width, height);
    capturedStones += _removeDeadChain(x, y + 1, color.opposite, stones, zobrist, width, height);
    capturedStones += _removeDeadChain(x - 1, y, color.opposite, stones, zobrist, width, height);
    capturedStones += _removeDeadChain(x, y - 1, color.opposite, stones, zobrist, width, height);

    // Check suicide — does the just-placed group have liberties?
    final isSuicidal = _removeDeadChain(x, y, color, stones, zobrist, width, height);

    // Clear move numbers on empty cells.
    for (int i = 0; i < stones.length; i++) {
      if (stones[i] == Stone.empty) {
        moveNumberList[i] = 0;
      }
    }

    // Update capture counts.
    int bc = data.blackCaptures;
    int wc = data.whiteCaptures;
    if (color.isBlack) {
      bc += capturedStones;
    } else {
      wc += capturedStones;
    }

    final newState = BoardData(
      width: width,
      height: height,
      stones: stones,
      lastMove: lastMove,
      lastMoveColor: color,
      blackToPlay: !data.blackToPlay,
      zobrist: zobrist.hash,
      moveNumber: moveNumber,
      moveNumberList: moveNumberList,
      blackCaptures: bc,
      whiteCaptures: wc,
      winrate: nextWinrate,
      scoreMean: nextScoreMean,
    );

    // Reject suicide or ko violation.
    if (isSuicidal > 0 || history.violatesKoRule(newState)) return false;

    // Commit to history.
    history.addOrGoto(newState, newBranch, changeMove);
    return true;
  }

  /// Place a stone alternating colors (auto-detect from board state).
  bool placeAuto(int x, int y, {bool newBranch = false, bool changeMove = false}) {
    return place(x, y, data.blackToPlay ? Stone.black : Stone.white,
        newBranch: newBranch, changeMove: changeMove);
  }

  // ---------------------------------------------------------------------------
  // Pass
  // ---------------------------------------------------------------------------

  bool _doPass(Stone color) {
    final stones = data.stones.toList(growable: false);
    final zobrist = _zobrist.clone();
    final moveNumber = data.moveNumber + 1;

    final newState = BoardData(
      width: width,
      height: height,
      stones: stones,
      lastMove: null,
      lastMoveColor: color,
      blackToPlay: !data.blackToPlay,
      zobrist: zobrist.hash,
      moveNumber: moveNumber,
      moveNumberList: List<int>.filled(stones.length, 0),
      blackCaptures: data.blackCaptures,
      whiteCaptures: data.whiteCaptures,
      winrate: 100.0 - data.winrate,
      scoreMean: -data.scoreMean,
    );

    history.addOrGoto(newState, false, false);
    return true;
  }

  /// Pass for the current player.
  bool pass() => _doPass(data.blackToPlay ? Stone.black : Stone.white);

  // ---------------------------------------------------------------------------
  // Handicap
  // ---------------------------------------------------------------------------

  /// Place handicap stones for `n` stones at standard star points.
  /// Clears the board first, places stones, then flattens history.
  void setHandicap(int n) {
    final placements = Handicap.placement(n, width);
    if (placements.isEmpty) return;

    // Clear and reset.
    _reset();

    final stones = data.stones.toList(growable: false);
    final zobrist = _zobrist.clone();

    for (final pos in placements) {
      final x = pos[0];
      final y = pos[1];
      final idx = indexOf(x, y);
      stones[idx] = Stone.black;
      zobrist.toggleStone(x, y, width, height, Stone.black);
    }

    // Replace history with a single flattened root node.
    final rootData = BoardData(
      width: width,
      height: height,
      stones: stones,
      lastMove: null,
      lastMoveColor: Stone.empty,
      blackToPlay: false, // white's turn after handicap
      zobrist: zobrist.hash,
      moveNumber: 0,
      moveNumberList: List<int>.filled(stones.length, 0),
      blackCaptures: 0,
      whiteCaptures: 0,
      winrate: 50.0,
    );
    history.replaceRoot(rootData);
  }

  void _reset() {
    _zobrist = Zobrist.init(width, height, 0);
    history.replaceRoot(BoardData.empty(width: width, height: height));
  }

  // ---------------------------------------------------------------------------
  // Setup stones (SGF AB/AW)
  // ---------------------------------------------------------------------------

  /// Place a setup stone at (x, y) without creating a new history node.
  /// Used for SGF AB/AW and handicap stones during SGF load.
  /// Mutates the current node in place.
  void setStone(int x, int y, Stone color) {
    if (!isValid(x, y)) return;
    final idx = indexOf(x, y);
    data.stones[idx] = color;
    _zobrist.toggleStone(x, y, width, height, color);
  }

  // ---------------------------------------------------------------------------
  // Scoring
  // ---------------------------------------------------------------------------

  /// Toggle a stone's dead/alive status for scoring.
  ///
  /// If the stone at (x, y) is a normal stone, marks it as dead
  /// (blackCaptured/whiteCaptured). If already marked dead, restores it.
  /// Mutates the current node's stones in place (no history entry).
  void toggleDeadStone(int x, int y) {
    if (!isValid(x, y)) return;
    final idx = indexOf(x, y);
    final s = data.stones[idx];
    if (s == Stone.blackCaptured) {
      data.stones[idx] = Stone.black;
    } else if (s == Stone.whiteCaptured) {
      data.stones[idx] = Stone.white;
    } else if (s == Stone.black) {
      data.stones[idx] = Stone.blackCaptured;
    } else if (s == Stone.white) {
      data.stones[idx] = Stone.whiteCaptured;
    }
  }

  /// Restore all dead-marked stones back to their original colors.
  void clearDeadStones() {
    for (int i = 0; i < data.stones.length; i++) {
      if (data.stones[i] == Stone.blackCaptured) {
        data.stones[i] = Stone.black;
      } else if (data.stones[i] == Stone.whiteCaptured) {
        data.stones[i] = Stone.white;
      }
    }
  }

  /// Check if a stone at [idx] is "alive" (not marked dead).
  static bool _isAlive(List<Stone> stones, int idx) {
    final s = stones[idx];
    return s == Stone.black || s == Stone.white;
  }

  /// Flood-fill from an empty intersection to find the connected empty region
  /// and determine its owner.
  ///
  /// Returns 0 = dame, 1 = black territory, 2 = white territory.
  /// Uses [visited] boolean list to avoid re-visiting.
  static int _floodFillTerritory(
      int x, int y, List<Stone> stones, List<bool> visited, int w, int h) {
    int result = 0; // bit 0 = black touch, bit 1 = white touch
    final queue = <List<int>>[[x, y]];
    visited[x * h + y] = true;

    while (queue.isNotEmpty) {
      final pos = queue.removeAt(0);
      final px = pos[0];
      final py = pos[1];

      for (final dir in [
        [1, 0], [-1, 0], [0, 1], [0, -1]
      ]) {
        final nx = px + dir[0];
        final ny = py + dir[1];
        if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;

        final nIdx = nx * h + ny;
        final s = stones[nIdx];

        if (s == Stone.empty && !visited[nIdx]) {
          visited[nIdx] = true;
          queue.add([nx, ny]);
        } else if (s == Stone.black && _isAlive(stones, nIdx)) {
          result |= 1;
        } else if (s == Stone.white && _isAlive(stones, nIdx)) {
          result |= 2;
        }
      }
    }
    return result;
  }

  /// Count territory for both colors.
  ///
  /// Returns a record (blackTerritory, whiteTerritory, dame).
  /// Dead stones are treated as captured (removed for territory counting).
  /// Uses Chinese (area) counting: empty intersections surrounded by alive stones.
  (int, int, int) countTerritory() {
    final w = width;
    final h = height;
    final stones = data.stones;
    final visited = List<bool>.filled(stones.length, false);

    int blackTerritory = 0;
    int whiteTerritory = 0;
    int dame = 0;

    for (int x = 0; x < w; x++) {
      for (int y = 0; y < h; y++) {
        final idx = indexOf(x, y);
        if (stones[idx] == Stone.empty && !visited[idx]) {
          // Count visited before flood-fill.
          final beforeCount = visited.where((v) => v).length;
          final result = _floodFillTerritory(x, y, stones, visited, w, h);
          final afterCount = visited.where((v) => v).length;
          final regionSize = afterCount - beforeCount;

          if (result == 1) {
            blackTerritory += regionSize;
          } else if (result == 2) {
            whiteTerritory += regionSize;
          } else {
            dame += regionSize;
          }
        }
      }
    }

    return (blackTerritory, whiteTerritory, dame);
  }

  /// Compute the score difference (black score - white score) using
  /// Chinese (area) scoring: territory + stones on board + komi.
  ///
  /// Dead stones are not counted as alive stones for area purposes.
  double computeScoreDifference({double komi = 6.5}) {
    final (blackTerritory, whiteTerritory, _) = countTerritory();

    // Count alive stones for each color.
    int blackStones = 0;
    int whiteStones = 0;
    for (final s in data.stones) {
      if (s == Stone.black) blackStones++;
      if (s == Stone.white) whiteStones++;
    }

    final blackScore = blackTerritory + blackStones;
    final whiteScore = whiteTerritory + whiteStones + komi;
    return blackScore - whiteScore;
  }

  // ---------------------------------------------------------------------------
  // Undo
  // ---------------------------------------------------------------------------

  bool undo() {
    if (!history.canGoBack) return false;
    history.previous();
    return true;
  }

  bool redo() {
    if (!history.canGoForward) return false;
    history.next();
    return true;
  }
}
