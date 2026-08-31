import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/podcast_episode.dart';
import '../models/station.dart';
import 'podcasts/mock_podcast_directory_repository.dart';
import 'podcasts/mock_podcast_feed_repository.dart';
import 'podcasts/podcast_directory_repository.dart';
import 'podcasts/podcast_feed_refresh_service.dart';
import 'podcasts/podcast_feed_repository.dart';
import 'podcasts/podcast_feed_store.dart';
import 'podcasts/podcast_catalogue_store.dart';
import 'radio/mock_radio_repository.dart';
import 'radio/radio_repository.dart';

/// Bundles the content repositories the app reads content through.
///
/// Screens depend on this scope — never on the concrete sources — so the
/// source can be mocked (offline/dev/tests) or swapped (radio-browser.info,
/// Podcast Index, RSS) without touching the widget layer.
///
/// The scope seeds its [stations]/[shows] caches with the curated mock
/// catalogue and hydrates them from the repositories when possible (and only
/// replaces them when the source returns something newer). That keeps every
/// surface rendering immediately and degrading gracefully offline.
class AppContent extends ChangeNotifier {
  /// How long a tag/country browse result is served from cache before the
  /// source is consulted again. Keeps chip-tapping from hammering the API.
  static const Duration browseCacheTtl = Duration(minutes: 10);

  /// Minimum gap between full catalogue refreshes of the home screen.
  static const Duration stationRefreshInterval = Duration(minutes: 5);

  AppContent({
    required this.radio,
    required this.podcastDirectory,
    required this.podcastFeeds,
    List<RadioStation>? seedStations,
    List<PodcastSeries>? seedShows,
    this.pinnedStation,
    this.isLive = false,
    this.savedShowsProvider,
    this.onNewEpisodes,
    DateTime Function()? clock,
    PodcastFeedStore? customFeedStore,
    PodcastCatalogueStore? catalogueStore,
  })  : _now = clock ?? DateTime.now,
        _stations = _applyPinned(List.of(seedStations ?? mockStations), pinnedStation),
        _shows = List.of(seedShows ?? (isLive ? const [] : mockPodcasts)),
        _customFeedStore = customFeedStore,
        _catalogueStore = catalogueStore;

  /// A station always kept at the front of the radio catalogue, regardless of
  /// what a live load returns or the seed ordering. When set, it is the first
  /// station (and therefore the featured/LIVE NOW station) and is never
  /// duplicated by a live result carrying the same [RadioStation.stationId].
  final RadioStation? pinnedStation;

  /// Returns [stations] with [pinned] forced to the front: the pinned instance
  /// is placed at index 0 and any other station sharing its [stationId] is
  /// dropped (deduped by stable station identity only — no fuzzy name math).
  static List<RadioStation> _applyPinned(
    List<RadioStation> stations,
    RadioStation? pinned,
  ) {
    if (pinned == null) return stations;
    final String id = pinned.stationId;
    return [
      pinned,
      for (final RadioStation s in stations)
        if (s.stationId != id) s,
    ];
  }

  /// Fully-offline scope: every repository serves the curated mock catalogue.
  /// Used by development and widget tests so behaviour is deterministic.
  factory AppContent.mock({
    Set<String> Function()? savedShowsProvider,
    void Function(PodcastSeries show, List<PodcastEpisode> episodes)? onNewEpisodes,
  }) =>
      AppContent(
        radio: const MockRadioRepository(),
        podcastDirectory: const MockPodcastDirectoryRepository(),
        podcastFeeds: const MockPodcastFeedRepository(),
        savedShowsProvider: savedShowsProvider,
        onNewEpisodes: onNewEpisodes,
        catalogueStore: InMemoryPodcastCatalogueStore(),
      );

  final RadioRepository radio;
  final PodcastDirectoryRepository podcastDirectory;
  final PodcastFeedRepository podcastFeeds;
  final PodcastFeedStore? _customFeedStore;
  final PodcastCatalogueStore? _catalogueStore;

  /// Whether [radio]/[podcastDirectory] hit real network sources. When false,
  /// search stays purely local so offline behaviour is deterministic.
  final bool isLive;

