import 'board_data.dart';

/// A node in the n-ary Go move history tree.
///
/// Ported from Lizzie's `BoardHistoryNode.java`.
///
/// Each node holds a [BoardData] snapshot, a reference to its parent,
/// and a list of child/variation nodes. Index 0 of [variations] is the
/// "main trunk" continuation; additional entries are sibling variations.
class BoardHistoryNode {
  BoardHistoryNode? previous;
  final List<BoardHistoryNode> variations;
  final BoardData data;
  int fromBackChildren; // saved child index for branch restore

  BoardHistoryNode({
    this.previous,
    List<BoardHistoryNode>? variations,
    required this.data,
    this.fromBackChildren = 0,
  }) : variations = variations ?? [];

  /// The main continuation (first child), if any.
  BoardHistoryNode? get next => variations.isNotEmpty ? variations[0] : null;

  /// Number of child/variation nodes.
  int get childCount => variations.length;

  /// True if this node has more than one child (i.e. variations exist).
  bool get hasVariations => variations.length > 1;

  /// Add a child node as the first (main) continuation, clearing any existing.
  void add(BoardHistoryNode node) {
    variations.clear();
    variations.add(node);
    node.previous = this;
  }

  /// Add or go to a child with matching zobrist. Returns the node.
  ///
  /// If [newBranch] is false and a child with the same zobrist hash exists,
  /// returns that child (dedup). Otherwise appends a new child.
  /// If [changeMove] is true, replaces the first child while preserving
  /// its subtree (used by change-move functionality).
  BoardHistoryNode addOrGoto(
    BoardData newData,
    bool newBranch,
    bool changeMove,
  ) {
    if (!newBranch) {
      // Check for transposition (matching zobrist).
      for (final child in variations) {
        if (child.data.zobrist == newData.zobrist) {
          return child;
        }
      }
    }

    final node = BoardHistoryNode(data: newData, previous: this);

    if (changeMove && variations.isNotEmpty) {
      // Replace first child but keep its subtree.
      node.variations.addAll(variations[0].variations);
      for (final v in node.variations) {
        v.previous = node;
      }
      variations[0] = node;
    } else {
      variations.add(node);
    }

    return node;
  }

  /// Get a specific variation by index.
  BoardHistoryNode? variation(int idx) =>
      idx >= 0 && idx < variations.length ? variations[idx] : null;

  /// Depth of the trunk from here to leaf (following next()).
  int get trunkDepth {
    int d = 0;
    var n = this;
    while (n.next != null) {
      d++;
      n = n.next!;
    }
    return d;
  }

  /// True if this node is on the main trunk (not a branch variation).
  bool get isMainTrunk {
    var ancestor = previous;
    while (ancestor != null) {
      if (ancestor.next != this) return false;
      ancestor = ancestor.previous;
    }
    return true;
  }
}
