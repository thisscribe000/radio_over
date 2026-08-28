import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/data/content_scope.dart';
import 'package:radio_over/data/podcasts/mock_podcast_directory_repository.dart';
import 'package:radio_over/data/podcasts/mock_podcast_feed_repository.dart';
import 'package:radio_over/data/radio/mock_radio_repository.dart';
import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/models/station.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/search_screen.dart';
import 'package:radio_over/theme.dart';

/// A live content scope with a scriptable search: records every call and lets
/// the test answer each query (and control latency) so debounce and stale-
/// request behaviour can be asserted.
class FakeLiveContent extends AppContent {
  FakeLiveContent()
      : super(
          radio: const MockRadioRepository([]),
          podcastDirectory: const MockPodcastDirectoryRepository(series: []),
          podcastFeeds: const MockPodcastFeedRepository(),
          isLive: true,
        );

  final List<String> stationCalls = [];
  final List<String> showCalls = [];
  Duration delay = Duration.zero;
  Map<String, List<RadioStation>> stationAnswers = {};
  Map<String, List<PodcastSeries>> showAnswers = {};

  @override
  Future<List<RadioStation>> searchStations(String query, {int limit = 25}) async {
    stationCalls.add(query);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return stationAnswers[query] ?? const [];
  }

  @override
  Future<List<PodcastSeries>> searchShows(String query, {int limit = 25}) async {
    showCalls.add(query);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return showAnswers[query] ?? const [];
  }
}

Future<void> typeQuery(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(const ValueKey('search-field')), query);
  await tester.pump();
}

void main() {
  testWidgets('empty query does not fire a search request', (tester) async {
    final FakeLiveContent content = FakeLiveContent();
    final PlaybackController controller = PlaybackController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SearchScreen(controller: controller, content: content),
      ),
    );

    await typeQuery(tester, '   ');
    await tester.pump(const Duration(milliseconds: 400));

    expect(content.stationCalls, isEmpty);
    expect(content.showCalls, isEmpty);
    expect(find.byKey(const ValueKey('search-discovery')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('debounce collapses a burst of keystrokes into one search',
      (tester) async {
    final FakeLiveContent content = FakeLiveContent();
    final PlaybackController controller = PlaybackController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SearchScreen(controller: controller, content: content),
      ),
    );

    // Type b, bb, bbc within the debounce window — only the last fires.
    await typeQuery(tester, 'b');
    await tester.pump(const Duration(milliseconds: 50));
    await typeQuery(tester, 'bb');
    await tester.pump(const Duration(milliseconds: 50));
    await typeQuery(tester, 'bbc');
    await tester.pump(const Duration(milliseconds: 400));

    expect(content.stationCalls, ['bbc']);
    expect(content.showCalls, ['bbc']);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('a late request does not overwrite a newer result',
      (tester) async {
    final FakeLiveContent content = FakeLiveContent();
    // First query resolves slowly so the newer query lands first.
    content.delay = const Duration(milliseconds: 500);
    content.stationAnswers['bbc'] = const [
      RadioStation(name: 'BBC 1', category: 'News', program: 'LIVE RADIO'),
    ];
    content.stationAnswers['cnn'] = const [
      RadioStation(name: 'CNN', category: 'News', program: 'LIVE RADIO'),
    ];
    final PlaybackController controller = PlaybackController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: SearchScreen(controller: controller, content: content),
      ),
    );

    // "bbc" passes its debounce and its request starts (resolves +500ms).
    await typeQuery(tester, 'bbc');
    await tester.pump(const Duration(milliseconds: 250));
    // Change to "cnn" before the bbc request resolves.
    await typeQuery(tester, 'cnn');
    await tester.pump(const Duration(milliseconds: 900));

    // The late "bbc" response must be discarded — only CNN is shown.
    expect(content.stationCalls, containsAll(['bbc', 'cnn']));
    expect(find.text('BBC 1'), findsNothing);
    expect(find.text('CNN'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
