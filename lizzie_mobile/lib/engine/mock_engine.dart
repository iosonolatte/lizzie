import 'dart:async';
import '../go/move_data.dart';
import '../go/stone.dart';
import 'analysis.dart';
import 'engine.dart';

/// Deterministic mock engine for offline development and testing.
///
/// Replays a canned set of analysis results without connecting to a
/// real GTP server. Makes the entire UI testable without a network.
class MockEngine implements Engine {
  final _statusController = StreamController<EngineStatus>.broadcast();
  @override
  Stream<EngineStatus> get status => _statusController.stream;

  final _analysisController = StreamController<AnalysisResult>.broadcast();
  @override
  Stream<AnalysisResult> get analysis => _analysisController.stream;

  @override
  bool get isPondering => _timer != null;

  Timer? _timer;
  int _tick = 0;

  // Canned best moves for 19x19 board at empty position.
  static const _cannedMoves = [
    ['Q16', 'D4', 'D16', 'Q4', 'C3', 'C15', 'R3', 'R15', 'K10'],
    ['D4', 'Q16', 'D16', 'Q4', 'C3', 'R3', 'C15', 'R15', 'K3'],
    ['Q16', 'D4', 'D16', 'Q4', 'R3', 'C15', 'C3', 'R15', 'K10'],
  ];

  static const _cannedWinrates = [43.0, 42.5, 41.0, 40.0, 38.0, 37.0, 36.0, 35.0, 34.0];
  static const _cannedPlayouts = [500, 320, 280, 150, 90, 60, 40, 30, 20];

  @override
  Future<void> start(EngineConfig config) async {
    _statusController.add(const Connecting('Mock engine starting...'));
    await Future.delayed(const Duration(milliseconds: 200));
    _statusController.add(const Ready('MockEngine', '1.0.0', true));
  }

  @override
  Future<void> stop() async {
    stopPonder();
    _statusController.add(const Disconnected());
  }

  @override
  Future<void> initGame(int boardSize, {double komi = 6.5, int handicap = 0}) async {
    // No-op for mock.
  }

  @override
  Future<void> playMove(Stone color, String? coordinate) async {
    // No-op for mock.
  }

  @override
  Future<void> undoMove() async {
    // No-op for mock.
  }

  @override
  Future<void> startPonder() async {
    stopPonder();
    _tick = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _emitAnalysis();
      _tick = (_tick + 1) % _cannedMoves.length;
    });
  }

  @override
  Future<void> stopPonder() async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<String> sendGtpCommand(String command) async {
    return '';
  }

  void _emitAnalysis() {
    final moves = _cannedMoves[_tick];
    final winrates = _cannedWinrates;
    final playouts = _cannedPlayouts;

    final moveData = List<MoveData>.generate(moves.length, (i) {
      return MoveData(
        coordinate: moves[i],
        playouts: playouts[i],
        winrate: winrates[i],
        scoreMean: winrates[i] - 50.0,
        scoreStdev: 25.0,
        lcb: winrates[i] - 2.0,
        order: i,
        variation: [moves[i], moves[(i + 1) % moves.length], moves[(i + 2) % moves.length]],
      );
    });

    _analysisController.add(AnalysisResult(
      bestMoves: moveData,
      scoreMean: moveData.isNotEmpty ? moveData.first.scoreMean : 0.0,
      scoreStdev: 25.0,
      currentPlayouts: moveData.fold(0, (sum, m) => sum + m.playouts),
    ));
  }
}
