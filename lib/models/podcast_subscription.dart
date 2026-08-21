/// Outcome of the last feed-refresh attempt for one podcast.
///
/// Loading is deliberately absent: it is transient screen state, not
/// something a subscription remembers. [idle] means no refresh has run yet.
enum FeedRefreshStatus {
  /// No refresh attempt has been made.
  idle,

  /// The feed was fetched and merged; at least one episode changed.
  success,

  /// The feed was fetched and parsed but nothing differed from the cache.
  noChanges,

  /// Skipped because the last successful fetch is too recent. The exact
  /// interval is the refresh service's configurable policy.
  rateLimited,

  /// The feed could not be reached (offline, bad status, timeout). Cached
  /// content is kept untouched.
  networkError,

  /// The server answered but the body is not a readable RSS feed.
  invalidFeed,
}

/// A followed podcast tracked for feed refresh.
///
/// Purely bookkeeping: which RSS URL to poll, when it was last polled, and
/// what the newest seen episode was — everything the refresh service needs to
/// detect new episodes without the UI re-fetching blindly. Subscriptions are
/// derived from the listener's saved shows, so unfollowing retires the
/// subscription while any cached episodes stay put.
class PodcastSubscription {
  const PodcastSubscription({
    required this.podcastId,
    required this.rssUrl,
    required this.subscribedAt,
    this.lastFetchedAt,
    this.lastSuccessfulFetchAt,
    this.lastKnownEpisodeKey,
    this.updateStatus = FeedRefreshStatus.idle,
  });

  /// The [PodcastSeries.id] being tracked.
  final String podcastId;

  /// Absolute RSS feed URL polled for updates.
  final String rssUrl;

  /// When the listener started following the show.
  final DateTime subscribedAt;

  /// Last refresh attempt of any kind (successful or not).
  final DateTime? lastFetchedAt;

  /// Last refresh that fetched AND parsed cleanly. Drives rate limiting and
  /// the "Updated …" label.
  final DateTime? lastSuccessfulFetchAt;

  /// Content-identity key of the newest episode seen in the feed, used to
  /// reason about changes without keeping every guid ever encountered.
  final String? lastKnownEpisodeKey;

  /// Outcome of the most recent refresh attempt.
  final FeedRefreshStatus updateStatus;

  PodcastSubscription copyWith({
    String? podcastId,
    String? rssUrl,
    DateTime? subscribedAt,
    DateTime? lastFetchedAt,
    DateTime? lastSuccessfulFetchAt,
    String? lastKnownEpisodeKey,
    FeedRefreshStatus? updateStatus,
  }) {
    return PodcastSubscription(
      podcastId: podcastId ?? this.podcastId,
      rssUrl: rssUrl ?? this.rssUrl,
      subscribedAt: subscribedAt ?? this.subscribedAt,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      lastSuccessfulFetchAt: lastSuccessfulFetchAt ?? this.lastSuccessfulFetchAt,
      lastKnownEpisodeKey: lastKnownEpisodeKey ?? this.lastKnownEpisodeKey,
      updateStatus: updateStatus ?? this.updateStatus,
    );
  }
}
