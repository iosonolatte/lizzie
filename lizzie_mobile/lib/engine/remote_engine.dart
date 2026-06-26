import 'dart:async';
import '../go/move_data.dart';
import '../go/stone.dart';
import 'analysis.dart';
import 'engine.dart';
import 'gtp_client.dart';

/// Engine implementation that talks to a remote KataGo/Leela Zero over TCP.
///
/// Ported from Lizzie's `Leelaz.java` with the correct framing, command
/// correlation, and analyze/pause semantics.
class RemoteEngine implements Engine {
  GtpClient? _client;
  bool _isPondering = false;
  bool _isKataGo = false;
  StreamSubscription<String>? _lineSub;
  int _boardWidth = 19;
  int _boardHeight = 19;

  // Status/analysis streams (broadcast so multiple listeners can observe).
  final _statusController = StreamController<EngineStatus>.broadcast();
  @override
  Stream<EngineStatus> get status => _statusController.stream;

  final _analysisController = StreamController<AnalysisResult>.broadcast();
  @override
  Stream<AnalysisResult> get analysis => _analysisController.stream;

  @override
  bool get isPondering => _isPondering;

  @override
  Future<void> start(EngineConfig config) async {
    _statusController.add(Connecting('Connecting to ${config.host}:${config.port}...'));
    _isPondering = false;

    try {
      _client = GtpClient();
      await _client!.connect(config.host, config.port);

      // Subscribe to raw lines for info/ownership parsing.
      _lineSub = _client!.lines.listen(_handleLine);

      // Handshake: name + version.
      final nameResponse = await _client!.send('name');
      _isKataGo = nameResponse.startsWith('KataGo');

      final versionResponse = await _client!.send('version');
      final version = versionResponse.trim();

      _statusController.add(Ready(nameResponse.trim(), version, _isKataGo));
    } catch (e) {
      _statusController.add(EngineError('Failed to connect: $e'));
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _isPondering = false;
    try {
      await _client?.send('quit');
    } catch (_) {}
    await _lineSub?.cancel();
    await _client?.disconnect();
    _client = null;
    _statusController.add(const Disconnected());
  }

  @override
  Future<void> initGame(int boardSize, {double komi = 6.5, int handicap = 0}) async {
    _boardWidth = boardSize;
    _boardHeight = boardSize;
    await _client!.send('boardsize $boardSize');
    await _client!.send('clear_board');
    await _client!.send('komi $komi');
    if (handicap > 0) {
      final response = await _client!.send('fixed_handicap $handicap');
      // Parse returned vertex list and place stones locally.
      // Format: "=N D4 Q16 ..." or "=N D4 D16 ..."
      _parseHandicapResponse(response);
    }
  }

  @override
  Future<void> playMove(Stone color, String? coordinate) async {
    final colorStr = color == Stone.black ? 'B' : 'W';
    final coord = coordinate ?? 'pass';
    await _client!.send('play $colorStr $coord');
  }

  @override
  Future<void> undoMove() async {
    await _client!.send('undo');
  }

  @override
  Future<void> startPonder() async {
    if (_isPondering) return;
    _isPondering = true;
    if (_isKataGo) {
      await _client!.send('kata-analyze 10 ownership true');
    } else {
      await _client!.send('lz-analyze 10');
    }
  }

  @override
  Future<void> stopPonder() async {
    if (!_isPondering) return;
    _isPondering = false;
    // Send any command to interrupt the running analyze.
    // The engine will emit the final =NNN for the analyze, then respond
    // to this command. We send 'name' as the interrupt.
    try {
      await _client!.send('name');
    } catch (_) {
      // Engine might be gone; that's OK.
    }
  }

  @override
  Future<String> sendGtpCommand(String command) async {
    return await _client!.send(command);
  }

  // ---------------------------------------------------------------------------
  // Line handler
  // ---------------------------------------------------------------------------

  void _handleLine(String line) {
    if (line.startsWith('info')) {
      _handleInfo(line.substring(5));
    }
    // "=..." and "?..." lines are consumed by GtpClient for command correlation,
    // so they don't reach here (the broadcast stream gets them, but we ignore
    // them in the engine logic).
  }

  void _handleInfo(String body) {
    List<MoveData> moves;
    List<double>? ownership;

    // Check for ownership data.
    final ownershipIdx = body.indexOf('ownership');
    if (ownershipIdx >= 0) {
      final ownershipStr = body.substring(ownershipIdx + 'ownership'.length).trim();
      ownership = ownershipStr
          .split(' ')
          .where((s) => s.isNotEmpty)
          .map((s) => double.tryParse(s) ?? 0.0)
          .toList();
      // Trim ownership to board size.
      final expectedLen = _boardWidth * _boardHeight;
      if (ownership.length > expectedLen) {
        ownership = ownership.sublist(0, expectedLen);
      }
    }

    if (_isKataGo) {
      moves = body.split(' info ').map((part) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) return null;
        try {
          return MoveData.fromInfoKatago(trimmed);
        } catch (_) {
          return null;
        }
      }).whereType<MoveData>().toList();
    } else {
      moves = body.split(' info ').map((part) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) return null;
        try {
          return MoveData.fromInfo(trimmed);
        } catch (_) {
          return null;
        }
      }).whereType<MoveData>().toList();
    }

    _analysisController.add(AnalysisResult(
      bestMoves: moves,
      ownership: ownership,
      scoreMean: moves.isNotEmpty ? moves.first.scoreMean : 0.0,
      scoreStdev: moves.isNotEmpty ? moves.first.scoreStdev : 0.0,
      currentPlayouts: MoveData.totalPlayouts(moves),
    ));
  }

  void _parseHandicapResponse(String response) {
    // Format: " D4 Q16 ..." (space-separated GTP coordinates)
    // The response comes back as GTP coordinates; we don't need to
    // place them locally (the engine tracks them). This is just for
    // local board sync if needed.
  }
}
