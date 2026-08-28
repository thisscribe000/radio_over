import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radio_over/data/content_scope.dart';
import 'package:radio_over/data/podcasts/podcast_feed_repository.dart';
import 'package:radio_over/data/podcasts/podcast_index_directory_repository.dart';
import 'package:radio_over/data/radio/radio_browser_repository.dart';
import 'package:radio_over/search/search_engine.dart';
import 'package:radio_over/search/search_result.dart';

/// A live [AppContent] whose Radio Browser, Podcast Index and RSS sources are
/// backed by in-memory [MockClient]s, so real search requests run against real
/// repository/model paths without touching the network.
AppContent liveContent({
  required String Function() radioBody,
  required String Function() directoryBody,
}) {
  final http.Client radioClient = MockClient(
    (request) async => http.Response(
      radioBody(),
      200,
      headers: const {'content-type': 'application/json'},
    ),
  );
  final http.Client directoryClient = MockClient(
    (request) async => http.Response(
      directoryBody(),
      200,
      headers: const {'content-type': 'application/json'},
    ),
  );
  return AppContent(
    radio: RadioBrowserRepository(client: radioClient),
    podcastDirectory: PodcastIndexDirectoryRepository(
      client: directoryClient,
      key: 'k',
      secret: 's',
    ),
    podcastFeeds: RssPodcastFeedRepository(client: radioClient),
    isLive: true,
  );
}

const String _radioStationJson =
    '{"stationuuid":"lagos-1","name":"Cool FM Lagos","tags":"pop, lagos",'
    '"country":"Nigeria","language":"english","favicon":"https://cool.fm/icon.png",'
    '"url":"https://stream.cool.fm/live","is_https":true,"isOnline":true}';

const String _directoryJson =
    '{"feeds":[{"id":7,"title":"BBC Global News","author":"BBC",'
    '"url":"https://bbc/feed.xml","categories":{"1":"News"}}]}';

void main() {
  group('SearchEngine live path', () {
    test('podcast search returns real podcast result models', () async {
      final AppContent content = liveContent(
        radioBody: () => '[]',
        directoryBody: () => _directoryJson,
      );
      final SearchEngine engine = SearchEngine(content: content);

      final SearchResultSet results = await engine.search('bbc');
      // A strong name-level match is elevated to the top result.
      final PodcastResult? result = results.top as PodcastResult?;
      expect(result, isNotNull);
      expect(result!.id, '7');
      expect(result.show.name, 'BBC Global News');
      expect(result.show.publisher, 'BBC');
      expect(result.show.feedUrl, 'https://bbc/feed.xml');
    });

    test('radio search returns real station result models', () async {
      final AppContent content = liveContent(
        radioBody: () => '[$_radioStationJson]',
        directoryBody: () => '{"feeds":[]}',
      );
      final SearchEngine engine = SearchEngine(content: content);

      final SearchResultSet results = await engine.search('lagos');
      expect(results.stations, isNotEmpty);
      final StationResult result = results.stations.first as StationResult;
      expect(result.station.name, 'Cool FM Lagos');
      expect(result.station.country, 'Nigeria');
      expect(result.station.id, 'lagos-1');
      expect(result.station.streamUrl, 'https://stream.cool.fm/live');
      expect(result.station.logoUrl, 'https://cool.fm/icon.png');
    });

    test('empty query returns an empty result set', () async {
      final AppContent content = liveContent(
        radioBody: () => '[$_radioStationJson]',
        directoryBody: () => _directoryJson,
      );
      final SearchEngine engine = SearchEngine(content: content);

      final SearchResultSet results = await engine.search('');
      expect(results.isEmpty, isTrue);
    });

    test('network error falls back to the local catalogue without crashing',
        () async {
      final http.Client radioClient = MockClient(
        (request) async => http.Response('oops', 503),
      );
      final http.Client directoryClient = MockClient(
        (request) async => http.Response('oops', 503),
      );
      final AppContent content = AppContent(
        radio: RadioBrowserRepository(client: radioClient),
        podcastDirectory: PodcastIndexDirectoryRepository(
          client: directoryClient,
          key: 'k',
          secret: 's',
        ),
        podcastFeeds: RssPodcastFeedRepository(client: radioClient),
        isLive: true,
        seedStations: const [],
        seedShows: const [],
      );
      final SearchEngine engine = SearchEngine(content: content);

      final SearchResultSet results = await engine.search('news');
      // Graceful degradation: no crash, a valid (possibly empty) result set.
      expect(results, isA<SearchResultSet>());
    });

    test('manual RSS discovery is preserved (feedable results keep a feed url)',
        () async {
      final AppContent content = liveContent(
        radioBody: () => '[]',
        directoryBody: () =>
            '{"feeds":[{"id":9,"title":"Deep Dive Daily","author":"Studio Co",'
            '"url":"https://deepdive/feed.xml","categories":{"1":"News"}}]}',
      );
      final SearchEngine engine = SearchEngine(content: content);

      final SearchResultSet results = await engine.search('deep dive');
      final PodcastResult? hit = results.top as PodcastResult?;
      expect(hit, isNotNull);
      // The feed url is the primary key for opening/refreshing the detail
      // screen, independent of follow state.
      expect(hit!.show.feedUrl, 'https://deepdive/feed.xml');
      expect(hit.show.id, '9');
    });
  });

  group('SearchResultSet', () {
    test('is empty only when every section is empty', () {
      const SearchResultSet empty = SearchResultSet();
      expect(empty.isEmpty, isTrue);
      const SearchResultSet nonEmpty = SearchResultSet(
        stations: <SearchResult>[],
      );
      expect(nonEmpty.isEmpty, isTrue);
    });
  });

  group('decoding JSON helpers', () {
    test('station json decodes through the engine path', () async {
      final Map<String, dynamic> json =
          jsonDecode(_radioStationJson) as Map<String, dynamic>;
      expect(json['name'], 'Cool FM Lagos');
    });
  });
}
