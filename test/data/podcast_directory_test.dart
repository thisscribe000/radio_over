import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radio_over/data/podcasts/mock_podcast_directory_repository.dart';
import 'package:radio_over/data/podcasts/podcast_directory_repository.dart';
import 'package:radio_over/data/podcasts/podcast_index_directory_repository.dart';
import 'package:radio_over/data/podcasts/podcast_feed_repository.dart';
import 'package:radio_over/models/podcast_episode.dart';

void main() {
  group('PodcastSearchHit', () {
    test('toSeries builds a runnable skeleton with a stable id', () {
      const PodcastSearchHit hit = PodcastSearchHit(
        title: 'The Morning Show',
        author: 'Acme Studios',
        feedUrl: 'https://acme/morning.xml',
        directoryId: 'acme-7',
        categories: ['News'],
      );
      final PodcastSeries series = hit.toSeries();
      expect(series.id, 'acme-7');
      expect(series.name, 'The Morning Show');
      expect(series.category, 'News');
      expect(series.feedUrl, 'https://acme/morning.xml');
      expect(series.episodes, isEmpty);
    });

    test('falls back to a slug id and generic category', () {
      const PodcastSearchHit hit = PodcastSearchHit(title: 'NPR News Now', author: '');
      final PodcastSeries series = hit.toSeries();
      expect(series.id, 'npr-news-now');
      expect(series.category, 'Podcast');
      expect(series.publisher, 'Unknown');
    });
  });

  group('MockPodcastDirectoryRepository', () {
    const MockPodcastDirectoryRepository repo = MockPodcastDirectoryRepository();

    test('searches the curated catalogue by title', () async {
      final List<PodcastSearchHit> hits = await repo.search('serial');
      expect(hits, isNotEmpty);
      expect(hits.first.title, 'Serial');
      expect(hits.first.feedUrl, isNull); // mocks have no feed to follow
    });
  });

  group('PodcastIndexDirectoryRepository', () {
    test('throws CredentialsNotConfigured when keys are absent', () {
      final PodcastIndexDirectoryRepository repo = PodcastIndexDirectoryRepository(
        key: '',
        secret: '',
      );
      expect(
        () => repo.search('news'),
        throwsA(isA<CredentialsNotConfigured>()),
      );
    });

    test('sends signed headers and decodes a feed list', () async {
      Map<String, String>? headers;
      final http.Client client = MockClient((http.Request request) async {
        headers = request.headers;
        final String body = '{"feeds":[{"id":1,"title":"The Daily","author":"NYT",'
            '"description":"News you need.","image":"https://nyt/art.png",'
            '"url":"https://nyt/feed.xml","categories":{"1":"News"}}]}';
        return http.Response(body, 200);
      });
      final PodcastIndexDirectoryRepository repo = PodcastIndexDirectoryRepository(
        client: client,
        key: 'k1',
        secret: 's1',
      );

      final List<PodcastSearchHit> hits = await repo.search('daily');
      expect(headers!['X-Auth-Key'], 'k1');
      expect(headers!['Authorization'], isNotEmpty);
      expect(headers!['X-Auth-Date'], isNotEmpty);
      expect(hits, hasLength(1));
      expect(hits.first.title, 'The Daily');
      expect(hits.first.author, 'NYT');
      expect(hits.first.categories, ['News']);
      expect(hits.first.feedUrl, 'https://nyt/feed.xml');
      expect(hits.first.directoryId, '1');
    });
  });

  group('RssPodcastFeedRepository', () {
    const String feedBody = '''
<?xml version="1.0"?>
<rss version="2.0"><channel>
<title>Signal Fire</title><description>Design stories.</description>
<itunes:author xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">Roman Mars</itunes:author>
<item>
  <title>Ep 1</title>
  <guid>sf-1</guid>
  <itunes:duration>10:00</itunes:duration>
  <enclosure url="https://audio/1.mp3" type="audio/mpeg"/>
</item>
</channel></rss>
''';

    test('fetches and parses a feed end to end', () async {
      String? requested;
      final http.Client client = MockClient((http.Request request) async {
        requested = request.url.toString();
        return http.Response(feedBody, 200);
      });
      final PodcastFeedRepository repo = RssPodcastFeedRepository(client: client);

      final PodcastSeries series = await repo.feed('https://example/feed.xml');
      expect(requested, 'https://example/feed.xml');
      expect(series.name, 'Signal Fire');
      expect(series.episodes.single.audioUrl, 'https://audio/1.mp3');
      expect(series.episodes.single.guid, 'sf-1');
    });

    test('surfaces a bad feed status', () async {
      final http.Client client = MockClient((request) async => http.Response('nope', 404));
      final PodcastFeedRepository repo = RssPodcastFeedRepository(client: client);
      expect(
        () => repo.feed('https://example/missing.xml'),
        throwsA(isA<Exception>()),
      );
    });
  });
}