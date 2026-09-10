import 'package:xml/xml.dart';
import '../../models/podcast_episode.dart';

/// Represents a podcast feed item parsed from an OPML document.
class OpmlFeed {
  const OpmlFeed({
    required this.title,
    required this.feedUrl,
    this.htmlUrl,
    this.description,
  });

  final String title;
  final String feedUrl;
  final String? htmlUrl;
  final String? description;
}

/// Universal OPML 2.0 import and export service for podcast subscriptions.
class OpmlService {
  /// Generates a standard OPML 2.0 XML string from a list of subscribed [shows].
  static String exportOpml({
    required List<PodcastSeries> shows,
    String title = 'Radio Over Subscriptions',
  }) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('opml', attributes: {'version': '2.0'}, nest: () {
      builder.element('head', nest: () {
        builder.element('title', nest: () {
          builder.text(title);
        });
        builder.element('dateCreated', nest: () {
          builder.text(DateTime.now().toUtc().toIso8601String());
        });
      });
      builder.element('body', nest: () {
        for (final show in shows) {
          final String? feed = show.feedUrl;
          if (feed != null && feed.trim().isNotEmpty) {
            builder.element('outline', attributes: {
              'text': show.name,
              'title': show.name,
              'type': 'rss',
              'xmlUrl': feed.trim(),
            });
          }
        }
      });
    });

    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Parses an OPML XML string and extracts all podcast RSS feeds.
  ///
  /// Supports flat and hierarchically nested outline trees.
  static List<OpmlFeed> parseOpml(String xmlString) {
    if (xmlString.trim().isEmpty) return const [];
    try {
      final document = XmlDocument.parse(xmlString);
      final List<OpmlFeed> feeds = [];

      // Find all outline elements that specify an RSS feed
      for (final outline in document.findAllElements('outline')) {
        final String? xmlUrl = outline.getAttribute('xmlUrl') ??
            outline.getAttribute('url') ??
            outline.getAttribute('xmlurl');

        if (xmlUrl != null && xmlUrl.trim().isNotEmpty) {
          final String title = outline.getAttribute('title') ??
              outline.getAttribute('text') ??
              'Untitled Podcast';
          final String? htmlUrl = outline.getAttribute('htmlUrl') ??
              outline.getAttribute('htmlurl');
          final String? description = outline.getAttribute('description');

          feeds.add(
            OpmlFeed(
              title: title.trim(),
              feedUrl: xmlUrl.trim(),
              htmlUrl: htmlUrl?.trim(),
              description: description?.trim(),
            ),
          );
        }
      }
      return feeds;
    } on XmlException {
      return const [];
    }
  }
}
