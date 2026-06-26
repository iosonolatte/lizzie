import 'package:flutter/material.dart';

/// Dialog showing the final scoring result after exiting scoring mode.
///
/// Displays territory counts, captures, komi, and the final result string.
class ScoringResultDialog extends StatelessWidget {
  final int blackTerritory;
  final int whiteTerritory;
  final int dame;
  final int blackCaptures;
  final int whiteCaptures;
  final double komi;
  final double scoreDiff;

  const ScoringResultDialog({
    super.key,
    required this.blackTerritory,
    required this.whiteTerritory,
    required this.dame,
    required this.blackCaptures,
    required this.whiteCaptures,
    required this.komi,
    required this.scoreDiff,
  });

  @override
  Widget build(BuildContext context) {
    // Chinese (area) scoring: territory + stones on board + komi.
    // scoreDiff = blackScore - whiteScore (already accounts for komi).
    final resultStr = scoreDiff > 0
        ? 'B+${scoreDiff.toStringAsFixed(1)}'
        : scoreDiff < 0
            ? 'W+${(-scoreDiff).toStringAsFixed(1)}'
            : 'Draw';

    return AlertDialog(
      title: const Text('Scoring Result'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _resultRow('Territory (B)', '$blackTerritory'),
          _resultRow('Territory (W)', '$whiteTerritory'),
          _resultRow('Captures (B)', '$blackCaptures'),
          _resultRow('Captures (W)', '$whiteCaptures'),
          if (dame > 0) _resultRow('Dame', '$dame'),
          const Divider(),
          _resultRow('Komi', komi.toStringAsFixed(1)),
          const Divider(thickness: 2),
          _resultRow(
            'Result',
            resultStr,
            valueStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: scoreDiff > 0 ? Colors.black : Colors.grey[800],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _resultRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: valueStyle ?? const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
