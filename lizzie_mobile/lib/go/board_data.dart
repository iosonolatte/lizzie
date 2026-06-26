import 'stone.dart';

/// Immutable snapshot of the board at one node in the move history tree.
///
/// Ported from Lizzie's `BoardData.java`.
class BoardData {
  final int width;
  final int height;

  /// Column-major flat array: index = x * height + y.
  final List<Stone> stones;

  /// [x, y] of last move, or null for pass / root.
  final List<int>? lastMove;

  /// Color of the last move played.
  final Stone lastMoveColor;

  /// True if it's Black's turn now.
  final bool blackToPlay;

  /// Incremental Zobrist hash of this position.
  final int zobrist;

  /// Move number (1-based).
  final int moveNumber;

  /// Per-cell display move number (0 = empty, otherwise move number).
  final List<int> moveNumberList;

  /// Stones captured BY black (i.e. black captured this many white stones).
  final int blackCaptures;

  /// Stones captured BY white.
  final int whiteCaptures;

  /// Current winrate (0-100, side-to-move perspective).
  final double winrate;

  /// Current total playouts across all suggested moves.
  final int playouts;

  /// Score mean from KataGo analysis.
  final double scoreMean;

  /// SGF MN property override (-1 means not set).
  final int moveMNNumber;

  /// Marker node (e.g. SGF AB[] passthrough placeholder).
  final bool dummy;

  /// SGF node properties (comments, labels, etc.).
  final Map<String, String> properties;

  /// Comment text for this node.
  String comment;

  BoardData({
    required this.width,
    required this.height,
    required this.stones,
    this.lastMove,
    required this.lastMoveColor,
    required this.blackToPlay,
    required this.zobrist,
    required this.moveNumber,
    required this.moveNumberList,
    this.blackCaptures = 0,
    this.whiteCaptures = 0,
    this.winrate = 50.0,
    this.playouts = 0,
    this.scoreMean = 0.0,
    this.moveMNNumber = -1,
    this.dummy = false,
    Map<String, String>? properties,
    this.comment = '',
  }) : properties = properties ?? {};

  factory BoardData.empty({int width = 19, int height = 19}) {
    final n = width * height;
    return BoardData(
      width: width,
      height: height,
      stones: List<Stone>.filled(n, Stone.empty),
      lastMove: null,
      lastMoveColor: Stone.empty,
      blackToPlay: true,
      zobrist: 0,
      moveNumber: 0,
      moveNumberList: List<int>.filled(n, 0),
    );
  }

  /// The number of intersections.
  int get size => width * height;

  int indexOf(int x, int y) => x * height + y;

  bool isValid(int x, int y) =>
      x >= 0 && x < width && y >= 0 && y < height;
}