  /// Ids of the shows the listener currently follows. Read by the feed
  /// refresh service to derive podcast subscriptions (follow = track).
  final Set<String> Function()? savedShowsProvider;

  /// Called when a feed refresh discovers new episodes, e.g. so the playback
  /// controller can mark them unseen for the NEW indicator.
  final void Function(PodcastSeries show, List<PodcastEpisode> episodes)? onNewEpisodes;

  /// The shared feed-refresh service for this scope. Screens read content
  /// through the scope anyway, so they reach refresh through it too — one
  /// service instance per scope keeps rate limiting and sync state coherent.
  late final PodcastFeedRefreshService feedRefresh = PodcastFeedRefreshService(
    content: this,
    savedShowsProvider: savedShowsProvider,
    onNewEpisodes: onNewEpisodes,
  );

  List<RadioStation> _stations;
  List<PodcastSeries> _shows;

  final DateTime Function() _now;
  final Map<String, List<RadioStation>> _tagCache = {};
  final Map<String, DateTime> _tagFetchedAt = {};
  final Map<String, List<RadioStation>> _countryCache = {};
  final Map<String, DateTime> _countryFetchedAt = {};
  DateTime? _stationsRefreshedAt;

  String? _browseTag;
  String? _browseCountry;
  List<RadioStation> _browseResults = const [];
  bool _browseLoading = false;

  /// Known radio stations: the seeded catalogue until a live load succeeds.
  List<RadioStation> get stations => List.unmodifiable(_stations);

  /// Known shows (featured/latest/popular/saved all read from here).
  List<PodcastSeries> get shows => List.unmodifiable(_shows);

  /// Flat episode index across all known shows.
  List<PodcastEpisode> get episodes =>
      [for (final PodcastSeries show in _shows) ...show.episodes];

  /// The show with [id] when it is in the known catalogue.
  PodcastSeries? showById(String id) {
    for (final PodcastSeries show in _shows) {
      if (show.id == id) return show;
    }
    return null;
  }

  /// A single episode by id across every known show, or null when unknown.
  PodcastEpisode? episodeById(String id) {
    for (final PodcastSeries show in _shows) {
      final PodcastEpisode? episode = show.episodeById(id);
      if (episode != null) return episode;
    }
    return null;
  }

  /// Inserts or replaces [show] in the catalogue (matched by id) and notifies
  /// listeners. The feed refresh service writes merged shows through here so
  /// every surface picks up new episodes without any per-screen plumbing.
  void updateShow(PodcastSeries show) {
    final int index = _shows.indexWhere((s) => s.id == show.id);
    if (index == -1) {
      _shows.insert(0, show);
    } else {
      _shows[index] = show;
    }
    _announce();
    unawaited(_catalogueStore?.save(_shows).catchError((_) {}));
  }

  /// Refreshes the radio catalogue from [radio]. Any failure keeps the
  /// current (seeded) catalogue untouched. Throttled: repeated calls within
  /// [stationRefreshInterval] are no-ops unless [force] is set.
  Future<List<RadioStation>> loadRadio({int limit = 30, bool force = false}) async {
    final DateTime now = _now();
    if (!force &&
        _stationsRefreshedAt != null &&
        now.difference(_stationsRefreshedAt!) < stationRefreshInterval) {
      return stations;
    }
    _stationsRefreshedAt = now;
    try {
      final List<RadioStation> hits = await radio.popular(limit: limit);
      if (hits.isNotEmpty) {
        _stations = _applyPinned(List.of(hits), pinnedStation);
        _announce();
      }
    } on Exception {
      // Offline/unconfigured: keep the seeded catalogue.
    }
    return stations;
  }

  // --- Radio browsing (tags & countries) ------------------------------------

  /// Active browse scope, when one is engaged.
  String? get browseTag => _browseTag;
  String? get browseCountry => _browseCountry;

  /// True while a tag/country lookup is in flight.
  bool get isBrowsing => _browseLoading;

  /// Stations for the active browse scope; empty when no scope is engaged.
  List<RadioStation> get browseStations => List.unmodifiable(_browseResults);

