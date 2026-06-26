import 'board_data.dart';
import 'board_history_node.dart';

/// Cursor-based navigation of the Go move history tree.
///
/// Ported from Lizzie's `BoardHistoryList.java`.
///
/// Maintains a pointer to the current [head] node in the tree and provides
/// navigation: previous, next, to start, to end, variation switching.
class BoardHistoryList {
  BoardHistoryNode head;

  BoardHistoryList(BoardData rootData)
    : head = BoardHistoryNode(data: rootData);

  // ---------------------------------------------------------------------------
  // Current state
  // ---------------------------------------------------------------------------

  BoardData get data => head.data;

  int get moveNumber => data.moveNumber;

  bool get canGoBack => head.previous != null;

  bool get canGoForward => head.next != null;

  bool get isAtRoot => head.previous == null;

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  /// Move to the previous node (parent).
  /// Returns true if successful.
  bool previous() {
    if (head.previous == null) return false;
    head = head.previous!;
    return true;
  }

  /// Move to the first child (main trunk continuation).
  /// Returns true if successful.
  bool next() {
    if (head.next == null) return false;
    head = head.next!;
    return true;
  }

  /// Move to the root node.
  void toStart() {
    while (head.previous != null) {
      head = head.previous!;
    }
  }

  /// Move to the end (leaf following next()).
  void toEnd() {
    while (head.next != null) {
      head = head.next!;
    }
  }

  /// Switch to a specific variation by index.
  /// Returns true if that variation exists.
  bool switchToVariation(int idx) {
    if (idx < 0 || idx >= head.variations.length) return false;
    head = head.variations[idx];
    return true;
  }

  /// Get the index of the current node among its parent's variations.
  int get currentVariationIndex {
    if (head.previous == null) return 0;
    return head.previous!.variations.indexOf(head);
  }

  /// Number of variations from the current node's parent.
  int get variationCount => head.previous?.variations.length ?? 1;

  // ---------------------------------------------------------------------------
  // Tree mutation
  // ---------------------------------------------------------------------------

  /// Add a new node after the current position.
  /// See [BoardHistoryNode.addOrGoto] for [newBranch] and [changeMove] semantics.
  void addOrGoto(BoardData newData, bool newBranch, bool changeMove) {
    head = head.addOrGoto(newData, newBranch, changeMove);
  }

  /// Replace the root node (used by handicap flatten and board reset).
  void replaceRoot(BoardData rootData) {
    head = BoardHistoryNode(data: rootData);
  }

  /// Get the root node.
  BoardHistoryNode get root {
    var n = head;
    while (n.previous != null) {
      n = n.previous!;
    }
    return n;
  }

  // ---------------------------------------------------------------------------
  // Ko detection
  // ---------------------------------------------------------------------------

  /// Simple ko check: compares the candidate position's zobrist to the
  /// grandparent's zobrist. This is what the `place()` method enforces.
  ///
  /// Ported from `BoardHistoryList.violatesKoRule()`.
  bool violatesKoRule(BoardData candidate) {
    if (head.previous == null) return false;
    final grandparent = head.previous!.previous;
    if (grandparent == null) return false;
    return candidate.zobrist == grandparent.data.zobrist;
  }

  /// Full positional superko check: walks the entire trunk from current node
  /// to root comparing zobrist AND side-to-play.
  ///
  /// Ported from `BoardHistoryList.violatesSuperko()`.
  /// NOTE: `place()` does NOT call this by default (only `violatesKoRule` is used).
  bool violatesSuperko(BoardData candidate) {
    var n = head;
    while (n.previous != null) {
      n = n.previous!;
      if (candidate.zobrist == n.data.zobrist &&
          candidate.blackToPlay == n.data.blackToPlay) {
        return true;
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // History walking
  // ---------------------------------------------------------------------------

  /// Walk from root to current head, returning all nodes on the path.
  List<BoardHistoryNode> get pathFromRoot {
    final path = <BoardHistoryNode>[];
    var n = head;
    while (n.previous != null) {
      path.add(n);
      n = n.previous!;
    }
    path.add(n); // root
    return path.reversed.toList();
  }

  /// Walk from root to current head, returning BoardData for each node.
  List<BoardData> get dataPathFromRoot =>
      pathFromRoot.map((n) => n.data).toList();

  /// Walk from root to leaf, following the main trunk.
  List<BoardHistoryNode> get trunkFromRoot {
    final result = <BoardHistoryNode>[];
    var n = root;
    result.add(n);
    while (n.next != null) {
      n = n.next!;
      result.add(n);
    }
    return result;
  }
}
