import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/widgets/add_rss_feed_dialog.dart';
import 'package:radio_over/theme.dart';

void main() {
  Widget buildTestableDialog({void Function(String?)? onResult}) {
    return MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await AddRssFeedDialog.show(context);
                onResult?.call(result);
              },
              child: const Text('OPEN DIALOG'),
            ),
          ),
        ),
      ),
    );
  }

  group('AddRssFeedDialog Widget Tests', () {
    testWidgets('tapping cancel dismisses dialog cleanly with null result', (tester) async {
      String? result = 'initial';
      await tester.pumpWidget(buildTestableDialog(onResult: (r) => result = r));

      await tester.tap(find.text('OPEN DIALOG'));
      await tester.pumpAndSettle();

      expect(find.byType(AddRssFeedDialog), findsOneWidget);
      expect(find.text('ADD RSS PODCAST'), findsNothing);
      expect(find.text('Add RSS Podcast'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.byKey(const ValueKey('rss-add-cancel')));
      await tester.pumpAndSettle();

      expect(find.byType(AddRssFeedDialog), findsNothing);
      expect(result, isNull);
    });

    testWidgets('submitting empty or invalid URL shows validation error', (tester) async {
      await tester.pumpWidget(buildTestableDialog());

      await tester.tap(find.text('OPEN DIALOG'));
      await tester.pumpAndSettle();

      // Submit empty
      await tester.tap(find.byKey(const ValueKey('rss-add-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter an RSS feed URL.'), findsOneWidget);

      // Enter invalid scheme
      await tester.enterText(find.byKey(const ValueKey('rss-add-input')), 'not-a-valid-url');
      await tester.tap(find.byKey(const ValueKey('rss-add-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid http:// or https:// URL.'), findsOneWidget);
    });

    testWidgets('submitting valid URL returns the url', (tester) async {
      String? result;
      await tester.pumpWidget(buildTestableDialog(onResult: (r) => result = r));

      await tester.tap(find.text('OPEN DIALOG'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('rss-add-input')), 'https://feeds.example.com/podcast.xml');
      await tester.tap(find.byKey(const ValueKey('rss-add-submit')));
      await tester.pumpAndSettle();

      expect(find.byType(AddRssFeedDialog), findsNothing);
      expect(result, 'https://feeds.example.com/podcast.xml');
    });
  });
}
