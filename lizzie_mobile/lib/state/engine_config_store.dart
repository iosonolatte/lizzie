import 'package:shared_preferences/shared_preferences.dart';

/// Type of Go analysis engine.
enum EngineType { mock, kataGo, leelaZero }

/// Holds all configuration data for connecting to an engine.
class EngineConfigData {
  final EngineType type;
  final String host;
  final int port;

  const EngineConfigData({
    required this.type,
    required this.host,
    required this.port,
  });

  EngineConfigData copyWith({EngineType? type, String? host, int? port}) {
    return EngineConfigData(
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }
}

/// Persistence layer for engine configuration using `shared_preferences`.
///
/// Stores/loads the selected engine type, host, and port across app restarts.
class EngineConfigStore {
  static const _kType = 'engine.type';
  static const _kHost = 'engine.host';
  static const _kPort = 'engine.port';

  /// Load the last-saved configuration, or return defaults.
  Future<EngineConfigData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final typeIdx = prefs.getInt(_kType) ?? 0; // mock by default
    // Clamp to valid range
    final type =
        EngineType.values[typeIdx.clamp(0, EngineType.values.length - 1)];
    return EngineConfigData(
      type: type,
      host: prefs.getString(_kHost) ?? '127.0.0.1',
      port: prefs.getInt(_kPort) ?? 7878,
    );
  }

  /// Save the configuration to disk.
  Future<void> save(EngineConfigData cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kType, cfg.type.index);
    await prefs.setString(_kHost, cfg.host);
    await prefs.setInt(_kPort, cfg.port);
  }
}
