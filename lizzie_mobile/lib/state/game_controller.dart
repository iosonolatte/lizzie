import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../go/board.dart';
import '../go/board_history_list.dart';
import '../go/game_info.dart';
import '../go/sgf_parser.dart';

/// Riverpod [Notifier] that manages the Go board state.
///
/// Wraps the pure [Board] engine with Riverpod reactivity.
/// Also holds [GameInfo] metadata for the current game.
/// Listens to [NotifierRef] for rebuilds on state change.
class GameController extends Notifier<Board> {
  GameInfo _gameInfo = GameInfo();
  bool _scoringMode = false;

  /// The game metadata (komi, handicap, player names, etc.).
  GameInfo get gameInfo => _gameInfo;

  /// Whether scoring mode is currently active.
  bool get scoringMode => _scoringMode;

  @override
  Board build() {
    return Board(width: 19, height: 19);
  }

  /// Play a move at a GTP coordinate (e.g. "C16" or "pass").
  /// Returns true if the move was accepted.
  bool play(String coord) {
    final result = state.play(coord);
    if (result) ref.notifyListeners();
    return result;
  }

  /// Place a stone at (x, y) for the current player.
  /// In scoring mode, toggles the dead/alive status of the stone instead.
  bool place(int x, int y) {
    if (_scoringMode) {
      state.toggleDeadStone(x, y);
      ref.notifyListeners();
      return true;
    }
    final result = state.placeAuto(x, y);
    if (result) ref.notifyListeners();
    return result;
  }

  /// Pass for the current player.
  bool pass() {
    final result = state.pass();
    if (result) ref.notifyListeners();
    return result;
  }

  /// Undo the last move.
  bool undo() {
    final result = state.undo();
    if (result) ref.notifyListeners();
    return result;
  }

  /// Redo a previously undone move.
  bool redo() {
    final result = state.redo();
    if (result) ref.notifyListeners();
    return result;
  }

  /// Navigate to the previous node in history.
  bool previous() {
    if (!state.history.canGoBack) return false;
    state.history.previous();
    ref.notifyListeners();
    return true;
  }

  /// Navigate to the next node in history.
  bool next() {
    if (!state.history.canGoForward) return false;
    state.history.next();
    ref.notifyListeners();
    return true;
  }

  /// Go to the start of the game.
  void toStart() {
    state.history.toStart();
    ref.notifyListeners();
  }

  /// Go to the end of the game.
  void toEnd() {
    state.history.toEnd();
    ref.notifyListeners();
  }

  /// Set a new board size (resets the game).
  void setBoardSize(int size) {
    state = Board(width: size, height: size);
    ref.notifyListeners();
  }

  /// Set handicap stones.
  void setHandicap(int n) {
    state.setHandicap(n);
    ref.notifyListeners();
  }

  /// Start a new game with the given parameters.
  ///
  /// Resets the board, sets [size], [komi], and optional [handicap].
  void newGame(int size, {double komi = 6.5, int handicap = 0}) {
    state = Board(width: size, height: size);
    if (handicap > 0) {
      state.setHandicap(handicap);
    }
    _gameInfo = GameInfo(komi: komi, handicap: handicap);
    ref.notifyListeners();
  }

  /// Serialize the current game to an SGF string.
  String toSgf() {
    return SgfParser.serialize(state.history, gameInfo: _gameInfo);
  }

  /// Toggle scoring mode on/off.
  ///
  /// When entering scoring mode, clears any existing dead-stone markings
  /// and notifies listeners. When exiting, notifies listeners so the UI
  /// can show the scoring result.
  void toggleScoringMode() {
    _scoringMode = !_scoringMode;
    if (_scoringMode) {
      state.clearDeadStones();
    }
    ref.notifyListeners();
  }

  /// Set the comment on the current board position.
  ///
  /// Mutates the current node's comment in place (no history entry created).
  void setComment(String comment) {
    state.data.comment = comment;
    ref.notifyListeners();
  }

  /// Replace the game metadata (player names, result, etc.).
  void updateGameInfo(GameInfo info) {
    _gameInfo = info;
    ref.notifyListeners();
  }

  /// Load SGF data into the board.
  ///
  /// Replaces the current board state with the parsed SGF history tree.
  /// Walks the parsed history trunk and replays each move to maintain
  /// consistent internal zobrist hashing and board state.
  /// Optionally accepts [gameInfo] to carry over metadata from the SGF.
  void loadSgf(BoardHistoryList parsedHistory, {GameInfo? gameInfo}) {
    final newBoard = Board(
      width: parsedHistory.data.width,
      height: parsedHistory.data.height,
    );

    // Walk the trunk from root onward, replaying moves.
    final trunkNodes = parsedHistory.trunkFromRoot;
    // Skip root (index 0) — it has moveNumber 0 and no lastMove.
    for (int i = 1; i < trunkNodes.length; i++) {
      final node = trunkNodes[i];
      final d = node.data;
      if (d.lastMove != null) {
        newBoard.place(
          d.lastMove![0],
          d.lastMove![1],
          d.lastMoveColor,
        );
      } else {
        // Pass.
        newBoard.pass();
      }
    }

    state = newBoard;
    if (gameInfo != null) {
      _gameInfo = gameInfo;
    }
    ref.notifyListeners();
  }
}
