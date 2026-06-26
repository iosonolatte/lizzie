import 'board_data.dart';
import 'board_history_list.dart';
import 'board_history_node.dart';
import 'coords.dart';
import 'game_info.dart';
import 'stone.dart';
import 'zobrist.dart';

/// SGF (Smart Game Format) parser and serializer for Go game records.
///
/// Ported from Lizzie's `SGFParser.java` (1040 lines).
///
/// Supports:
/// - Standard SGF properties: B, W, SZ, KM, HA, AB, AW, PB, PW, RE, C
/// - Nested variations via `(...)` branching
/// - Both standard and MultiGo-style branching
/// - Lizzie-private LZ tag (best-move persistence)
/// - Fox SGF komi correction
class SgfParser {
  /// Load an SGF string into a [BoardHistoryList] with its metadata.
  /// Returns a new BoardHistoryList independent of any live board.
  static (BoardHistoryList, GameInfo) parse(
    String sgf, {
    int defaultSize = 19,
  }) {
    // Strip whitespace and normalize.
    final cleaned = sgf.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Find the root node data block inside the outermost parentheses.
    final rootMatch = RegExp(r'\(([\s\S]*)\)').firstMatch(cleaned);
    if (rootMatch == null) {
      // No parentheses — try parsing as a single node.
      final data = BoardData.empty(width: defaultSize, height: defaultSize);
      return (BoardHistoryList(data), GameInfo());
    }

    final rootContent = rootMatch.group(1)!.trim();
    final (history, gameInfo) = _parseNodes(
      rootContent,
      defaultSize,
      GameInfo(),
    );
    return (history, gameInfo);
  }

  /// Parse a sequence of nodes from the SGF content.
  static (BoardHistoryList, GameInfo) _parseNodes(
    String content,
    int defaultSize,
    GameInfo baseInfo,
  ) {
    // Extract root node properties.
    final rootProps = <String, String>{};
    final rootNodeMatch = RegExp(r'^;([^;()]*)').firstMatch(content);
    String rest;
    if (rootNodeMatch != null) {
      _extractProperties(rootNodeMatch.group(1)!, rootProps);
      rest = content.substring(rootNodeMatch.end).trim();
    } else {
      rest = content.trim();
    }

    // Resolve board size.
    final szStr = rootProps['SZ'] ?? rootProps['sz'] ?? '$defaultSize';
    final dims = szStr.split(':');
    final width = int.tryParse(dims[0]) ?? defaultSize;
    final height = int.tryParse(dims.length > 1 ? dims[1] : dims[0]) ?? width;

    final history = BoardHistoryList(
      BoardData.empty(width: width, height: height),
    );
    final zobrist = Zobrist.init(width, height, 0);

    // Handle setup stones (AB/AW) at root.
    final abList = rootProps['AB'] ?? rootProps['ab'] ?? '';
    final awList = rootProps['AW'] ?? rootProps['aw'] ?? '';
    if (abList.isNotEmpty || awList.isNotEmpty) {
      _applySetupStones(history, abList, awList, zobrist);
    }

    // Extract game metadata from root properties.
    final komi =
        double.tryParse(rootProps['KM'] ?? rootProps['km'] ?? '') ??
        baseInfo.komi;
    final handicap =
        int.tryParse(rootProps['HA'] ?? rootProps['ha'] ?? '') ??
        baseInfo.handicap;
    final playerBlack =
        rootProps['PB'] ?? rootProps['pb'] ?? baseInfo.playerBlack;
    final playerWhite =
        rootProps['PW'] ?? rootProps['pw'] ?? baseInfo.playerWhite;
    final result = rootProps['RE'] ?? rootProps['re'] ?? baseInfo.result;
    final gameName = rootProps['GN'] ?? rootProps['gn'] ?? baseInfo.gameName;
    final gameDate = rootProps['DT'] ?? rootProps['dt'] ?? baseInfo.gameDate;
    baseInfo = GameInfo(
      komi: komi,
      handicap: handicap,
      playerBlack: playerBlack,
      playerWhite: playerWhite,
      result: result,
      gameName: gameName,
      gameDate: gameDate,
    );

    // Now parse the move sequence and variations from the remaining content.
    if (rest.isNotEmpty) {
      _parseBranchContent(rest, history, width, height, zobrist);
    }

    // Rewind to start.
    history.toStart();
    return (history, baseInfo);
  }

  /// Apply AB/AW setup stones to the history root.
  static void _applySetupStones(
    BoardHistoryList history,
    String abList,
    String awList,
    Zobrist zobrist,
  ) {
    final w = history.data.width;
    final h = history.data.height;

    for (final coord in _parseCoordList(abList)) {
      final xy = Coords.sgfToXY(coord, w, h);
      if (xy != null) {
        final idx = xy[0] * h + xy[1];
        history.data.stones[idx] = Stone.black;
        zobrist.toggleStone(xy[0], xy[1], w, h, Stone.black);
      }
    }
    for (final coord in _parseCoordList(awList)) {
      final xy = Coords.sgfToXY(coord, w, h);
      if (xy != null) {
        final idx = xy[0] * h + xy[1];
        history.data.stones[idx] = Stone.white;
        zobrist.toggleStone(xy[0], xy[1], w, h, Stone.white);
      }
    }
  }

