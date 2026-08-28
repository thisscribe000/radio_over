import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/navigation/app_shell.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/theme.dart';
import 'package:radio_over/widgets/pill_tab_bar.dart';

/// Runs a shell test, unmounting before the controller is disposed so the
/// playback/sleep tickers never trip `!timersPending`.
Future<void> runNavTest(
  WidgetTester tester,
  Future<void> Function(WidgetTester, PlaybackController) body,
) async {
  final PlaybackController controller = PlaybackController();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: AppShell(controller: controller),
    ),
  );
  try {
    await body(tester, controller);
  } finally {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  }
}

Finder iconIn(String label, IconData icon) => find.descendant(
      of: find.byKey(ValueKey('tab-$label')),
      matching: find.byIcon(icon),
    );

Finder labelIn(String label) => find.descendant(
      of: find.byKey(ValueKey('tab-$label')),
      matching: find.text(label),
    );

void main() {
  testWidgets('active tab shows its label with no icon; inactive show icon only',
      (tester) async {
    await runNavTest(tester, (tester, _) async {
      // RADIO (left) selected initially.
      expect(labelIn('RADIO'), findsOneWidget);
      expect(iconIn('RADIO', Icons.radio), findsNothing);

      // Inactive tabs: icon only, no label.
      expect(iconIn('PODCASTS', Icons.podcasts), findsOneWidget);
      expect(labelIn('PODCASTS'), findsNothing);
      expect(iconIn('LIBRARY', Icons.library_music_outlined), findsOneWidget);
      expect(labelIn('LIBRARY'), findsNothing);
    });
  });

  testWidgets('only one destination shows a label at a time', (tester) async {
    await runNavTest(tester, (tester, _) async {
      // Exactly one label across the whole bar (the active tab).
      expect(
        find.descendant(
          of: find.byType(PillTabBar),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PillTabBar),
          matching: find.byType(Icon),
        ),
        findsNWidgets(2),
      );
    });
  });

  testWidgets('switching moves the label from old tab to new tab', (tester) async {
    await runNavTest(tester, (tester, _) async {
      await tester.tap(find.byKey(const ValueKey('tab-PODCASTS')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Podcasts now shows the label; its icon is gone.
      expect(labelIn('PODCASTS'), findsOneWidget);
      expect(iconIn('PODCASTS', Icons.podcasts), findsNothing);
      // Radio collapsed back to its icon.
      expect(iconIn('RADIO', Icons.radio), findsOneWidget);
      expect(labelIn('RADIO'), findsNothing);
      expect(iconIn('LIBRARY', Icons.library_music_outlined), findsOneWidget);
      expect(labelIn('LIBRARY'), findsNothing);

      // Move to Library (right).
      await tester.tap(find.byKey(const ValueKey('tab-LIBRARY')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(labelIn('LIBRARY'), findsOneWidget);
      expect(iconIn('LIBRARY', Icons.library_music_outlined), findsNothing);
      expect(iconIn('PODCASTS', Icons.podcasts), findsOneWidget);
      expect(labelIn('PODCASTS'), findsNothing);

      // Move back to Radio (left) — reverse direction also works.
      await tester.tap(find.byKey(const ValueKey('tab-RADIO')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(labelIn('RADIO'), findsOneWidget);
      expect(iconIn('RADIO', Icons.radio), findsNothing);
      expect(iconIn('LIBRARY', Icons.library_music_outlined), findsOneWidget);
      expect(labelIn('LIBRARY'), findsNothing);
    });
  });

  testWidgets('stays responsive across phone widths without overflow',
      (tester) async {
    const List<PillTabDestination> destinations = [
      PillTabDestination('RADIO', Icons.radio),
      PillTabDestination('PODCASTS', Icons.podcasts),
      PillTabDestination('LIBRARY', Icons.library_music_outlined),
    ];

    for (final (double width, int selected) in <(double, int)>[
      (320, 1),
      (375, 0),
      (414, 2),
      (480, 1),
    ]) {
      Widget harness() => MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: PillTabBar(
                    tabs: destinations,
                    selectedIndex: selected,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          );
      await tester.pumpWidget(harness());
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull, reason: 'overflow at width $width');

      // The selected tab shows its label, not its icon, at every width.
      final String activeLabel = destinations[selected].label;
      final IconData activeIcon = destinations[selected].icon;
      expect(labelIn(activeLabel), findsOneWidget);
      expect(iconIn(activeLabel, activeIcon), findsNothing);
    }
  });

  testWidgets('PillTabBar is reusable and index driven', (tester) async {
    const List<PillTabDestination> destinations = [
      PillTabDestination('A', Icons.house_outlined),
      PillTabDestination('B', Icons.auto_stories_outlined),
      PillTabDestination('C', Icons.person_outline),
    ];

    Widget harness(int index) => MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 375,
                child: PillTabBar(
                  tabs: destinations,
                  selectedIndex: index,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(harness(0));
    expect(labelIn('A'), findsOneWidget);
    expect(iconIn('A', Icons.house_outlined), findsNothing);
    expect(iconIn('B', Icons.auto_stories_outlined), findsOneWidget);
    expect(labelIn('B'), findsNothing);

    await tester.pumpWidget(harness(1));
    await tester.pump(const Duration(milliseconds: 350));
    expect(labelIn('B'), findsOneWidget);
    expect(iconIn('B', Icons.auto_stories_outlined), findsNothing);
    expect(iconIn('A', Icons.house_outlined), findsOneWidget);
    expect(labelIn('A'), findsNothing);

    await tester.pumpWidget(harness(2));
    await tester.pump(const Duration(milliseconds: 350));
    expect(labelIn('C'), findsOneWidget);
    expect(iconIn('C', Icons.person_outline), findsNothing);
    expect(iconIn('A', Icons.house_outlined), findsOneWidget);
    expect(labelIn('A'), findsNothing);
    expect(iconIn('B', Icons.auto_stories_outlined), findsOneWidget);
    expect(labelIn('B'), findsNothing);
  });
}
