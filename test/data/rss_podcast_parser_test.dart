import 'package:flutter_test/flutter_test.dart';
import 'package:radio_over/data/podcasts/rss_podcast_parser.dart';
import 'package:radio_over/models/podcast_episode.dart';

String _feed([String extraItems = '']) => '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
<channel>
  <title>Signal Fire</title>
  <link>https://example.com/signalfire</link>
  <description>Design is everywhere in our lives.</description>
  <language>en-us</language>
  <itunes:author>Roman Mars</itunes:author>
  <itunes:category text="Design"/>
  <itunes:image href="https://example.com/art.jpg"/>
  <item>
    <title>Ep 101: The Secret Lives of Airport Codes</title>
    <itunes:image href="https://example.com/ep101.jpg"/>
    <guid>signal-fire-101</guid>
    <pubDate>Tue, 18 Aug 2026 09:30:00 +0000</pubDate>
    <itunes:duration>38:45</itunes:duration>
    <enclosure url="https://example.com/audio/101.mp3" type="audio/mpeg" length="12345"/>
    <description>A surprisingly contested history of the airport code.</description>
  </item>
  <item>
    <title>Ep 100: The Great Banyan Tree</title>
    <guid isPermaLink="false">https://example.com/100</guid>
    <pubDate>Mon, 17 Aug 2026 08:00:00 +0000</pubDate>
    <itunes:duration>90</itunes:duration>
    <enclosure url="https://example.com/audio/100.mp3" type="audio/mpeg"/>
    <description>A single tree that became a city landmark.</description>
  </item>
  $extraItems
</channel>
</rss>
''';

void main() {
  const RssPodcastParser parser = RssPodcastParser();

  group('RssPodcastParser', () {
    test('parses a full feed into a usable series', () {
      final PodcastSeries series = parser.parseFeed(_feed());

      expect(series.name, 'Signal Fire');
      expect(series.publisher, 'Roman Mars');
      expect(series.category, 'Design');
      expect(series.description, contains('Design is everywhere'));
      expect(series.imageUrl, 'https://example.com/art.jpg');
      expect(series.id, 'signal-fire');

      expect(series.episodes, hasLength(2));
      final PodcastEpisode first = series.episodes.first;
      expect(first.id, 'signal-fire-101');
      expect(first.guid, 'signal-fire-101');
      expect(first.title, 'Ep 101: The Secret Lives of Airport Codes');
      expect(first.audioUrl, 'https://example.com/audio/101.mp3');
      expect(first.duration, const Duration(minutes: 38, seconds: 45));
      expect(first.imageUrl, 'https://example.com/ep101.jpg');
      expect(first.about, contains('airport code'));
      expect(first.podcastId, 'signal-fire');
      expect(first.podcastName, 'Signal Fire');
    });

    test('converts pubDate to the app display style', () {
      final PodcastSeries series = parser.parseFeed(_feed());
      final DateTime local = DateTime.utc(2026, 8, 18).toLocal();
      const List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      expect(series.episodes.first.published, '${months[local.month - 1]} ${local.day}');
      final DateTime local2 = DateTime.utc(2026, 8, 17).toLocal();
      expect(series.episodes[1].published, '${months[local2.month - 1]} ${local2.day}');
    });

    test('parses second-only and H:MM:SS durations', () {
      final PodcastSeries series = parser.parseFeed('''
<?xml version="1.0"?>
<rss version="2.0"><channel>
<title>Durations</title><description>d</description>
<item>
  <title>One</title><itunes:duration>90</itunes:duration>
  <enclosure url="https://e/1.mp3"/>
</item>
<item>
  <title>Two</title><itunes:duration>1:02:33</itunes:duration>
  <enclosure url="https://e/2.mp3"/>
</item>
<item>
  <title>Three</title><itunes:duration>2:30</itunes:duration>
  <enclosure url="https://e/3.mp3"/>
</item>
</channel></rss>
''');
      expect(series.episodes[0].duration, const Duration(seconds: 90));
      expect(series.episodes[1].duration, const Duration(hours: 1, minutes: 2, seconds: 33));
      expect(series.episodes[2].duration, const Duration(minutes: 2, seconds: 30));
    });

    test('is forgiving of missing optional fields', () {
      final PodcastSeries series = parser.parseFeed('''
<?xml version="1.0"?>
<rss version="2.0"><channel>
<title>Bare Min</title>
<item><title>Loose Episode</title></item>
</channel></rss>
''');

      expect(series.name, 'Bare Min');
      expect(series.category, 'Podcast');
      expect(series.publisher, 'Unknown');
      expect(series.imageUrl, isNull);
      expect(series.episodes, hasLength(1));
      final PodcastEpisode episode = series.episodes.single;
      expect(episode.id, 'loose-episode');
      expect(episode.audioUrl, isNull);
      expect(episode.guid, isNull);
      expect(episode.duration, Duration.zero);
      expect(episode.published, isNull);
    });

    test('honours preferred identity fields from a directory hit', () {
      final PodcastSeries series = parser.parseFeed(
        _feed(),
        preferredId: 'dir-42',
        preferredName: 'Signal Fire (HQ)',
        preferredImageUrl: 'https://dir/art.png',
      );
      expect(series.id, 'dir-42');
      expect(series.name, 'Signal Fire');
      expect(series.imageUrl, 'https://dir/art.png');
      expect(series.episodes.first.podcastName, 'Signal Fire');
    });

    test('throws a FormatException for non-RSS input', () {
      expect(
        () => parser.parseFeed('<html><body>not a feed</body></html>'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}