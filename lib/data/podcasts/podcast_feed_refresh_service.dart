import '../../models/podcast_episode.dart';
import '../../models/podcast_subscription.dart';
import '../content_scope.dart';
import 'podcast_feed_repository.dart';

/// The result of one refresh attempt. [show] always carries the best known
/// version of the series — merged on success, cached on failure — so callers
/// can render it unconditionally.
class FeedRefreshResult {
  const FeedRefreshResult({
    required this.status,
    required this.show,
    this.newEpisodes = const [],
    this.updatedCount = 0,
    this.fetched = false,
  });

  final FeedRefreshStatus status;
  final PodcastSeries show;

  /// Episodes discovered in the feed that were not known before.
  final List<PodcastEpisode> newEpisodes;

  /// How many existing episodes had their metadata refreshed in place.
  final int updatedCount;

  /// Whether a network fetch actually happened (false for throttled skips).
  final bool fetched;

  bool get ok => status == FeedRefreshStatus.success || status == FeedRefreshStatus.noChanges;
}

/// Per-show sync bookkeeping. Kept for every show the service touches so
/// rate limiting applies whether or not the listener follows it; a
/// [PodcastSubscription] view is exposed only for followed shows.
class _SyncRecord {
  _SyncRecord({this.rssUrl});

  final String? rssUrl;
  DateTime? subscribedAt;
  DateTime? lastFetchedAt;
  DateTime? lastSuccessfulFetchAt;
  String? lastKnownEpisodeKey;
  FeedRefreshStatus updateStatus = FeedRefreshStatus.idle;
}

/// Refreshes podcast RSS feeds and merges changes into the content scope.
///
/// The single entry point for feed synchronization — callable from the show
/// screen (open + pull-to-refresh), the library, and later a background job
/// or notification surface — so no widget ever fetches RSS directly.
///
/// Flow: UI → [PodcastFeedRefreshService] → [PodcastFeedRepository] → parser
/// → diff against the cached series → [AppContent.updateShow] → UI rebuilds.
///
/// Behaviour:
/// * Identity/diffing prefers the episode GUID with a normalized
///   title/date/audio fallback ([episodeIdentityKey]); list position is never
///   used, so a new topmost episode is detected without duplicating the rest.
/// * Merged episodes keep their local playback position; metadata is taken
///   from the feed when it differs.
/// * Fetches are rate limited per feed via [minRefreshInterval]; pull-to-
///   refresh passes `force: true` to bypass it.
/// * Subscriptions are derived from the listener's saved shows through
///   [savedShowsProvider]: following makes a show eligible for batch refresh,
///   unfollowing retires the subscription (cached episodes are kept), and
///   search results never subscribe anyone.
/// * Failures never throw and never touch the cache; they surface as
///   [FeedRefreshStatus.networkError] / [FeedRefreshStatus.invalidFeed].
class PodcastFeedRefreshService {
  PodcastFeedRefreshService({
    required this.content,
    PodcastFeedRepository? feeds,
    this.minRefreshInterval = defaultMinRefreshInterval,
    DateTime Function()? clock,
    this.savedShowsProvider,
    this.onNewEpisodes,
  })  : _feeds = feeds ?? content.podcastFeeds,
        _now = clock ?? DateTime.now;

  /// How long after a successful fetch a feed is considered fresh. Configurable
  /// so policy can change (or move server-side) without touching call sites.
  final Duration minRefreshInterval;

  /// Returns the ids of shows the listener currently follows. When null, no
  /// show counts as subscribed (direct [refresh] still works).
  final Set<String> Function()? savedShowsProvider;

  /// Called after a refresh discovers genuinely new episodes, e.g. to mark
  /// them unseen in the playback controller.
  final void Function(PodcastSeries show, List<PodcastEpisode> episodes)? onNewEpisodes;

  static const Duration defaultMinRefreshInterval = Duration(minutes: 15);

  final AppContent content;
  final PodcastFeedRepository _feeds;
  final DateTime Function() _now;
  final Map<String, _SyncRecord> _sync = {};

  /// Subscription view of a followed show, or null when the listener does not
  /// follow it (or no provider was configured).
  PodcastSubscription? subscription(String showId) {
    if (!_isSubscribed(showId)) return null;
    final _SyncRecord? record = _sync[showId];
    final String? rssUrl = record?.rssUrl ?? content.showById(showId)?.feedUrl;
    if (record == null || rssUrl == null || rssUrl.isEmpty) return null;
    return PodcastSubscription(
      podcastId: showId,
      rssUrl: rssUrl,
      subscribedAt: record.subscribedAt ?? _now(),
      lastFetchedAt: record.lastFetchedAt,
      lastSuccessfulFetchAt: record.lastSuccessfulFetchAt,
      lastKnownEpisodeKey: record.lastKnownEpisodeKey,
      updateStatus: record.updateStatus,
    );
  }

