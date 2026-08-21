import 'package:flutter_test/flutter_test.dart';

import 'package:radio_over/data/content_scope.dart';
import 'package:radio_over/data/podcasts/podcast_feed_refresh_service.dart';
import 'package:radio_over/data/podcasts/podcast_feed_repository.dart';
import 'package:radio_over/data/podcasts/rss_podcast_parser.dart';
import 'package:radio_over/data/podcasts/mock_podcast_directory_repository.dart';
import 'package:radio_over/data/radio/mock_radio_repository.dart';
import 'package:radio_over/data/radio/radio_repository.dart';
import 'package:radio_over/models/podcast_episode.dart';
import 'package:radio_over/models/podcast_subscription.dart';

/// Scriptable feed source: serves per-URL RSS bodies that tests mutate
/// between refreshes, counts fetches, and can simulate network/parse faults.
class FakeFeedRepository implements PodcastFeedRepository {
  final Map<String, String> _bodies = {};
  final Set<String> _networkFaults = {};
  final Set<String> _invalidFaults = {};
  int fetchCount = 0;

  void serve(String url, String body) => _bodies[url] = body;
  void failNetwork(String url) => _networkFaults.add(url);
  void failInvalid(String url) => _invalidFaults.add(url);
  void heal(String url) {
    _networkFaults.remove(url);
    _invalidFaults.remove(url);
  }

  @override
  Future<PodcastSeries> feed(
    String feedUrl, {
    String? preferredId,
    String? preferredName,
    String? preferredAuthor,
    String? preferredImageUrl,
  }) async {
    fetchCount++;
    if (_networkFaults.contains(feedUrl)) {
      throw ContentSourceException('Feed unreachable: $feedUrl');
    }
    if (_invalidFaults.contains(feedUrl)) {
      throw const FormatException('Not an RSS feed');
    }
    final String? body = _bodies[feedUrl];
    if (body == null) throw ContentSourceException('Feed 404: $feedUrl');
    return const RssPodcastParser().parseFeed(
      body,
      preferredId: preferredId,
      preferredName: preferredName,
      preferredAuthor: preferredAuthor,
      preferredImageUrl: preferredImageUrl,
    );
  }
}

