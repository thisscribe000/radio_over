import '../models/podcast_episode.dart';
import '../models/station.dart';
import 'search_result.dart';

/// Parsed, ranked and grouped results for one query.
class SearchResultSet {
  const SearchResultSet({
    this.top,
    this.stations = const [],
    this.podcasts = const [],
    this.episodes = const [],
  });

  /// The single strongest name-level match (station or podcast), if any.
  final SearchResult? top;

  final List<SearchResult> stations;
  final List<SearchResult> podcasts;
  final List<SearchResult> episodes;

  bool get isEmpty =>
      top == null && stations.isEmpty && podcasts.isEmpty && episodes.isEmpty;
}

/// Pure catalogue search. No UI and no playback: given a query it returns the
/// unified hit set across radio and podcasts, so a real backend can replace
/// [search] later without changing the presentation layer.
class SearchEngine {
  const SearchEngine();

  /// Popular searches/content categories for the discovery state.
  static const List<String> trending = [
    'The Daily',
    'BBC World Service',
    'Jazz',
    'True crime',
    'Design',
  ];

  /// Suggested terms for the no-results state.
  static const List<String> fallbackSuggestions = [
    'News',
    'Technology',
    'Business',
    'Gospel',
    'Sports',
  ];

  static const int _maxStations = 4;
  static const int _maxPodcasts = 4;
  static const int _maxEpisodes = 5;

  SearchResultSet search(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return const SearchResultSet();

    final List<StationResult> stations = [];
    for (final RadioStation station in mockStations) {
      final int score = _scoreAll(
        [station.name, station.program, station.category, station.country],
        q,
      );
      if (score >= 0) stations.add(StationResult(rank: score, station: station));
    }

    final List<PodcastResult> podcasts = [];
    for (final PodcastSeries show in mockPodcasts) {
      final int score = _scoreAll(
        [show.name, show.publisher, show.category, show.description],
        q,
      );
      if (score >= 0) podcasts.add(PodcastResult(rank: score, show: show));
    }

    final List<EpisodeResult> episodes = [];
    for (final PodcastEpisode episode in mockPodcastEpisodes) {
      final int score = _scoreAll(
        [episode.title, episode.podcastName, episode.about],
        q,
      );
      if (score >= 0) episodes.add(EpisodeResult(rank: score, episode: episode));
    }

    stations.sort(_byRank);
    podcasts.sort(_byRank);
    episodes.sort(_byRank);

    final SearchResult? top = _pickTop(stations, podcasts);
    if (top is StationResult) {
      stations.removeWhere((r) => r.station.name == top.station.name);
    } else if (top is PodcastResult) {
      podcasts.removeWhere((r) => r.show.id == top.show.id);
    }

    return SearchResultSet(
      top: top,
      stations: stations.take(_maxStations).toList(),
      podcasts: podcasts.take(_maxPodcasts).toList(),
      episodes: episodes.take(_maxEpisodes).toList(),
    );
  }

  /// The top result is the best name-level match among stations and podcasts.
  /// Episodes are never elevated — a show/station identity is a stronger hit.
  SearchResult? _pickTop(
    List<StationResult> stations,
    List<PodcastResult> podcasts,
  ) {
    final List<SearchResult> candidates = [
      for (final StationResult r in stations)
        if (r.rank <= 1) r,
      for (final PodcastResult r in podcasts)
        if (r.rank <= 1) r,
    ];
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final int byRank = a.rank.compareTo(b.rank);
      if (byRank != 0) return byRank;
      final int stationFirst =
          (a is StationResult ? 0 : 1).compareTo(b is StationResult ? 0 : 1);
      if (stationFirst != 0) return stationFirst;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return candidates.first;
  }

  int _scoreAll(List<String?> fields, String q) {
    int best = -1;
    for (final String? field in fields) {
      final int score = _score(field, q);
      if (score >= 0 && (best < 0 || score < best)) best = score;
    }
    return best;
  }

  /// 0 = exact match, 1 = prefix, 3 = contains, -1 = no match.
  int _score(String? field, String q) {
    if (field == null || field.isEmpty) return -1;
    final String f = field.toLowerCase();
    if (f == q) return 0;
    if (f.startsWith(q)) return 1;
    if (f.contains(q)) return 3;
    return -1;
  }

  int _byRank(SearchResult a, SearchResult b) {
    final int byRank = a.rank.compareTo(b.rank);
    if (byRank != 0) return byRank;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }
}