import '../../models/podcast_episode.dart';

export '../radio/radio_repository.dart' show ContentSourceException;

/// A lightweight search result from a podcast directory. Kept deliberately
/// small: a hit only carries what a search list needs. The full show (with
/// episodes) is resolved from its feed via [PodcastFeedRepository].
class PodcastSearchHit {
  const PodcastSearchHit({
    required this.title,
    required this.author,
    this.description,
    this.categories = const [],
    this.imageUrl,
    this.feedUrl,
    this.directoryId,
  });

  final String title;
  final String author;
  final String? description;
  final List<String> categories;
  final String? imageUrl;

  /// Absolute RSS feed URL; the primary key for resolving a full series.
  final String? feedUrl;

  /// Stable id assigned by the directory, for dedupe/refine by directory.
  final String? directoryId;

  /// Primary category label, derived like the radio category fallback.
  String get primaryCategory => categories.isNotEmpty ? categories.first : 'Podcast';

  /// Builds a runnable [PodcastSeries] skeleton from the hit before the feed
  /// resolves. Episodes are absent until [PodcastFeedRepository.feed] runs.
  PodcastSeries toSeries() {
    return PodcastSeries(
      id: directoryId ?? _slugId(title),
      name: title,
      category: primaryCategory,
      publisher: author.isEmpty ? 'Unknown' : author,
      description: description ?? '',
      imageUrl: imageUrl,
      feedUrl: feedUrl,
      episodes: const [],
    );
  }

  static String _slugId(String value) {
    final String slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'podcast' : slug;
  }
}

/// Contract for a remote podcast directory/search: finds shows, never a feed.
abstract class PodcastDirectoryRepository {
  /// Shows whose title matches [query], most relevant first.
  Future<List<PodcastSearchHit>> search(String query, {int limit = 25});

  /// Curated/popular shows for the home screen.
  Future<List<PodcastSearchHit>> popular({int limit = 25});
}