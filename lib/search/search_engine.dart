import '../data/content_scope.dart';
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

/// Unified catalogue search across radio and podcasts.
///
/// No UI and no playback: given a query it returns the ranked hit set so the
/// presentation layer never has to know where content comes from. Results
/// are always available synchronously from the scope's local catalogue, and
/// when the scope is live ([AppContent.isLive]) the configured repositories
/// are queried in parallel and their hits merged in (deduped).
class SearchEngine {
  SearchEngine({AppContent? content}) : content = content ?? AppContent.mock();

  final AppContent content;

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

  /// Ranked hits for [query], grouping stations, podcasts and episodes.
  Future<SearchResultSet> search(String query) async {
    if (!content.isLive) return searchLocal(query);

    final dd = await Future.wait<dynamic>([
      content.searchStations(query),
      content.searchShows(query),
    ]);
    final List<RadioStation> remoteStations =
        (dd[0] as List).cast<RadioStation>();
    final List<PodcastSeries> remoteShows =
        (dd[1] as List).cast<PodcastSeries>();
    return _compose(query, remoteStations: remoteStations, remoteShows: remoteShows);
  }

  /// Deterministic, purely-local search over the scope's catalogue. Used when
  /// the content is not live and by tests.
  SearchResultSet searchLocal(String query) => _compose(query);

  SearchResultSet _compose(
    String query, {
    List<RadioStation> remoteStations = const [],
    List<PodcastSeries> remoteShows = const [],
  }) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return const SearchResultSet();

    final List<StationResult> stations = [];
    final Map<String, StationResult> stationByName = {};
    for (final RadioStation station in [...remoteStations, ...content.stations]) {
      final int score = _scoreAll(
        [station.name, station.program, station.category, station.country],
        q,
      );
      if (score < 0) continue;
      final StationResult candidate = StationResult(rank: score, station: station);
      final StationResult? previous = stationByName[station.name];
      if (previous == null || score < previous.rank) {
        stationByName[station.name] = candidate;
      }
    }
    stations.addAll(stationByName.values);

    final List<PodcastResult> podcasts = [];
    final Map<String, PodcastResult> podcastById = {};
    for (final PodcastSeries show in [...remoteShows, ...content.shows]) {
      final int score = _scoreAll(
        [show.name, show.publisher, show.category, show.description],
        q,
      );
      if (score < 0) continue;
      final PodcastResult candidate = PodcastResult(rank: score, show: show);
      final PodcastResult? previous = podcastById[show.id];
      if (previous == null ||
          score < previous.rank ||
          (previous.show.episodes.isEmpty && candidate.show.episodes.isNotEmpty)) {
        podcastById[show.id] = candidate;
      }
    }
    podcasts.addAll(podcastById.values);

    final List<EpisodeResult> episodes = [];
    for (final PodcastEpisode episode in content.episodes) {
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