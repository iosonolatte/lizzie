/// Game-level metadata (komi, handicap, player names).
///
/// Ported from Lizzie's `GameInfo.java`.
class GameInfo {
  final double komi;
  final int handicap;
  final String playerBlack;
  final String playerWhite;
  final String gameName;
  final String gameDate;
  final String result;

  const GameInfo({
    this.komi = 7.5,
    this.handicap = 0,
    this.playerBlack = '',
    this.playerWhite = '',
    this.gameName = '',
    this.gameDate = '',
    this.result = '',
  });

  GameInfo copyWith({
    double? komi,
    int? handicap,
    String? playerBlack,
    String? playerWhite,
    String? gameName,
    String? gameDate,
    String? result,
  }) {
    return GameInfo(
      komi: komi ?? this.komi,
      handicap: handicap ?? this.handicap,
      playerBlack: playerBlack ?? this.playerBlack,
      playerWhite: playerWhite ?? this.playerWhite,
      gameName: gameName ?? this.gameName,
      gameDate: gameDate ?? this.gameDate,
      result: result ?? this.result,
    );
  }
}
