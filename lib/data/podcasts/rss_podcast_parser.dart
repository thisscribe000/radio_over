import 'package:xml/xml.dart';

import '../../models/podcast_episode.dart';

/// Parses RSS 2.0 podcast feeds (with iTunes extensions) into a [PodcastSeries].
///
/// Deliberately forgiving: feeds that omit optional bits (<itunes:*>, enclosures
/// with no audio, channel images, etc.) still produce a runnable series. The
/// only hard requirement is a `<channel>` with a `<title>`.
class RssPodcastParser {
  const RssPodcastParser();

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Parses [xmlString] into a series. Empty-string fields fall back to the
  /// preferred values so a directory hit and its feed converge on one identity.
  PodcastSeries parseFeed(
    String xmlString, {
    String? preferredId,
    String? preferredName,
    String? preferredAuthor,
    String? preferredImageUrl,
  }) {
    final XmlDocument document = XmlDocument.parse(xmlString);
    final List<XmlElement> channels = document.findAllElements('channel').toList();
    if (channels.isEmpty) {
      throw const FormatException('Not an RSS feed: missing <channel>');
    }
    final XmlElement channel = channels.first;

    final String title = _nonEmptyTrim(_text(channel, 'title')) ?? preferredName ?? 'Untitled podcast';
    final String author = _firstText(channel, ['itunes:author', 'author']) ?? preferredAuthor ?? _textParent(channel);
    final String? channelImage = _attr(channel, 'itunes:image', 'href') ?? _childText(channel, 'image', 'url');
    final String? categoryRaw = _attr(channel, 'itunes:category', 'text') ?? _text(channel, 'category');
    final String category = (categoryRaw == null || categoryRaw.isEmpty)
        ? 'Podcast'
        : _categoryFromDescription(categoryRaw);
    final String? description = _nonEmptyTrim(_text(channel, 'description'));

    final List<PodcastEpisode> episodes = <PodcastEpisode>[
      for (final XmlElement item in channel.findAllElements('item'))
        if (item != channel.parent)
          _parseEpisode(item, seriesId: _slugId(title), seriesName: title),
    ];

    return PodcastSeries(
      id: (preferredId?.isNotEmpty ?? false) ? preferredId! : _slugId(title),
      name: title,
      category: category,
      publisher: author.isEmpty ? 'Unknown' : author,
      description: description ?? '',
      imageUrl: preferredImageUrl?.isNotEmpty == true || (channelImage?.isNotEmpty ?? false) ? preferredImageUrl ?? channelImage : null,
      feedAuthor: author.isEmpty ? null : author,
      episodes: episodes,
    );
  }

  PodcastEpisode _parseEpisode(XmlElement item, {required String seriesId, required String seriesName}) {
    final String? title = _text(item, 'title');
    final String? enclosureUrl = _attr(item, 'enclosure', 'url');
    final String? guid = _firstText(item, ['guid']) ?? enclosureUrl;
    final Duration duration = _parseDuration(_text(item, 'itunes:duration') ?? _text(item, 'duration') ?? '');
    final String? image = _attr(item, 'itunes:image', 'href') ?? _text(item, 'itunes:image');
    final String? publishedRaw = _text(item, 'pubDate') ?? _text(item, 'dc:date');

    final String id = (guid?.isNotEmpty ?? false) ? guid! : _slugId(title ?? 'episode');
    final String episodeTitle = title ?? 'Untitled episode';

    return PodcastEpisode(
      id: id,
      podcastId: seriesId,
      podcastName: seriesName,
      title: episodeTitle,
      duration: duration,
      published: _formatPublished(publishedRaw),
      about: _text(item, 'description')?.trim(),
      audioUrl: (enclosureUrl == null || enclosureUrl.isEmpty) ? null : enclosureUrl,
      guid: guid,
      imageUrl: (image == null || image.isEmpty) ? null : image,
    );
  }

  // --- low-level helpers ------------------------------------------------

  String? _text(XmlElement parent, String name) {
    final XmlElement? element = parent.getElement(name);
    if (element == null) return null;
    return element.innerText;
  }