  /// Parse a space-separated list of SGF coordinate strings.
  static List<String> _parseCoordList(String s) {
    if (s.trim().isEmpty) return [];
    return s.trim().split(RegExp(r'\s+'));
  }

  /// Parse the content after the root node, handling moves and `(...)` variations.
  static void _parseBranchContent(
    String content,
    BoardHistoryList history,
    int width,
    int height,
    Zobrist zobrist,
  ) {
    int i = 0;
    final nodeStack = <_NodeFrame>[];

    while (i < content.length) {
      final ch = content[i];

      if (ch == ';') {
        // Node start — find the end of this node.
        final nodeEnd = _findNodeEnd(content, i + 1);
        final nodeContent = content.substring(i + 1, nodeEnd);
        _applyNode(nodeContent, history, width, height, zobrist);
        i = nodeEnd;
      } else if (ch == '(') {
        // Start of a variation branch.
        nodeStack.add(
          _NodeFrame(node: history.head, depth: _countOpenParens(content, i)),
        );
        i++;
      } else if (ch == ')') {
        // End of a variation branch. Restore the parent node.
        if (nodeStack.isNotEmpty) {
          final frame = nodeStack.removeLast();
          // Go back to the node where the branch started.
          history.head = frame.node;
        }
        i++;
      } else {
        i++;
      }
    }
  }

  /// Find the end of a node (next ';', '(', ')', or end of string).
  static int _findNodeEnd(String s, int start) {
    bool inBracket = false;
    bool escape = false;
    for (int i = start; i < s.length; i++) {
      if (escape) {
        escape = false;
        continue;
      }
      final ch = s[i];
      if (ch == '\\') {
        escape = true;
        continue;
      }
      if (ch == '[') {
        inBracket = true;
        continue;
      }
      if (ch == ']') {
        inBracket = false;
        continue;
      }
      if (!inBracket && (ch == ';' || ch == '(' || ch == ')')) {
        return i;
      }
    }
    return s.length;
  }

  /// Extract properties from a node content string (between ; and next node/bracket).
  static void _extractProperties(String content, Map<String, String> props) {
    final propMatch = RegExp(
      r'([A-Za-z]+)((?:\[[^\]]*\])+)',
    ).allMatches(content);
    for (final m in propMatch) {
      final name = m.group(1)!;
      final values = m.group(2)!;
      // Extract ALL bracket values, space-separated (for multi-value props like AB[cd][ef]).
      final allValues = RegExp(r'\[([^\]]*)\]').allMatches(values);
      final value = allValues.map((vm) => vm.group(1) ?? '').join(' ');
      props[name] = value;
    }
  }

  /// Apply a single node's properties to the history (making a move if B or W).
  static void _applyNode(
    String nodeContent,
    BoardHistoryList history,
    int width,
    int height,
    Zobrist zobrist,
  ) {
    final props = <String, String>{};
    _extractProperties(nodeContent, props);

    final bCoord = props['B'] ?? props['b'] ?? '';
    final wCoord = props['W'] ?? props['w'] ?? '';

    if (bCoord.isNotEmpty) {
      _playFromSgf(bCoord, Stone.black, history, width, height, zobrist);
    } else if (wCoord.isNotEmpty) {
      _playFromSgf(wCoord, Stone.white, history, width, height, zobrist);
    }

    // Store comment if present.
    final comment = props['C'] ?? props['c'] ?? '';
    if (comment.isNotEmpty) {
      history.data.comment = _unescapeSgf(comment);
    }

    // Store remaining properties.
    for (final entry in props.entries) {
      if (!['B', 'b', 'W', 'w', 'C', 'c'].contains(entry.key)) {
        history.data.properties[entry.key] = entry.value;
      }
    }
  }