String item({
  required String guid,
  required String title,
  String duration = '30:00',
  String pubDate = 'Mon, 17 Aug 2026 08:00:00 +0000',
}) =>
    '''
<item>
  <title>$title</title>
  <guid>$guid</guid>
  <pubDate>$pubDate</pubDate>
  <itunes:duration>$duration</itunes:duration>
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
final DateTime startTime = DateTime(2026, 8, 20, 12);

const PodcastSeries skeleton = PodcastSeries(
  id: 'signal-fire',
  name: 'Signal Fire',
  category: 'Design',
  publisher: 'Roman Mars',
  description: 'Design stories.',
  feedUrl: feedUrl,
  episodes: [],
);

/// Everything one test needs: scriptable feeds, a mutable followed-set, an
/// advanceable clock and the service under test over a seeded content scope.
class Fixture {
  Fixture({this.minInterval = const Duration(minutes: 15)}) {
    DateTime current = startTime;
    now = () => current;
    tick = (Duration d) => current = current.add(d);
    content = AppContent(
      radio: const MockRadioRepository(),
      podcastDirectory: const MockPodcastDirectoryRepository(),
      podcastFeeds: feeds,
      seedShows: [skeleton],
      savedShowsProvider: () => saved,
      onNewEpisodes: (show, episodes) =>
          discovered.addAll(episodes.map((e) => e.id)),
    );
    service = PodcastFeedRefreshService(
      content: content,
      feeds: feeds,
      minRefreshInterval: minInterval,
      clock: now,
      savedShowsProvider: () => saved,
      onNewEpisodes: (show, episodes) =>
          discovered.addAll(episodes.map((e) => e.id)),
    );
  }

  final FakeFeedRepository feeds = FakeFeedRepository();
  final Set<String> saved = {};
  final Set<String> discovered = {};
  final Duration minInterval;
  late final AppContent content;
  late final PodcastFeedRefreshService service;
  late DateTime Function() now;
  late void Function(Duration) tick;
}

void main() {
  group('episodeIdentityKey', () {
    test('prefers the feed GUID', () {
      const PodcastEpisode withGuid = PodcastEpisode(
        id: 'a',
        podcastId: 'p',
        podcastName: 'P',
        title: 'Title',
        duration: Duration(minutes: 10),
        guid: 'urn:guid-1',
      );
      expect(episodeIdentityKey(withGuid), 'guid:urn:guid-1');
    });

    test('falls back to normalized title/date/audio when no GUID', () {
      const PodcastEpisode base = PodcastEpisode(
        id: 'a',
        podcastId: 'p',
        podcastName: 'P',
        title: 'The   Big Story',
        duration: Duration(minutes: 10),
        published: 'Aug 18',
        audioUrl: 'https://cdn.example.com/a.mp3',
      );
      const PodcastEpisode same = PodcastEpisode(
        id: 'whatever',
        podcastId: 'p',
        podcastName: 'P',
        title: 'the big story',
        duration: Duration(minutes: 10),
        published: 'Aug 18',
        audioUrl: 'https://cdn.example.com/a.mp3',
      );
      expect(episodeIdentityKey(base), episodeIdentityKey(same));
      expect(episodeIdentityKey(base), startsWith('fallback:'));
    });
  });

  group('PodcastFeedRefreshService', () {
    test('TEST 1 · opening a show fetches the feed and episodes appear', () async {
      final Fixture f = Fixture()
        ..feeds.serve(feedUrl, feedXml([
          item(guid: 'e100', title: 'Ep 100'),
          item(guid: 'e99', title: 'Ep 99'),
        ]));

      final PodcastSeries loaded = await f.service.resolveForDisplay(skeleton);

      expect(loaded.episodes, hasLength(2));
      expect(loaded.episodes.first.id, 'e100');
      // Written through to the shared catalogue too.
      expect(f.content.showById('signal-fire')!.episodes, hasLength(2));
    });

    test('TEST 2 · refreshing the unchanged feed adds no duplicates', () async {
      final Fixture f = Fixture()
        ..feeds.serve(feedUrl, feedXml([
          item(guid: 'e100', title: 'Ep 100'),
          item(guid: 'e99', title: 'Ep 99'),
        ]));

      await f.service.resolveForDisplay(skeleton);
      final FeedRefreshResult result =
          await f.service.refresh(skeleton, force: true);

      expect(result.status, FeedRefreshStatus.noChanges);
      expect(result.newEpisodes, isEmpty);
      expect(result.show.episodes, hasLength(2));
      expect(f.feeds.fetchCount, 2);
    });

    test('TEST 3 · a new topmost episode is detected without duplicating the rest',
        () async {
      final Fixture f = Fixture()
        ..feeds.serve(feedUrl, feedXml([
          item(guid: 'e100', title: 'Ep 100'),
          item(guid: 'e99', title: 'Ep 99'),
        ]));

      await f.service.resolveForDisplay(skeleton);
      f.discovered.clear(); // first load discovers everything; only diffs matter

      f.feeds.serve(feedUrl, feedXml([
        item(guid: 'e101', title: 'Ep 101'),
        item(guid: 'e100', title: 'Ep 100'),
        item(guid: 'e99', title: 'Ep 99'),
      ]));
      final FeedRefreshResult result =
          await f.service.refresh(skeleton, force: true);

      expect(result.status, FeedRefreshStatus.success);
      expect(result.newEpisodes.map((e) => e.id), ['e101']);
      expect(result.show.episodes, hasLength(3));
      expect(result.show.episodes.map((e) => e.id),
          ['e101', 'e100', 'e99']);
      expect(f.discovered, {'e101'});
    });

    test('merged episodes keep their local playback position', () async {
      final Fixture f = Fixture();
      // Seed the catalogue with a cached copy that carries progress.
      f.content.updateShow(const PodcastSeries(
        id: 'signal-fire',
        name: 'Signal Fire',
        category: 'Design',
        publisher: 'Roman Mars',
        description: 'Design stories.',
        feedUrl: feedUrl,
        episodes: [
          PodcastEpisode(
            id: 'e100',
            podcastId: 'signal-fire',
            podcastName: 'Signal Fire',
            title: 'Ep 100',
            duration: Duration(minutes: 30),
            position: Duration(minutes: 5),
          ),
        ],
      ));
      f.feeds.serve(feedUrl, feedXml([item(guid: 'e100', title: 'Ep 100')]));

      final FeedRefreshResult result =
          await f.service.refresh(skeleton, force: true);

      expect(result.status, FeedRefreshStatus.noChanges);
      expect(result.show.episodes.single.position, const Duration(minutes: 5));
    });

    test('metadata changes update existing episodes in place', () async {
      final Fixture f = Fixture()
        ..feeds.serve(feedUrl, feedXml([item(guid: 'e100', title: 'Ep 100')]));

      await f.service.resolveForDisplay(skeleton);

      f.feeds.serve(feedUrl, feedXml([
        item(guid: 'e100', title: 'Ep 100 (extended)', duration: '44:00'),
      ]));
      final FeedRefreshResult result =
          await f.service.refresh(skeleton, force: true);

      expect(result.updatedCount, 1);
      expect(result.show.episodes, hasLength(1));
      expect(result.show.episodes.single.title, 'Ep 100 (extended)');
      expect(result.show.episodes.single.duration, const Duration(minutes: 44));
    });

    test('TEST 5 · network failure keeps cached podcast and episodes', () async {
      final Fixture f = Fixture()
        ..feeds.serve(feedUrl, feedXml([
          item(guid: 'e100', title: 'Ep 100'),
          item(guid: 'e99', title: 'Ep 99'),
        ]));

      f.saved.add('signal-fire');
      await f.service.resolveForDisplay(skeleton);
      final DateTime? lastGood = f.service.lastSuccessfulFetch('signal-fire');

      f.feeds.failNetwork(feedUrl);
      final FeedRefreshResult result =
          await f.service.refresh(skeleton, force: true);

      expect(result.status, FeedRefreshStatus.networkError);
      expect(result.show.episodes, hasLength(2)); // cached copy handed back
      expect(f.content.showById('signal-fire')!.episodes, hasLength(2));
      expect(f.service.lastSuccessfulFetch('signal-fire'), lastGood);
      expect(
        f.service.subscription('signal-fire')!.updateStatus,
        FeedRefreshStatus.networkError,
      );

      // Recovering works on the next attempt.
      f.feeds.heal(feedUrl);
      final FeedRefreshResult retry =
          await f.service.refresh(skeleton, force: true);
      expect(retry.status, FeedRefreshStatus.noChanges);
    });

    test('invalid RSS reports invalidFeed without crashing or wiping cache',
        () async {
      final Fixture f = Fixture()
        ..feeds.serve(feedUrl, feedXml([item(guid: 'e100', title: 'Ep 100')]));

      await f.service.resolveForDisplay(skeleton);
      f.feeds.failInvalid(feedUrl);

      final FeedRefreshResult result =
          await f.service.refresh(skeleton, force: true);

      expect(result.status, FeedRefreshStatus.invalidFeed);
      expect(result.show.episodes, hasLength(1));
      expect(f.content.showById('signal-fire')!.episodes, hasLength(1));
    });

    test('rate limiting skips very recent fetches; force bypasses', () async {
      final Fixture f = Fixture(minInterval: const Duration(minutes: 15))
        ..feeds.serve(feedUrl, feedXml([item(guid: 'e100', title: 'Ep 100')]));

      await f.service.resolveForDisplay(skeleton);
      final int fetchesAfterFirst = f.feeds.fetchCount;

      final FeedRefreshResult throttled = await f.service.refresh(skeleton);
      expect(throttled.status, FeedRefreshStatus.rateLimited);
      expect(throttled.fetched, isFalse);
      expect(f.feeds.fetchCount, fetchesAfterFirst);

      f.tick(const Duration(minutes: 16));
      final FeedRefreshResult stale = await f.service.refresh(skeleton);
      expect(stale.fetched, isTrue);
      expect(f.feeds.fetchCount, fetchesAfterFirst + 1);
    });

    test('resolveForDisplay serves the fresh cache without re-fetching',
        () async {
      final Fixture f = Fixture()
        ..feeds.serve(feedUrl, feedXml([item(guid: 'e100', title: 'Ep 100')]));

      await f.service.resolveForDisplay(skeleton);
      final int fetches = f.feeds.fetchCount;

      final PodcastSeries again = await f.service.resolveForDisplay(skeleton);
      expect(again.episodes, hasLength(1));
      expect(f.feeds.fetchCount, fetches);
    });

    test('TEST 6 · multiple followed podcasts keep independent sync state',
        () async {
      final Fixture f = Fixture();
      const String urlB = 'https://example.com/other.xml';
      const PodcastSeries skeletonB = PodcastSeries(
        id: 'other-show',
        name: 'Other Show',
        category: 'News',
        publisher: 'NPR',
        description: 'News.',
        feedUrl: urlB,
        episodes: [],
      );
      f.content.updateShow(skeletonB);
      f.saved.addAll({'signal-fire', 'other-show'});
      f.feeds.serve(feedUrl, feedXml([item(guid: 'e100', title: 'Ep 100')]));
      f.feeds.serve(urlB, '''
