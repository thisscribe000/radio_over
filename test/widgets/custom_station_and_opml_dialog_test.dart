import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/models/station.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/theme.dart';
import 'package:radio_over/widgets/add_custom_station_dialog.dart';
import 'package:radio_over/widgets/opml_dialog.dart';

void main() {
  group('AddCustomStationDialog & OpmlDialog Widget Tests', () {
    testWidgets('AddCustomStationDialog validates input and saves station', (tester) async {
      final PlaybackController controller = PlaybackController();
      RadioStation? savedStation;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AddCustomStationDialog.show(
                  context,
                  controller: controller,
                  onStationAdded: (st) => savedStation = st,
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('Add Custom Radio'), findsOneWidget);

      // Attempt to save empty
      await tester.tap(find.byKey(const ValueKey('custom-station-save-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a station name.'), findsOneWidget);

      // Enter name and invalid URL
      await tester.enterText(find.byKey(const ValueKey('custom-station-name-field')), 'Cyberpunk FM');
      await tester.enterText(find.byKey(const ValueKey('custom-station-url-field')), 'not-a-url');
      await tester.tap(find.byKey(const ValueKey('custom-station-save-btn')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a valid http:// or https:// stream URL.'), findsOneWidget);

      // Enter valid URL and save & play
      await tester.enterText(find.byKey(const ValueKey('custom-station-url-field')), 'https://stream.example.com/cyber.mp3');
      await tester.enterText(find.byKey(const ValueKey('custom-station-cat-field')), 'Synthwave');

      await tester.tap(find.byKey(const ValueKey('custom-station-play-btn')));
      await tester.pumpAndSettle();

      expect(find.byType(AddCustomStationDialog), findsNothing);
      expect(savedStation, isNotNull);
      expect(savedStation!.name, 'Cyberpunk FM');
      expect(savedStation!.category, 'Synthwave');
      expect(controller.isFavouriteStation(savedStation!.stationId), isTrue);
      expect(controller.currentStation?.name, 'Cyberpunk FM');

      // Unmount before disposing
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('OpmlDialog allows importing podcast feeds from OPML XML', (tester) async {
      final PlaybackController controller = PlaybackController();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => OpmlDialog.show(
                  context,
                  controller: controller,
                ),
                child: const Text('OPEN OPML'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN OPML'));
      await tester.pumpAndSettle();

      expect(find.text('OPML Subscriptions'), findsOneWidget);
      expect(find.text('EXPORT'), findsOneWidget);
      expect(find.text('IMPORT'), findsOneWidget);

      // Switch to IMPORT tab
      await tester.tap(find.text('IMPORT'));
      await tester.pumpAndSettle();

      const String sampleOpml = '''<opml version="2.0"><body>
<outline type="rss" text="Rust In Motion" xmlUrl="https://rust.example.com/feed.xml" />
<outline type="rss" text="Dart Highlights" xmlUrl="https://dart.example.com/feed.xml" />
</body></opml>''';

      await tester.enterText(find.byKey(const ValueKey('opml-import-input')), sampleOpml);
      await tester.tap(find.byKey(const ValueKey('opml-import-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Successfully subscribed to 2 podcasts!'), findsOneWidget);
      expect(controller.isSavedShow('https://rust.example.com/feed.xml'), isTrue);
      expect(controller.isSavedShow('https://dart.example.com/feed.xml'), isTrue);

      // Unmount before disposing
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });
}