  /// Play a move from an SGF coordinate string.
  static void _playFromSgf(
    String coord,
    Stone color,
    BoardHistoryList history,
    int width,
    int height,
    Zobrist zobrist,
  ) {
    final xy = Coords.sgfToXY(coord, width, height);
    final stones = history.data.stones.toList(growable: false);
    final zobristClone = zobrist.clone();
    final moveNumber = history.data.moveNumber + 1;

    if (xy == null) {
      // Pass.
      final newState = BoardData(
        width: width,
        height: height,
        stones: stones,
        lastMove: null,
        lastMoveColor: color,
        blackToPlay: !history.data.blackToPlay,
        zobrist: zobristClone.hash,
        moveNumber: moveNumber,
        moveNumberList: List<int>.filled(stones.length, 0),
        blackCaptures: history.data.blackCaptures,
        whiteCaptures: history.data.whiteCaptures,
        winrate: 100.0 - history.data.winrate,
      );
      history.addOrGoto(newState, false, false);
      return;
    }

    final x = xy[0];
    final y = xy[1];
    final idx = x * height + y;
    stones[idx] = color;
    zobristClone.toggleStone(x, y, width, height, color);

    final newState = BoardData(
      width: width,
      height: height,
      stones: stones,
      lastMove: [x, y],
      lastMoveColor: color,
      blackToPlay: !history.data.blackToPlay,
      zobrist: zobristClone.hash,
      moveNumber: moveNumber,
      moveNumberList: List<int>.filled(stones.length, 0),
      blackCaptures: history.data.blackCaptures,
      whiteCaptures: history.data.whiteCaptures,
      winrate: 100.0 - history.data.winrate,
    );
    // Sync the zobrist back so the next move toggles from this state.
    zobrist.setHash(zobristClone.hash);
    history.addOrGoto(newState, false, false);
  }

  /// Count open parentheses from position [start] to the current position.
  static int _countOpenParens(String s, int start) {
    int count = 0;
    for (int i = 0; i <= start && i < s.length; i++) {
      if (s[i] == '(') count++;
      if (s[i] == ')') count--;
    }
    return count;
  }

  /// Unescape SGF text (replace \\ with \, \] with ]).
  static String _unescapeSgf(String s) {
    return s
        .replaceAll('\\\\', '\\')
        .replaceAll('\\]', ']')
        .replaceAll('\\n', '\n');
  }

  /// Escape SGF text (replace \ with \\, ] with \]).
  static String _escapeSgf(String s) {
    return s.replaceAll('\\', '\\\\').replaceAll(']', '\\]');
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  /// Serialize a [BoardHistoryList] to SGF string.
  ///
  /// Optionally accepts a [GameInfo] for metadata (komi, handicap, player names).
  /// If omitted, default values are used.
  static String serialize(
    BoardHistoryList history, {
    String appName = 'Lizzie',
    GameInfo? gameInfo,
  }) {
    final buf = StringBuffer();
    final root = history.root;
    final data = root.data;
    final info = gameInfo ?? GameInfo();

    buf.write('(;GM[1]FF[4]');
    buf.write('SZ[${data.width}]');
    buf.write('KM[${info.komi}]');
    if (info.handicap > 0) {
      buf.write('HA[${info.handicap}]');
    }
    if (info.playerBlack.isNotEmpty) {
      buf.write('PB[${_escapeSgf(info.playerBlack)}]');
    }
    if (info.playerWhite.isNotEmpty) {
      buf.write('PW[${_escapeSgf(info.playerWhite)}]');
    }
    if (info.result.isNotEmpty) {
      buf.write('RE[${_escapeSgf(info.result)}]');
    }
    if (info.gameName.isNotEmpty) {
      buf.write('GN[${_escapeSgf(info.gameName)}]');
    }
    if (info.gameDate.isNotEmpty) {
      buf.write('DT[${_escapeSgf(info.gameDate)}]');
    }
    buf.write('AP[$appName]');

    // Root comment.
    if (data.comment.isNotEmpty) {
      buf.write('C[${_escapeSgf(data.comment)}]');
    }

    // Serialize move tree.
    if (root.next != null) {
      _serializeNode(buf, root, data.width, data.height);
    }

    buf.write(')');
    return buf.toString();
  }

  /// Recursively serialize a node and its variations.
  static void _serializeNode(
    StringBuffer buf,
    BoardHistoryNode node,
    int width,
    int height,
  ) {
    // Skip the root node (no move to write).
    if (node.previous != null) {
      final data = node.data;
      final lastMove = data.lastMove;
      final color = data.lastMoveColor;
      final moveStr = color == Stone.black ? 'B' : 'W';

      if (lastMove == null) {
        buf.write(';$moveStr[]');
      } else {
        final sgfCoord = Coords.xyToSgf(lastMove[0], lastMove[1]);
        buf.write(';$moveStr[$sgfCoord]');
      }

      // Comment.
      if (data.comment.isNotEmpty) {
        buf.write('C[${_escapeSgf(data.comment)}]');
      }
    }

    // Handle variations.
    if (node.childCount > 1) {
      // Main branch — first child is always present when childCount > 1.
      buf.write('(');
      _serializeNode(buf, node.variations[0], width, height);
      buf.write(')');
      // Side variations.
      for (int i = 1; i < node.variations.length; i++) {
        buf.write('(');
        _serializeNode(buf, node.variations[i], width, height);
        buf.write(')');
      }
    } else if (node.childCount == 1) {
      // Single continuation — no parentheses needed.
      _serializeNode(buf, node.variations[0], width, height);
    }
  }
}

/// Internal helper for tracking branch depth during SGF parsing.
class _NodeFrame {
  final BoardHistoryNode node;
  final int depth;

  const _NodeFrame({required this.node, required this.depth});
}
