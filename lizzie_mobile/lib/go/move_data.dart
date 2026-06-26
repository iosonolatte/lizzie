/// Holds analysis data for a single move suggestion, parsed from
/// KataGo or Leela Zero GTP analysis output.
///
/// Ported from Lizzie's `MoveData.java`.
///
/// **Winrate normalization:** internally stored as 0-100, side-to-move
/// perspective. KataGo raw values (0-1) are ×100; Leela Zero raw values
/// (0-10000) are ÷100. Display code should flip to black's perspective
/// when `winRateAlwaysBlack && !blackToPlay`.
class MoveData {
  final String coordinate;
  final int playouts;
  final double winrate; // 0-100, side-to-move perspective
  final double scoreMean;
  final double scoreStdev;
  final double policy; // 0-100
  final double lcb; // 0-100 (lower confidence bound winrate)
  final double utility;
  final int order;
  final List<String> variation; // principal variation (GTP coords)

  const MoveData({
    required this.coordinate,
    this.playouts = 0,
    this.winrate = 0.0,
    this.scoreMean = 0.0,
    this.scoreStdev = 0.0,
    this.policy = 0.0,
    this.lcb = 0.0,
    this.utility = 0.0,
    this.order = 0,
    this.variation = const [],
  });

  // ---------------------------------------------------------------------------
  // KataGo "info" line parser
  // ---------------------------------------------------------------------------
  //
  // Format:
  //   info move Q5 visits 9 utility -0.145503 winrate 0.430823 scoreMean -1.88438
  //        scoreStdev 23.8437 prior 0.000681463 lcb 0.420129 order 15 pv Q5 D16 D4
  //
  // Ownership may be appended:
  //   ... ownership 0.1 -0.2 0.3 ...

  factory MoveData.fromInfoKatago(String line, {bool useLcbWinrate = false}) {
    final parts = line.trim().split(' ');
    String coord = '';
    int visits = 0;
    double winrate = 0.0;
    double scoreMean = 0.0;
    double scoreStdev = 0.0;
    double prior = 0.0;
    double lcb = 0.0;
    double utility = 0.0;
    int order = 0;
    final variation = <String>[];

    int i = 0;
    while (i < parts.length) {
      final key = parts[i];
      final next = i + 1 < parts.length ? parts[i + 1] : '';
      switch (key) {
        case 'move':
          coord = next;
          i += 2;
          break;
        case 'visits':
          visits = int.tryParse(next) ?? 0;
          i += 2;
          break;
        case 'winrate':
          winrate = (double.tryParse(next) ?? 0.0) * 100.0; // 0-1 → 0-100
          i += 2;
          break;
        case 'scoreMean':
          scoreMean = double.tryParse(next) ?? 0.0;
          i += 2;
          break;
        case 'scoreStdev':
          scoreStdev = double.tryParse(next) ?? 0.0;
          i += 2;
          break;
        case 'prior':
          prior = (double.tryParse(next) ?? 0.0) * 100.0; // 0-1 → 0-100
          i += 2;
          break;
        case 'lcb':
          lcb = (double.tryParse(next) ?? 0.0) * 100.0; // 0-1 → 0-100
          i += 2;
          break;
        case 'utility':
          utility = double.tryParse(next) ?? 0.0;
          i += 2;
          break;
        case 'order':
          order = int.tryParse(next) ?? 0;
          i += 2;
          break;
        case 'pv':
          i += 1;
          while (i < parts.length) {
            variation.add(parts[i]);
            i++;
          }
          break;
        case 'ownership':
          // Ownership values follow; we don't store them here.
          i = parts.length;
          break;
        default:
          i++;
          break;
      }
    }

    if (useLcbWinrate && lcb > 0) {
      winrate = lcb;
    }

    return MoveData(
      coordinate: coord,
      playouts: visits,
      winrate: winrate,
      scoreMean: scoreMean,
      scoreStdev: scoreStdev,
      policy: prior,
      lcb: lcb,
      utility: utility,
      order: order,
      variation: variation,
    );
  }

  // ---------------------------------------------------------------------------
  // Leela Zero "info" line parser
  // ---------------------------------------------------------------------------
  //
  // Format:
  //   info move R5 visits 38 winrate 5404 order 0 pv R5 Q5 R6 S4

  factory MoveData.fromInfo(String line, {bool useLcbWinrate = false}) {
    final parts = line.trim().split(' ');
    String coord = '';
    int visits = 0;
    double winrate = 0.0;
    double scoreMean = 0.0;
    double prior = 0.0;
    double lcb = 0.0;
    final variation = <String>[];

    int i = 0;
    while (i < parts.length) {
      final key = parts[i];
      final next = i + 1 < parts.length ? parts[i + 1] : '';
      switch (key) {
        case 'move':
          coord = next;
          i += 2;
          break;
        case 'visits':
          visits = int.tryParse(next) ?? 0;
          i += 2;
          break;
        case 'winrate':
          winrate = (int.tryParse(next) ?? 0) / 100.0; // 0-10000 → 0-100
          i += 2;
          break;
        case 'scoreMean':
          scoreMean = double.tryParse(next) ?? 0.0;
          i += 2;
          break;
        case 'prior':
          prior = (int.tryParse(next) ?? 0) / 100.0; // 0-10000 → 0-100
          i += 2;
          break;
        case 'lcb':
          lcb = (int.tryParse(next) ?? 0) / 100.0; // 0-10000 → 0-100
          i += 2;
          break;
        case 'pv':
          i += 1;
          while (i < parts.length) {
            variation.add(parts[i]);
            i++;
          }
          break;
        default:
          i++;
          break;
      }
    }

    if (useLcbWinrate && lcb > 0) {
      winrate = lcb;
    }

    return MoveData(
      coordinate: coord,
      playouts: visits,
      winrate: winrate,
      scoreMean: scoreMean,
      policy: prior,
      lcb: lcb,
      variation: variation,
    );
  }

  // ---------------------------------------------------------------------------
  // Summary line parser ("R5 -> 1234 visits, 45.6% winrate")
  // ---------------------------------------------------------------------------

  static MoveData? fromSummary(String line) {
    try {
      final parts = line.split(' -> ');
      if (parts.length < 2) return null;
      final coord = parts[0].trim();
      final rest = parts[1];
      final visitsMatch = RegExp(r'(\d+) visits?').firstMatch(rest);
      final winrateMatch = RegExp(r'([\d.]+)%').firstMatch(rest);
      return MoveData(
        coordinate: coord,
        playouts: int.tryParse(visitsMatch?.group(1) ?? '') ?? 0,
        winrate: double.tryParse(winrateMatch?.group(1) ?? '0') ?? 0.0,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Aggregate utilities
  // ---------------------------------------------------------------------------

  /// Total playouts across a list of moves.
  static int totalPlayouts(List<MoveData> moves) =>
      moves.fold(0, (sum, m) => sum + m.playouts);

  /// Playout-weighted average winrate.
  static double averageWinrate(List<MoveData> moves) {
    final total = totalPlayouts(moves);
    if (total == 0) return 0.0;
    return moves.fold(0.0, (sum, m) => sum + m.winrate * m.playouts) / total;
  }

  /// Playout-weighted average scoreMean.
  static double averageScoreMean(List<MoveData> moves) {
    final total = totalPlayouts(moves);
    if (total == 0) return 0.0;
    return moves.fold(0.0, (sum, m) => sum + m.scoreMean * m.playouts) / total;
  }

  @override
  String toString() =>
      'MoveData($coordinate: $playouts visits, ${winrate.toStringAsFixed(1)}%)';
}
