import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/data/podcasts/opml_service.dart';
import 'package:radio_over/models/podcast_episode.dart';

void main() {
  group('OpmlService Tests', () {
    test('exportOpml generates standard OPML 2.0 XML with outline tags', () {
      final List<PodcastSeries> shows = [
        const PodcastSeries(
          id: 'show-1',
          name: 'The Daily Tech',
          category: 'Technology',
          publisher: 'Tech Media',
          description: 'Daily tech news',
          feedUrl: 'https://example.com/daily-tech.xml',
          episodes: [],
        ),
        const PodcastSeries(
          id: 'show-2',
          name: 'Science Hour',
          category: 'Science',
          publisher: 'Lab World',
          description: 'Weekly science exploration',
          feedUrl: 'https://example.com/science.xml',
          episodes: [],
        ),
      ];

      final String opml = OpmlService.exportOpml(shows: shows, title: 'My Subscriptions');

      expect(opml, contains('<opml version="2.0">'));
      expect(opml, contains('<title>My Subscriptions</title>'));
      expect(opml, contains('text="The Daily Tech"'));
      expect(opml, contains('xmlUrl="https://example.com/daily-tech.xml"'));
      expect(opml, contains('text="Science Hour"'));
      expect(opml, contains('xmlUrl="https://example.com/science.xml"'));
    });

    test('parseOpml extracts feeds from valid OPML XML string', () {
      const String sampleOpml = '''<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
  <head>
    <title>Exported Feeds</title>
  </head>
  <body>
    <outline text="Podcasts" title="Podcasts">
      <outline type="rss" text="Hard Fork" title="Hard Fork" xmlUrl="https://feeds.simplecast.com/hardfork" htmlUrl="https://nytimes.com/hardfork" />
      <outline type="rss" text="Syntax" title="Syntax" xmlUrl="https://feed.syntax.fm/rss" />
    </outline>
  </body>
</opml>''';

      final List<OpmlFeed> feeds = OpmlService.parseOpml(sampleOpml);

      expect(feeds.length, 2);
      expect(feeds[0].title, 'Hard Fork');
      expect(feeds[0].feedUrl, 'https://feeds.simplecast.com/hardfork');
      expect(feeds[0].htmlUrl, 'https://nytimes.com/hardfork');

      expect(feeds[1].title, 'Syntax');
      expect(feeds[1].feedUrl, 'https://feed.syntax.fm/rss');
    });

    test('parseOpml returns empty list on empty or invalid XML', () {
      expect(OpmlService.parseOpml(''), isEmpty);
      expect(OpmlService.parseOpml('<not-opml>'), isEmpty);
      expect(OpmlService.parseOpml('invalid garbage text'), isEmpty);
    });
  });
}