  /// Every followed show's subscription, most recently subscribed first.
  List<PodcastSubscription> get subscriptions {
    final List<PodcastSubscription> all = [
      for (final String id in savedShowIds)
        if (subscription(id) != null) subscription(id)!,
    ];
    return List.unmodifiable(all);
  }

  Set<String> get savedShowIds => Set<String>.of(savedShowsProvider?.call() ?? const <String>{});

  bool _isSubscribed(String showId) => savedShowIds.contains(showId);

  /// When [showId]'s feed was last successfully fetched and merged,
  /// regardless of whether the listener follows it. Drives "Updated …" labels.
  DateTime? lastSuccessfulFetch(String showId) => _sync[showId]?.lastSuccessfulFetchAt;

  _SyncRecord _recordFor(String showId, String? feedUrl) {
    final _SyncRecord record = _sync.putIfAbsent(showId, () => _SyncRecord(rssUrl: feedUrl));
    if (record.subscribedAt == null && _isSubscribed(showId)) {
      record.subscribedAt = _now();
    }
    return record;
  }

  /// Cache-first load used when a show screen opens. Returns the cached full
  /// series when it is fresh enough, otherwise fetches once (throttled) and
  /// merges. Never throws; falls back to whatever is cached.
  Future<PodcastSeries> resolveForDisplay(PodcastSeries show) async {
    final PodcastSeries cached = content.showById(show.id) ?? show;
    final String? feedUrl = cached.feedUrl;
    if (feedUrl == null || feedUrl.isEmpty) return cached;

    // A skeleton (no episodes yet) always justifies a fetch; otherwise only
    // when the last successful fetch is older than the interval.
    final _SyncRecord record = _recordFor(show.id, feedUrl);
    final bool neverFetched = record.lastSuccessfulFetchAt == null;
    final bool stale = !neverFetched &&
        _now().difference(record.lastSuccessfulFetchAt!) >= minRefreshInterval;
    if (cached.episodes.isNotEmpty && !neverFetched && !stale) return cached;

    final FeedRefreshResult result = await _fetchAndMerge(cached);
    return result.show;
  }

  /// Explicit refresh of one show (pull-to-refresh). Pass [force] to bypass
  /// the rate limit. Never throws.
  Future<FeedRefreshResult> refresh(PodcastSeries show, {bool force = false}) async {
    final PodcastSeries cached = content.showById(show.id) ?? show;
    final String? feedUrl = cached.feedUrl;
    if (feedUrl == null || feedUrl.isEmpty) {
      return FeedRefreshResult(status: FeedRefreshStatus.noChanges, show: cached);
    }
    final _SyncRecord record = _recordFor(show.id, feedUrl);
    if (!force && record.lastSuccessfulFetchAt != null) {
      final Duration since = _now().difference(record.lastSuccessfulFetchAt!);
      if (since < minRefreshInterval) {
        return FeedRefreshResult(
          status: FeedRefreshStatus.rateLimited,
          show: cached,
          fetched: false,
        );
      }
    }
    return _fetchAndMerge(cached);
  }

  /// Refreshes every followed show once, independently. Built for future
  /// background refresh: "refresh my subscribed podcasts" is exactly this call.
  Future<List<FeedRefreshResult>> refreshAll({bool force = false}) async {
    final List<FeedRefreshResult> results = [];
    for (final String showId in savedShowIds) {
      final PodcastSeries? show = content.showById(showId);
      if (show == null) continue;
      results.add(await refresh(show, force: force));
    }
    return results;
  }

