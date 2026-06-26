import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lizzie_mobile/ui/screens/analysis_screen.dart';

void main() {
  testWidgets('Analysis screen renders with ProviderScope', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AnalysisScreen())),
    );

    // Pump a few frames to let initState's postFrameCallback fire.
    // In tests, SharedPreferences is not mocked, so the engine defaults
    // to mock type and the connection fails silently — _isPondering stays
    // false, showing the play_arrow (start) icon instead of pause.
    await tester.pump(const Duration(milliseconds: 300));
    if (find.byIcon(Icons.pause).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.pause));
    } else {
      await tester.tap(find.byIcon(Icons.play_arrow));
    }
    await tester.pump();

    // Verify the app bar title is shown.
    expect(find.text('Lizzie Mobile'), findsOneWidget);

    // Verify app bar action icons are present.
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
    expect(find.byIcon(Icons.save), findsOneWidget);

    // Verify navigation controls are present.
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.redo), findsOneWidget);

    // Pump remaining time to let any timers settle.
    await tester.pump(const Duration(seconds: 1));
  });
}
