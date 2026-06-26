import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';

/// Panel showing a winrate-over-moves line chart.
///
/// Walks the game history trunk to collect winrate data points from each
/// [BoardData] node, then renders an interactive [LineChart].
class WinrateChartPanel extends ConsumerWidget {
  const WinrateChartPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(gameProvider);
    final trunk = board.history.trunkFromRoot;

    // Build data points: (moveNumber, winrateFromBlackPerspective).
    final spots = <FlSpot>[];
    for (final node in trunk) {
      final d = node.data;
      final moveNum = d.moveNumber;
      // Flip to black's perspective if it's white's turn (meaning the last
      // move was black's and the stored winrate is from white's POV).
      final wr = d.blackToPlay ? d.winrate : 100.0 - d.winrate;
      spots.add(FlSpot(moveNum.toDouble(), wr));
    }

    // If no data yet, show a placeholder.
    if (spots.isEmpty) {
      return const Center(
        child: Text('No moves yet', style: TextStyle(color: Colors.grey)),
      );
    }

    final maxX = spots.last.x;
    final minX = spots.first.x;
    final rangeX = (maxX - minX).clamp(1.0, double.infinity);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX + 1,
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 25,
            verticalInterval: (rangeX / 4).ceilToDouble().clamp(1, double.infinity),
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 25,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}%',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: rangeX > 20 ? (rangeX / 5).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.blue,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: spots.length < 30,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 3,
                  color: Colors.blue,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withValues(alpha: 0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) =>
                  touchedSpots.map((spot) {
                return LineTooltipItem(
                  'Move ${spot.x.toInt()}\n${spot.y.toStringAsFixed(1)}%',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        duration: const Duration(milliseconds: 200),
      ),
    );
  }
}
