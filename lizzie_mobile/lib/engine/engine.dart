import 'dart:async';
import '../go/stone.dart';
import 'analysis.dart';

/// Configuration for connecting to a remote GTP engine.
class EngineConfig {
  final String host;
  final int port;
  final bool useTls;

  const EngineConfig({
    required this.host,
    required this.port,
    this.useTls = false,
  });
}

/// Core engine interface for Go analysis over GTP.
///
/// Implementations: [RemoteEngine] and [MockEngine].
abstract class Engine {
  /// Engine connection status stream.
  Stream<EngineStatus> get status;

  /// Analysis results stream — emits every time the engine updates.
  Stream<AnalysisResult> get analysis;

  /// Whether the engine is currently pondering.
  bool get isPondering;

  /// Start the engine with given configuration.
  Future<void> start(EngineConfig config);

  /// Gracefully stop the engine.
  Future<void> stop();

  /// Initialize a new game (board size, komi, handicap).
  ///
  /// Returns the list of GTP coordinate strings for any handicap stones placed
  /// by the engine (e.g. `['D4', 'Q16', 'D16']`). Returns an empty list when
  /// [handicap] is 0 or the engine places no stones.
  /// The caller is responsible for applying these coordinates to the local board.
  Future<List<String>> initGame(int boardSize, {double komi = 6.5, int handicap = 0});

  /// Play a move on the engine's internal board.
  Future<void> playMove(Stone color, String? coordinate);

  /// Undo the last move on the engine's internal board.
  Future<void> undoMove();

  /// Start pondering (continuous analysis) on current position.
  Future<void> startPonder();

  /// Stop pondering.
  Future<void> stopPonder();

  /// Send a raw GTP command and get the response.
  Future<String> sendGtpCommand(String command);
}
