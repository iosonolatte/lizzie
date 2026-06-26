import '../go/move_data.dart';

/// Full analysis result from the engine.
class AnalysisResult {
  final List<MoveData> bestMoves;
  final List<double>?
  ownership; // board-width × board-height, signed (positive = black)
  final double scoreMean;
  final double scoreStdev;
  final int currentPlayouts;

  const AnalysisResult({
    required this.bestMoves,
    this.ownership,
    this.scoreMean = 0.0,
    this.scoreStdev = 0.0,
    this.currentPlayouts = 0,
  });
}

/// Engine connection status.
sealed class EngineStatus {
  const EngineStatus();
}

class Disconnected extends EngineStatus {
  const Disconnected();
}

class Connecting extends EngineStatus {
  final String info;
  const Connecting(this.info);
}

class Ready extends EngineStatus {
  final String engineName;
  final String version;
  final bool isKataGo;
  const Ready(this.engineName, this.version, this.isKataGo);
}

class EngineError extends EngineStatus {
  final String message;
  const EngineError(this.message);
}
