import 'package:flutter/material.dart';
import 'move_list.dart';
import 'subboard.dart';
import 'winrate_chart.dart';

/// Tab-based analysis panel below the board.
///
/// Contains three tabs:
/// - Winrate: line chart of winrate across moves
/// - Subboard: mini board overview with move numbers
/// - Moves: scrollable list of played moves
class AnalysisPanel extends StatelessWidget {
  const AnalysisPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Material(
              color: Colors.grey[50],
              child: TabBar(
                labelColor: Colors.blue[800],
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Colors.blue[800],
                tabs: const [
                  Tab(icon: Icon(Icons.trending_up, size: 18), text: 'Winrate'),
                  Tab(icon: Icon(Icons.grid_on, size: 18), text: 'Subboard'),
                  Tab(icon: Icon(Icons.list, size: 18), text: 'Moves'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const WinrateChartPanel(),
                  const SubboardPanel(),
                  const MoveListPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