  /// Fetches the feed, diffs it against the cached series and writes the
  /// merged result back into the content scope.
  Future<FeedRefreshResult> _fetchAndMerge(PodcastSeries cached) async {
    final String feedUrl = cached.feedUrl!;
    final _SyncRecord record = _recordFor(cached.id, feedUrl)
      ..lastFetchedAt = _now();

    final PodcastSeries incoming;
    try {
      incoming = await _feeds.feed(
        feedUrl,
        preferredId: cached.id,
        preferredName: cached.name,
        preferredAuthor: cached.feedAuthor ?? cached.publisher,
        preferredImageUrl: cached.imageUrl,
      );
    } on FormatException {
      record.updateStatus = FeedRefreshStatus.invalidFeed;
      return FeedRefreshResult(status: FeedRefreshStatus.invalidFeed, show: cached);
    } on Exception {
      record.updateStatus = FeedRefreshStatus.networkError;
      return FeedRefreshResult(status: FeedRefreshStatus.networkError, show: cached);
    }

    final _MergeOutcome outcome = _mergeEpisodes(cached, incoming);
    final PodcastSeries merged = PodcastSeries(
      id: cached.id,
      name: incoming.name.isNotEmpty ? incoming.name : cached.name,
      category: incoming.category,
      publisher: incoming.publisher.isNotEmpty ? incoming.publisher : cached.publisher,
      description: incoming.description.isNotEmpty ? incoming.description : cached.description,
      frequency: cached.frequency,
      episodes: outcome.merged,
      imageUrl: incoming.imageUrl ?? cached.imageUrl,
      feedUrl: feedUrl,
      feedAuthor: incoming.feedAuthor ?? cached.feedAuthor,
    );

    content.updateShow(merged);

    record
      ..lastSuccessfulFetchAt = _now()
      ..updateStatus = outcome.added.isEmpty
          ? FeedRefreshStatus.noChanges
          : FeedRefreshStatus.success
      ..lastKnownEpisodeKey =
          incoming.episodes.isEmpty ? record.lastKnownEpisodeKey : episodeIdentityKey(incoming.episodes.first);

    if (outcome.added.isNotEmpty) {
      onNewEpisodes?.call(merged, outcome.added);
    }
    return FeedRefreshResult(
      status: record.updateStatus,
      show: merged,
      newEpisodes: outcome.added,
      updatedCount: outcome.updatedCount,
      fetched: true,
    );
  }

  /// Merges freshly parsed episodes into the cached list.
  ///
  /// Matching is by content identity ([episodeIdentityKey]) with an id-level
  /// fallback, never by position, so a new item at the top of the feed is
  /// detected while everything else keeps its place (and playback position).
  /// Metadata updates apply in place; episodes the feed no longer lists stay
  /// appended at the end rather than being silently destroyed.
  static _MergeOutcome _mergeEpisodes(PodcastSeries cached, PodcastSeries incoming) {
    final Map<String, PodcastEpisode> byIdentity = {
      for (final PodcastEpisode episode in cached.episodes) episodeIdentityKey(episode): episode,
    };
    final Map<String, PodcastEpisode> byId = {
      for (final PodcastEpisode episode in cached.episodes) episode.id: episode,
    };

    final List<PodcastEpisode> merged = [];
    final List<PodcastEpisode> added = [];
    int updatedCount = 0;
    final Set<String> consumed = {};

    for (final PodcastEpisode episode in incoming.episodes) {
      final PodcastEpisode? existing =
          byIdentity[episodeIdentityKey(episode)] ?? byId[episode.id];
      if (existing == null) {
        merged.add(episode);
        added.add(episode);
        continue;
      }
      consumed.add(existing.id);
      final PodcastEpisode refreshed = PodcastEpisode(
        id: existing.id,
        podcastId: existing.podcastId,
        podcastName: existing.podcastName,
        title: episode.title,
        duration: episode.duration,
        episodeNumber: episode.episodeNumber ?? existing.episodeNumber,
        published: episode.published ?? existing.published,
        about: episode.about ?? existing.about,
        position: existing.position,
        transcriptAvailable: existing.transcriptAvailable,
        audioUrl: episode.audioUrl ?? existing.audioUrl,
        guid: episode.guid ?? existing.guid,
        imageUrl: episode.imageUrl ?? existing.imageUrl,
      );
      if (!_sameMetadata(refreshed, existing)) updatedCount++;
      merged.add(refreshed);
    }

    for (final PodcastEpisode episode in cached.episodes) {
      if (!consumed.contains(episode.id)) merged.add(episode);
    }
    return _MergeOutcome(merged: merged, added: added, updatedCount: updatedCount);
  }

  static bool _sameMetadata(PodcastEpisode a, PodcastEpisode b) =>
      a.title == b.title &&
      a.duration == b.duration &&
      a.published == b.published &&
      a.about == b.about &&
      a.audioUrl == b.audioUrl &&
      a.imageUrl == b.imageUrl &&
      a.guid == b.guid;
}

class _MergeOutcome {
  const _MergeOutcome({required this.merged, required this.added, required this.updatedCount});

  final List<PodcastEpisode> merged;
  final List<PodcastEpisode> added;
  final int updatedCount;
}
