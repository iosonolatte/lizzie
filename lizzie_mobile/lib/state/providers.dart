import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/analysis.dart';
import '../go/board.dart';
import 'engine_config_store.dart';
import 'game_controller.dart';
import 'engine_controller.dart';

/// The main game board state.
final gameProvider = NotifierProvider<GameController, Board>(
  GameController.new,
);

/// The engine connection and analysis state.
final engineProvider = NotifierProvider<EngineController, AsyncValue<EngineStatus>>(
  EngineController.new,
);

/// Engine configuration persistence store.
final engineConfigStoreProvider = Provider<EngineConfigStore>((ref) {
  return EngineConfigStore();
});

/// Load the last-saved engine configuration from disk.
final savedEngineConfigProvider = FutureProvider<EngineConfigData>((ref) async {
  final store = ref.read(engineConfigStoreProvider);
  return await store.load();
});