  /// First non-empty match across names (handles `<author>` vs `<itunes:author>`).
  String? _firstText(XmlElement parent, List<String> names) {
    for (final String name in names) {
      for (final XmlElement element in parent.findElements(name)) {
        final String value = element.innerText.trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  /// Author fallback: the channel's own `author`-lookalike text when neither
  /// itunes nor publisher attributes are set.
  String _textParent(XmlElement channel) {
    final String? editor = _text(channel, 'managingEditor')?.trim();
    if ((editor?.isNotEmpty ?? false)) return editor!;
    return _attr(channel, 'itunes:owner', 'name') ?? '';
  }

  String? _attr(XmlElement parent, String name, String attribute) {
    final XmlElement? element = parent.getElement(name);
    if (element == null) return null;
    final String? value = element.getAttribute(attribute);
    return (value == null || value.isEmpty) ? null : value;
  }

  String? _childText(XmlElement parent, String elementName, String childName) {
    final XmlElement? element = parent.getElement(elementName);
    if (element == null) return null;
    final XmlElement? child = element.getElement(childName);
    if (child == null) return null;
    final String value = child.innerText.trim();
    return value.isEmpty ? null : value;
  }

  static String? _nonEmptyTrim(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _categoryFromDescription(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return 'Podcast';
    return value.split(RegExp(r'[\s>]')).where((w) => w.isNotEmpty).first;
  }

  static String _slugId(String value) {
    final String slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'podcast' : slug;
  }

  /// Parses iTunes-style durations: "3735", "93", "1:02:33", "2:30", or "0:45".
  /// Unparseable values fall back to zero.
  static Duration _parseDuration(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) return Duration.zero;
    if (!value.contains(':')) {
      final int? seconds = int.tryParse(value);
      return seconds == null ? Duration.zero : Duration(seconds: seconds);
    }
    final List<String> parts = value.split(':');
    if (parts.length == 2) {
      final int? minutes = int.tryParse(parts[0]);
      final int? seconds = int.tryParse(parts[1]);
      if (minutes == null || seconds == null) return Duration.zero;
      return Duration(minutes: minutes, seconds: seconds);
    }
    if (parts.length >= 3) {
      final int? hours = int.tryParse(parts[0]);
      final int? minutes = int.tryParse(parts[1]);
      final int? seconds = int.tryParse(parts[2]);
      if (hours == null || minutes == null || seconds == null) return Duration.zero;
      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    }
    return Duration.zero;
  }

  /// RFC 822 pubDate → "Aug 18" display string matching the mock catalogue.
  static String? _formatPublished(String? raw) {
    if (raw == null) return null;
    final DateTime? date = _parseRfc822(raw);
    if (date == null) return null;
    return '${_months[date.month - 1]} ${date.day}';
  }

  /// Parses standard feed dates like "Tue, 18 Aug 2026 09:30:00 +0000".
  /// Handles a leading weekday, optional seconds, and numeric/GMT offsets.
  static DateTime? _parseRfc822(String value) {
    final Match? match = RegExp(
      r'^(?:[A-Za-z]{3},?\s+)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{2,4})\s*'
      r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(?:([A-Za-z0-9+\-]+))?$',
    ).firstMatch(value.trim());
    if (match == null) return null;
    final int? day = int.tryParse(match.group(1)!);
    final int? month = _monthFromName(match.group(2)!);
    final int year = (int.tryParse(match.group(3)!) ?? 0) < 100
        ? (int.tryParse(match.group(3)!) ?? 0) + 2000
        : (int.tryParse(match.group(3)!) ?? 0);
    final int? hour = int.tryParse(match.group(4)!);
    final int? minute = int.tryParse(match.group(5)!);
    final int second = int.tryParse(match.group(6) ?? '0') ?? 0;
    if (day == null || month == null || hour == null || minute == null) {
      return null;
    }
    int offsetMinutes = 0;
    final String? zone = match.group(7);
    if (zone != null && zone != 'GMT' && zone != 'UT') {
      final Match? zoneMatch = RegExp(r'^([+-])(\d{2})(\d{2})$').firstMatch(zone);
      if (zoneMatch != null) {
        final int hours = int.parse(zoneMatch.group(2)!);
        final int minutes = int.parse(zoneMatch.group(3)!);
        offsetMinutes = (hours * 60 + minutes) * (zoneMatch.group(1) == '-' ? -1 : 1);
      }
    }
    return DateTime.utc(year, month, day, hour, minute, second)
        .subtract(Duration(minutes: offsetMinutes))
        .toLocal();
  }

  static int? _monthFromName(String name) {
    const List<String> names = [
      'jan', 'feb', 'mar', 'apr', 'may', 'jun',
      'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
    ];
    final int index = names.indexOf(name.toLowerCase());
    return index == -1 ? null : index + 1;
  }
}