  /// Countries present across the known catalogue and browse results,
  /// alphabetically — derived from data, never hard-coded.
  List<String> get availableCountries {
    final Set<String> names = <String>{};
    for (final RadioStation s in [..._stations, ..._browseResults]) {
      final String? c = s.country?.trim();
      if (c != null && c.isNotEmpty) names.add(c);
    }
    return names.toList()..sort();
  }

  /// Categories present across the known catalogue and browse results —
  /// derived from data so real sources drive the chips.
  List<String> get availableCategories {
    final Set<String> names = <String>{};
    for (final RadioStation s in [..._stations, ..._browseResults]) {
      names.add(s.category.trim());
    }
    return names.toList()..sort();
  }

  /// Shows stations for [tag]. Tapping the already-active tag clears the
  /// scope instead. Results are cached for [browseCacheTtl]; when the source
  /// is unreachable the local catalogue is filtered as a fallback.
  Future<void> browseByTag(String tag) => _browse(tag: tag);

  /// Same contract as [browseByTag] but scoped to a country name.
  Future<void> browseByCountry(String country) => _browse(country: country);

  /// Leaves any browse scope and returns the home list to the catalogue.
  void clearBrowse() {
    if (_browseTag == null && _browseCountry == null && _browseResults.isEmpty) {
      return;
    }
    _browseTag = null;
    _browseCountry = null;
    _browseResults = const [];
    _browseLoading = false;
    notifyListeners();
  }

  Future<void> _browse({String? tag, String? country}) async {
    assert((tag == null) != (country == null), 'exactly one scope');
    final bool sameScope =
        _browseTag == tag && _browseCountry == country && _browseResults.isNotEmpty;
    if (sameScope) {
      clearBrowse(); // tapping the active chip toggles it off
      return;
    }
    _browseTag = tag;
    _browseCountry = country;
    _browseResults = const [];
    _browseLoading = true;
    notifyListeners();

    final String key = (tag ?? country!).trim().toLowerCase();
    final Map<String, List<RadioStation>> cache =
        tag != null ? _tagCache : _countryCache;
    final Map<String, DateTime> fetchedAt =
        tag != null ? _tagFetchedAt : _countryFetchedAt;
    final DateTime? at = fetchedAt[key];
    final List<RadioStation>? cached = cache[key];
    if (cached != null && at != null && _now().difference(at) < browseCacheTtl) {
      _browseResults = cached;
      _browseLoading = false;
      notifyListeners();
      return;
    }

    try {
      final List<RadioStation> hits = tag != null
          ? await radio.byTag(tag, limit: 40)
          : await radio.byCountry(country!, limit: 40);
      if (hits.isNotEmpty) {
        cache[key] = hits;
        fetchedAt[key] = _now();
        if (_browseTag == tag && _browseCountry == country) {
          _browseResults = hits;
        }
      }
    } on Exception {
      // Source unreachable: fall back to filtering what we already have so
      // browsing still means something offline.
      if (_browseTag == tag && _browseCountry == country) {
        _browseResults = [
          for (final RadioStation s in _stations)
            if (tag != null
                ? (s.category.toLowerCase() == key ||
                    s.tags.any((String t) => t.toLowerCase() == key))
                : ((s.country ?? '').toLowerCase() == key))
              s,
        ];
      }
    }
    _browseLoading = false;
    notifyListeners();
  }

  /// Refreshes the show catalogue from [podcastDirectory], resolving each
  /// hit to a full series (episodes included) either from its feed or from
  /// the local catalogue.
  Future<List<PodcastSeries>> loadShows({int limit = 12}) async {
    try {
      final List<PodcastSearchHit> hits = await podcastDirectory.popular(limit: limit);
      if (hits.isNotEmpty) {
        final List<PodcastSeries> resolved = [];
        for (final PodcastSearchHit hit in hits) {
          final String id = hit.directoryId ?? hit.title;
          final PodcastSeries? existing = showById(id);
          if (existing != null && existing.episodes.isNotEmpty) {
            resolved.add(existing);
          } else {
            resolved.add(hit.toSeries());
          }
        }
        _shows = [
          ...resolved,
          for (final PodcastSeries existing in _shows)
            if (!resolved.any((show) => show.id == existing.id)) existing,
        ];
        _announce();

        // Pre-resolve the first few popular shows in the background
        for (final PodcastSeries show in resolved.take(6)) {
          if (show.episodes.isEmpty) {
            unawaited(feedRefresh.resolveForDisplay(show).catchError((_) => show));
          }
        }
      }
    } on Exception {
      // Offline/unconfigured (e.g. no Podcast Index credentials): keep seed.
    }
    return shows;
  }

