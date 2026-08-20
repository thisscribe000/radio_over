import '../models/podcast_episode.dart';
import '../models/station.dart';

/// The kind of audio content a search result points at. Drives routing on tap.
enum SearchResultType {
  radioStation('Radio'),
  podcast('Podcast'),
  episode('Episode');

  const SearchResultType(this.label);

  final String label;
}

/// A single unified hit from global search.
///
/// Search is deliberately not split into "radio search" and "podcast search":
/// every hit is the same [SearchResult], and the presentation layer chooses
/// artwork, indicator and route from the concrete subclass.
sealed class SearchResult {
  const SearchResult({
    required this.id,
    required this.rank,
    required this.title,
    required this.artworkTitle,
    this.subtitle,
    this.metadata = const [],
  });

  /// Stable identifier used for finder keys, e.g. "BBC World Service".
  final String id;

  /// Lower is better; drives ordering inside a section.
  final int rank;

  final String title;

  /// The string the artwork/monogram is derived from.
  final String artworkTitle;

  /// Secondary line, e.g. current programme or publisher.
  final String? subtitle;

  /// Quiet type indicator tokens, e.g. category/country/publisher.
  final List<String> metadata;

  SearchResultType get type;
}

/// A radio station hit, carrying the real [RadioStation] so playback can
/// hand it straight to the existing [PlaybackController].
class StationResult extends SearchResult {
  StationResult({required super.rank, required this.station})
      : super(
          id: station.name,
          title: station.name,
          artworkTitle: station.name,
          subtitle: station.program,
          metadata: [
            station.category.toUpperCase(),
            if (station.country != null) station.country!.toUpperCase(),
          ],
        );

  final RadioStation station;

  @override
  SearchResultType get type => SearchResultType.radioStation;
}

/// A podcast show hit, carrying the real [PodcastSeries] so it can route to
/// the existing Podcast Detail screen.
class PodcastResult extends SearchResult {
  PodcastResult({required super.rank, required this.show})
      : super(
          id: show.id,
          title: show.name,
          artworkTitle: show.name,
          subtitle: show.publisher,
          metadata: [show.category.toUpperCase()],
        );

  final PodcastSeries show;

  @override
  SearchResultType get type => SearchResultType.podcast;
}

/// An episode hit, carrying the real [PodcastEpisode].
class EpisodeResult extends SearchResult {
  EpisodeResult({required super.rank, required this.episode})
      : super(
          id: episode.id,
          title: episode.title,
          artworkTitle: episode.podcastName,
          subtitle: episode.podcastName,
          metadata: [episode.podcastName.toUpperCase()],
        );

  final PodcastEpisode episode;

  @override
  SearchResultType get type => SearchResultType.episode;
}