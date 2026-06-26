import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/analysis.dart';
import '../engine/engine.dart';
import '../engine/mock_engine.dart';
import '../engine/remote_engine.dart';
import '../go/stone.dart';
import 'engine_config_store.dart';

/// Riverpod [Notifier] that manages the engine lifecycle and analysis data.
///
/// By default uses [MockEngine] for offline development.
class EngineController extends Notifier<AsyncValue<EngineStatus>> {
  Engine? _engine;
  StreamSubscription<EngineStatus>? _statusSub;
  StreamSubscription<AnalysisResult>? _analysisSub;
  AnalysisResult? _lastAnalysis;

  @override
  AsyncValue<EngineStatus> build() {
    return const AsyncValue.data(Disconnected());
  }

  Engine? get engine => _engine;
  AnalysisResult? get lastAnalysis => _lastAnalysis;

  /// Start the engine with given configuration.
  /// Legacy method: uses host=='mock' to pick MockEngine.
  Future<void> start(EngineConfig config) async {
    final cfg = config.host == 'mock'
        ? const EngineConfigData(type: EngineType.mock, host: 'mock', port: 0)
        : EngineConfigData(type: EngineType.kataGo, host: config.host, port: config.port);
    await startWithType(cfg);
  }

  /// Start the engine with typed configuration.
  Future<void> startWithType(EngineConfigData cfg) async {
    _engine?.stop();

    final EngineConfig engineConfig;
    if (cfg.type == EngineType.mock) {
      _engine = MockEngine();
      engineConfig = const EngineConfig(host: 'mock', port: 0);
    } else {
      _engine = RemoteEngine();
      engineConfig = EngineConfig(host: cfg.host, port: cfg.port);
    }

    // Subscribe to status changes.
    _statusSub?.cancel();
    _statusSub = _engine!.status.listen((status) {
      state = AsyncValue.data(status);
      ref.notifyListeners();
    });

    // Subscribe to analysis.
    _analysisSub?.cancel();
    _analysisSub = _engine!.analysis.listen((analysis) {
      _lastAnalysis = analysis;
      ref.notifyListeners();
    });

    await _engine!.start(engineConfig);
  }

  /// Stop the engine.
  Future<void> stop() async {
    await _engine?.stop();
    _engine = null;
    _lastAnalysis = null;
    state = const AsyncValue.data(Disconnected());
  }

  /// Initialize a new game on the engine.
  Future<void> initGame(int boardSize, {double komi = 6.5, int handicap = 0}) async {
    await _engine?.initGame(boardSize, komi: komi, handicap: handicap);
  }

  /// Send a play command to the engine.
  Future<void> playMove(Stone color, String? coordinate) async {
    await _engine?.playMove(color, coordinate);
  }

  /// Start pondering (continuous analysis).
  Future<void> startPonder() async {
    await _engine?.startPonder();
  }

  /// Stop pondering.
  Future<void> stopPonder() async {
    await _engine?.stopPonder();
  }
}
