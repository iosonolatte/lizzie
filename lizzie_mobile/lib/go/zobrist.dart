import 'stone.dart';

/// Incremental XOR-based Zobrist hash for Go positions.
///
/// Only BLACK and WHITE stones contribute to the hash.
/// Ported from Lizzie's `Zobrist.java`.
class Zobrist {
  late final List<int> _blackZobrist;
  late final List<int> _whiteZobrist;
  int _zhash = 0;

  Zobrist._(this._blackZobrist, this._whiteZobrist, this._zhash);

  /// Creates a fresh instance with randomly seeded tables.
  /// `width` and `height` are board dimensions (column-major index =
  /// x * height + y).
  Zobrist.init(int width, int height, [int seed = 0]) {
    // Use a seeded random for deterministic tests.
    final rng = _SeededRandom(seed);
    final n = width * height;
    _blackZobrist = List<int>.generate(n, (_) => rng.next());
    _whiteZobrist = List<int>.generate(n, (_) => rng.next());
    _zhash = 0;
  }

  Zobrist clone() => Zobrist._(_blackZobrist, _whiteZobrist, _zhash);

  int get hash => _zhash;

  /// Set the hash directly (used by SGF parser for sync).
  void setHash(int value) => _zhash = value;

  /// Toggle the stone at (x, y). Only BLACK and WHITE change the hash.
  void toggleStone(int x, int y, int width, int height, Stone color) {
    final idx = x * height + y;
    switch (color) {
      case Stone.black:
        _zhash ^= _blackZobrist[idx];
      case Stone.white:
        _zhash ^= _whiteZobrist[idx];
      default:
        break; // EMPTY, ghosts, etc. contribute nothing
    }
  }

  @override
  bool operator ==(Object other) => other is Zobrist && _zhash == other._zhash;

  @override
  int get hashCode => _zhash;

  @override
  String toString() => 'Zobrist(${_zhash.toRadixString(16)})';
}

/// Minimal seeded pseudo-random number generator that matches the Java
/// `Random.nextLong()` convention (64-bit output from a 48-bit seed).
class _SeededRandom {
  int _seed;

  _SeededRandom(int seed) : _seed = (seed ^ 0x5DEECE66D) & ((1 << 48) - 1);

  int next() {
    _seed = (_seed * 0x5DEECE66D + 0xB) & ((1 << 48) - 1);
    // Java's nextLong() returns two next(32) calls combined.
    final high = (_seed >> 16) & 0xFFFFFFFF;
    _seed = (_seed * 0x5DEECE66D + 0xB) & ((1 << 48) - 1);
    final low = (_seed >> 16) & 0xFFFFFFFF;
    return (high << 32) | low;
  }
}
