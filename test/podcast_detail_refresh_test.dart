import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/data/content_scope.dart';
import 'package:radio_over/data/podcasts/mock_podcast_directory_repository.dart';
import 'package:radio_over/data/podcasts/podcast_feed_repository.dart';
import 'package:radio_over/data/podcasts/rss_podcast_parser.dart';
import 'package:radio_over/data/radio/mock_radio_repository.dart';
import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/playback/playback_controller.dart';
import 'package:radio_over/screens/podcast_detail_screen.dart';
import 'package:radio_over/theme.dart';

/// Scriptable feed source mirroring the service-test fake: per-URL bodies
/// tests mutate between refreshes plus fault injection.
class FakeFeedRepository implements PodcastFeedRepository {
  final Map<String, String> _bodies = {};
  final Set<String> _networkFaults = {};

  void serve(String url, String body) => _bodies[url] = body;
  void failNetwork(String url) => _networkFaults.add(url);

  @override
  Future<PodcastSeries> feed(
    String feedUrl, {
    String? preferredId,
    String? preferredName,
    String? preferredAuthor,
    String? preferredImageUrl,
  }) async {
    if (_networkFaults.contains(feedUrl)) {
      throw Exception('offline');
    }
    return const RssPodcastParser().parseFeed(_bodies[feedUrl]!);
  }
}

String item(String guid, String title) => '''
<item>
  <title>$title</title>
  <guid>$guid</guid>
  <pubDate>Mon, 17 Aug 2026 08:00:00 +0000</pubDate>
  <itunes:duration>30:00</itunes:duration>
  <enclosure url="https://example.com/$guid.mp3" type="audio/mpeg"/>
</item>''';

String feedXml(List<String> items) => '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
<channel>
  <title>Signal Fire</title>
  <description>Design stories.</description>
  <itunes:author>Roman Mars</itunes:author>
  ${items.join('\n')}
</channel>
</rss>
''';

const String feedUrl = 'https://example.com/signal-fire.xml';

const PodcastSeries skeleton = PodcastSeries(
  id: 'signal-fire',
  name: 'Signal Fire',
  category: 'Design',
  publisher: 'Roman Mars',
  description: 'Design stories.',
  feedUrl: feedUrl,
  episodes: [],
);

Finder row(String episodeId) => find.byKey(ValueKey('detail-row-$episodeId'));
Finder newBadge(String episodeId) => find.byKey(ValueKey('detail-new-$episodeId'));

/// Pumps the show screen against a scripted feed scope. [arrange] runs before
/// the first build so the opening load already sees the initial feed body.
/// The tree is unmounted before the controller is disposed so the playback
/// clock never outlives the test (pending-timer rule).
Future<void> runDetailTest(
  WidgetTester tester,
  void Function(FakeFeedRepository) arrange,
  Future<void> Function(WidgetTester, PlaybackController, FakeFeedRepository) body,
) async {
  final PlaybackController controller = PlaybackController();
  final FakeFeedRepository feeds = FakeFeedRepository();
  arrange(feeds);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: PodcastDetailScreen(
        show: skeleton,
        controller: controller,
        content: AppContent(
          radio: const MockRadioRepository(),
          podcastDirectory: const MockPodcastDirectoryRepository(),
          podcastFeeds: feeds,
          seedShows: [skeleton],
          savedShowsProvider: () => controller.savedShows,
          onNewEpisodes: (show, episodes) =>
              controller.markEpisodesUnseen([for (final e in episodes) e.id]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  try {
    await body(tester, controller, feeds);
  } finally {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  }
}

Future<void> pullToRefresh(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('podcast-detail-list')),
    const Offset(0, 320),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TEST 1 · opening the show fetches the feed and episodes appear',
      (tester) {
    return runDetailTest(tester, (feeds) {
      feeds.serve(feedUrl, feedXml([
        item('e100', 'Ep 100'),
        item('e99', 'Ep 99'),
      ]));
    }, (tester, controller, feeds) async {
      expect(row('e100'), findsOneWidget);
      expect(row('e99'), findsOneWidget);
      expect(find.text('Ep 100'), findsOneWidget);
    });
  });

  testWidgets(
      'TEST 3 · pull to refresh discovers a new episode with a NEW badge',
      (tester) {
    return runDetailTest(tester, (feeds) {
      feeds.serve(feedUrl, feedXml([item('e100', 'Ep 100')]));
    }, (tester, controller, feeds) async {
      // First discovery flags the episode as new.
      expect(row('e100'), findsOneWidget);
      expect(newBadge('e100'), findsOneWidget);

      feeds.serve(feedUrl, feedXml([
        item('e101', 'Ep 101'),
        item('e100', 'Ep 100'),
      ]));
      await pullToRefresh(tester);

      expect(row('e101'), findsOneWidget);
      expect(row('e100'), findsOneWidget); // no duplicates, old rows intact
      expect(newBadge('e101'), findsOneWidget);
      expect(newBadge('e100'), findsOneWidget); // untouched until opened
    });
  });

  testWidgets('TEST 4 · playing the new episode clears its NEW badge',
      (tester) {
    return runDetailTest(tester, (feeds) {
      feeds.serve(feedUrl, feedXml([
        item('e101', 'Ep 101'),
        item('e100', 'Ep 100'),
      ]));
    }, (tester, controller, feeds) async {
      // The opening load itself discovers both episodes as new.
      expect(newBadge('e101'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('detail-play-e101')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(controller.isNewEpisode('e101'), isFalse);
      expect(newBadge('e101'), findsNothing);
    });
  });

  testWidgets(
      'TEST 5 · network failure keeps cached episodes and shows a retry hint',
      (tester) {
    return runDetailTest(tester, (feeds) {
      feeds.serve(feedUrl, feedXml([item('e100', 'Ep 100')]));
    }, (tester, controller, feeds) async {
      expect(row('e100'), findsOneWidget);

      feeds.failNetwork(feedUrl);
      await pullToRefresh(tester);

      expect(row('e100'), findsOneWidget); // cache survives
      expect(find.text("COULDN'T REFRESH · PULL TO RETRY"), findsOneWidget);
    });
  });

  testWidgets('a successful refresh shows the quiet UPDATED metadata',
      (tester) {
    return runDetailTest(tester, (feeds) {
      feeds.serve(feedUrl, feedXml([item('e100', 'Ep 100')]));
    }, (tester, controller, feeds) async {
      feeds.serve(feedUrl, feedXml([
        item('e101', 'Ep 101'),
        item('e100', 'Ep 100'),
      ]));
      await pullToRefresh(tester);

      expect(find.text('UPDATED JUST NOW'), findsOneWidget);
    });
  });
}
