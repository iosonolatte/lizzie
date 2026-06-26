import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../go/coords.dart';
import '../../state/providers.dart';

/// Scrollable list of played moves with move number, color, coordinate, and
/// winrate. Tapping a move navigates to that position.
class MoveListPanel extends ConsumerWidget {
  const MoveListPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(gameProvider);
    final trunk = board.history.trunkFromRoot;
    final currentMove = board.moveNumber;
    final data = board.data;

    // Capture counts.
    final bc = data.blackCaptures;
    final wc = data.whiteCaptures;

    return Column(
      children: [
        // Capture counts header.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: Colors.grey[100],
          child: Row(
            children: [
              _captureChip(Colors.black, bc),
              const SizedBox(width: 16),
              _captureChip(Colors.white, wc),
            ],
          ),
        ),
        // Move list.
        Expanded(
          child: trunk.isEmpty
              ? const Center(
                  child: Text(
                    'No moves yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: trunk.length,
                  itemBuilder: (context, index) {
                    final node = trunk[index];
                    final d = node.data;
                    final moveNum = d.moveNumber;
                    if (moveNum == 0) {
                      return const SizedBox.shrink(); // skip root
                    }

                    final isCurrent = moveNum == currentMove;
                    final isBlack = d.lastMoveColor.isBlack;
                    final coord = d.lastMove != null
                        ? Coords.xyToGtp(
                            d.lastMove![0],
                            d.lastMove![1],
                            d.width,
                            d.height,
                          )
                        : 'PASS';
                    final wr = d.winrate;

                    return ListTile(
                      dense: true,
                      selected: isCurrent,
                      selectedTileColor: Colors.blue.withValues(alpha: 0.1),
                      leading: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isBlack ? Colors.black : Colors.white,
                          border: Border.all(
                            color: isBlack
                                ? Colors.transparent
                                : Colors.grey[400]!,
                          ),
                        ),
                      ),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$moveNum. $coord',
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          if (d.comment.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.comment,
                              size: 14,
                              color: Colors.blueGrey[300],
                            ),
                          ],
                        ],
                      ),
                      trailing: Text(
                        '${wr.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: wr >= 50 ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                      onTap: () {
                        // Navigate to this move in history.
                        final controller = ref.read(gameProvider.notifier);
                        controller.toStart();
                        for (int i = 0; i < moveNum; i++) {
                          if (!controller.next()) break;
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _captureChip(Color stoneColor, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: stoneColor,
            border: stoneColor == Colors.white
                ? Border.all(color: Colors.grey[400]!)
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text('$count', style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