<?xml version="1.0"?>
<rss version="2.0"><channel><title>Other Show</title>
${item(guid: 'b1', title: 'Other Ep 1')}
</channel></rss>
''');

      final List<FeedRefreshResult> results = await f.service.refreshAll();

      expect(results, hasLength(2));
      expect(results.every((r) => r.ok), isTrue);
      expect(f.service.subscription('signal-fire')!.rssUrl, feedUrl);
      expect(f.service.subscription('other-show')!.rssUrl, urlB);
      expect(f.service.lastSuccessfulFetch('signal-fire'),
          isNotNull);
      expect(f.service.lastSuccessfulFetch('other-show'), isNotNull);

      // One show failing does not disturb the other.
      f.feeds.failNetwork(feedUrl);
      f.tick(const Duration(minutes: 16));
      final List<FeedRefreshResult> mixed = await f.service.refreshAll();
      expect(mixed.firstWhere((r) => r.show.id == 'signal-fire').status,
          FeedRefreshStatus.networkError);
      expect(mixed.firstWhere((r) => r.show.id == 'other-show').ok, isTrue);
    });

    test('TEST 7 · unfollowing retires the subscription but keeps cache',
        () async {
      final Fixture f = Fixture()
        ..feeds.serve(feedUrl, feedXml([item(guid: 'e100', title: 'Ep 100')]));

      f.saved.add('signal-fire');
      await f.service.resolveForDisplay(skeleton);
      expect(f.service.subscription('signal-fire'), isNotNull);

      f.saved.remove('signal-fire');
      expect(f.service.subscription('signal-fire'), isNull);
      expect(f.service.subscriptions, isEmpty);

      final int fetches = f.feeds.fetchCount;
      await f.service.refreshAll();
      expect(f.feeds.fetchCount, fetches); // no longer polled

      // Cached episodes are user data; unfollowing must not destroy them.
      expect(f.content.showById('signal-fire')!.episodes, hasLength(1));
    });

    test('discovery never subscribes: unsaved shows refresh without a subscription',
        () async {
      final Fixture f = Fixture()
        ..feeds.serve(feedUrl, feedXml([item(guid: 'e100', title: 'Ep 100')]));

      final FeedRefreshResult result =
          await f.service.refresh(skeleton, force: true);

      expect(result.ok, isTrue);
      expect(f.service.subscription('signal-fire'), isNull);
      expect(f.service.subscriptions, isEmpty);
    });

    test('subscription records lastFetchedAt/lastSuccessfulFetchAt distinctly',
        () async {
      final Fixture f = Fixture()
        ..feeds.serve(feedUrl, feedXml([item(guid: 'e100', title: 'Ep 100')]));

      f.saved.add('signal-fire');
      await f.service.resolveForDisplay(skeleton);
      final PodcastSubscription ok = f.service.subscription('signal-fire')!;
      expect(ok.lastFetchedAt, startTime);
      expect(ok.lastSuccessfulFetchAt, startTime);
      expect(ok.lastKnownEpisodeKey, 'guid:e100');

      f.feeds.failNetwork(feedUrl);
      f.tick(const Duration(minutes: 1));
      // Force bypasses rate limiting so the failed attempt actually runs.
      await f.service.refresh(skeleton, force: true);
      final PodcastSubscription failed = f.service.subscription('signal-fire')!;
      expect(failed.lastFetchedAt, startTime.add(const Duration(minutes: 1)));
      expect(failed.lastSuccessfulFetchAt, startTime);
    });
  });
}
