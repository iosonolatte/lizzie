/// Represents the contents of one intersection on a Go board.
///
/// Ported from Lizzie's `Stone.java` with the same set of values used
/// during flood-fill capture, scoring, and ghost-stone display.
enum Stone {
  black,
  white,
  empty,

  /// Flood-fill "visited" markers — swapped in during liberty checks,
  /// then either restored or replaced with EMPTY on cleanup.
  blackRecursed,
  whiteRecursed,

  /// Display-only ghost stones for analysis principal variations.
  blackGhost,
  whiteGhost,

  /// Neutral territory / visited marker during scoring.
  dame,

  /// Territory ownership (scoring mode).
  blackPoint,
  whitePoint,

  /// Stones marked dead/captured during scoring.
  blackCaptured,
  whiteCaptured;

  Stone get opposite {
    switch (this) {
      case Stone.black:
        return Stone.white;
      case Stone.white:
        return Stone.black;
      default:
        return this;
    }
  }

  Stone get recursed {
    switch (this) {
      case Stone.black:
        return Stone.blackRecursed;
      case Stone.white:
        return Stone.whiteRecursed;
      default:
        return this;
    }
  }

  Stone get unrecursed {
    switch (this) {
      case Stone.blackRecursed:
        return Stone.black;
      case Stone.whiteRecursed:
        return Stone.white;
      default:
        return this;
    }
  }

  bool get isBlack =>
      this == Stone.black ||
      this == Stone.blackRecursed ||
      this == Stone.blackGhost;

  bool get isWhite => this != Stone.empty && !isBlack;

  Stone get unGhosted {
    switch (this) {
      case Stone.black:
      case Stone.blackGhost:
        return Stone.black;
      case Stone.white:
      case Stone.whiteGhost:
        return Stone.white;
      default:
        return Stone.empty;
    }
  }
}