  /// Restores previously cached podcast shows and episodes from disk.
  Future<void> restoreCatalogue() async {
    final PodcastCatalogueStore? store = _catalogueStore;
    if (store == null) return;
    try {
      final List<PodcastSeries> cached = await store.load();
      if (cached.isNotEmpty) {
        _shows = [
          ...cached,
          for (final PodcastSeries existing in _shows)
            if (!cached.any((s) => s.id == existing.id)) existing,
        ];
        _announce();
      }
    } catch (_) {
      // Ignore cache load errors.
    }
  }

  /// Restores listener-imported feeds without deleting them when temporarily
  /// offline or when a feed is unavailable.
  Future<void> restoreCustomFeeds() async {
    final PodcastFeedStore? store = _customFeedStore;
    if (store == null) return;
    for (final String url in await store.load()) {
      try {
        updateShow(await podcastFeeds.feed(url));
      } on Exception {
        // The URL remains persisted and can be retried on a later launch.
      }
    }
  }

  /// Adds a listener-selected RSS/Atom feed to the catalogue.
  Future<PodcastSeries> addPodcastFeed(String feedUrl) async {
    final Uri? uri = Uri.tryParse(feedUrl.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('Enter a valid RSS feed URL');
    }
    final PodcastSeries show = await podcastFeeds.feed(uri.toString());
    updateShow(show);
    final PodcastFeedStore? store = _customFeedStore;
    if (store != null) {
      final List<String> urls = await store.load();
      if (!urls.contains(uri.toString())) {
        await store.save([...urls, uri.toString()]);
      }
    }
    return show;
  }



  /// Resolves a full [PodcastSeries] for a show skeleton (e.g. a search hit).
  /// Keeps the skeleton when the feed cannot be reached.
  Future<PodcastSeries> loadShow(PodcastSeries skeleton) async {
    final PodcastSeries? known = showById(skeleton.id);
    if (known != null && known.episodes.isNotEmpty) return known;
    final String? feed = skeleton.feedUrl;
    if (feed == null || feed.isEmpty) return skeleton;
    try {
      final PodcastSeries resolved = await podcastFeeds.feed(
        feed,
        preferredId: skeleton.showId,
        preferredName: skeleton.name,
        preferredAuthor: skeleton.publisher,
        preferredImageUrl: skeleton.imageUrl,
      );
      _shows = [
        resolved,
        for (final PodcastSeries show in _shows)
          if (show.id != resolved.id) show,
      ];
      _announce();
      return resolved;
    } on Exception {
      return skeleton;
    }
  }

  /// Station search. Falls back to a local name match when the source is
  /// unreachable so search never dies with the directory.
  Future<List<RadioStation>> searchStations(String query, {int limit = 25}) async {
    try {
      final List<RadioStation> hits = await radio.search(query, limit: limit);
      if (hits.isNotEmpty) return hits;
    } on Exception {
      // fall through to the local catalogue
    }
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      for (final RadioStation station in _stations)
        if (station.name.toLowerCase().contains(q)) station,
    ].take(limit).toList();
  }

  /// Show search. Returns full series for local hits and skeletons for
  /// directory hits (the detail screen resolves those feeds when opened).
  Future<List<PodcastSeries>> searchShows(String query, {int limit = 25}) async {
    try {
      final List<PodcastSearchHit> hits = await podcastDirectory.search(query, limit: limit);
      if (hits.isNotEmpty) return [for (final PodcastSearchHit hit in hits) hit.toSeries()];
    } on Exception {
      // fall through to the local catalogue
    }
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      for (final PodcastSeries show in _shows)
        if (show.name.toLowerCase().contains(q) ||
            show.publisher.toLowerCase().contains(q))
          show,
    ].take(limit).toList();
  }

  void _announce() {
    if (hasListeners) notifyListeners();
  }
}