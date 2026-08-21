import 'dart:async';

import 'package:flutter/material.dart';

import '../data/content_scope.dart';
import '../data/podcasts/podcast_feed_refresh_service.dart';
import '../models/podcast_episode.dart';
import '../models/podcast_subscription.dart';
import '../playback/playback_controller.dart';
import '../screens/podcast_player_screen.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/podcast_art.dart';
import '../widgets/podcast_mini_player.dart';
import '../widgets/radio_mini_player.dart';

/// The Podcast Detail / Show screen.
///
/// A catalogue page for one show: identity (artwork, title, publisher,
/// category), a quiet FOLLOW action, the episode list (the primary content),
/// an expandable ABOUT, and a small related section. Reached from the Podcast
/// Home's featured block, popular shows and saved list; a real search surface
/// can route here later.
///
/// Deliberately not a social profile: no follower counts, likes or badges.
/// The emphasis stays on the show and its episodes. Episodes hand off to the
/// existing [PodcastPlayerScreen]; while browsing or playing, the shared
/// persistent mini-player slot stays visible at the bottom of the screen.
class PodcastDetailScreen extends StatefulWidget {
  const PodcastDetailScreen({
    super.key,
    required this.show,
    required this.controller,
    this.content,
  });

  final PodcastSeries show;
  final PlaybackController controller;

  /// Content source; defaults to the offline mock scope when not provided.
  final AppContent? content;

  @override
  State<PodcastDetailScreen> createState() => _PodcastDetailScreenState();
}

class _PodcastDetailScreenState extends State<PodcastDetailScreen> {
  late final AppContent _content = widget.content ?? AppContent.mock();
  late PodcastSeries _show = widget.show;
  bool _oldest = false;
  bool _descriptionOpen = false;
  bool _aboutOpen = false;

  /// Outcome of the most recent explicit refresh on this screen; drives the
  /// quiet error/retry line. Null until the listener pulls to refresh.
  FeedRefreshResult? _lastResult;

  /// Titles of the currently dismissed mini players (episode id / station
  /// name); null while the strip is visible. Choosing something else clears.
  String? _dismissedEpisode;
  String? _dismissedRadio;

  PlaybackController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncDismissal);
    unawaited(_initialLoad());
  }

  /// Cache-first open: shows whatever is cached immediately, then lets the
  /// feed refresh service decide whether the RSS feed is worth fetching
  /// (never fetched, stale, or a skeleton) — never a blind fetch per rebuild.
  Future<void> _initialLoad() async {
    final PodcastSeries loaded = await _content.feedRefresh.resolveForDisplay(widget.show);
    if (!mounted || identical(loaded, _show)) return;
    setState(() {
      _show = loaded;
      _oldest = false;
    });
  }

  /// Pull-to-refresh: force-fetch the feed, merge changes and update in place.
  Future<void> _refreshFeed() async {
    final FeedRefreshResult result = await _content.feedRefresh.refresh(_show, force: true);
    if (!mounted) return;
    setState(() {
      _show = result.show;
      _lastResult = result;
      _oldest = false;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncDismissal);
    super.dispose();
  }

  void _syncDismissal() {
    final PodcastEpisode? episode = controller.currentEpisode;
    if (controller.podcastActive && episode != null && episode.id != _dismissedEpisode) {
      _dismissedEpisode = null;
    }
    final station = controller.currentStation;
    if (controller.radioActive && station != null && station.name != _dismissedRadio) {
      _dismissedRadio = null;
    }
  }

  List<PodcastSeries> get _related => [
        for (final PodcastSeries show in _content.shows)
          if (show.id != _show.id) show,
      ];

  /// Starts playback only, so the persistent mini player takes over and the
  /// user can keep browsing the show.
  void _startEpisode(PodcastEpisode episode) {
    controller.playPodcastEpisode(episode);
  }

  /// Starts playback and opens the existing Podcast Player.
  void _openEpisode(PodcastEpisode episode) {
    controller.playPodcastEpisode(episode);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PodcastPlayerScreen(controller: controller),
      ),
    );
  }

  void _openShow(PodcastSeries show) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PodcastDetailScreen(
          show: show,
          controller: controller,
          content: _content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PodcastSeries show = _show;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('detail-back'),
                      tooltip: 'Back',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, size: 22, color: AppColors.ink),
                    ),
                    const Expanded(
                      child: Center(child: Text('PODCAST', style: AppTextStyles.navLabel)),
                    ),
                    IconButton(
                      key: const ValueKey('detail-share'),
                      tooltip: 'Share',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {},
                      icon: const Icon(Icons.ios_share, size: 20, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshFeed,
                  child: ListView(
                    key: const ValueKey('podcast-detail-list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                    children: [
                      _buildHeader(show),
                      _buildRefreshStatusLine(show),
                      const SizedBox(height: 28),
                      _buildEpisodeHeading(),
                      const SizedBox(height: 6),
                      for (final PodcastEpisode episode in _episodes(show)) ...[
                        _DetailEpisodeRow(
                          episode: episode,
                          controller: controller,
                          onStart: () => _startEpisode(episode),
                          onOpen: () => _openEpisode(episode),
                        ),
                        const Divider(height: 1, thickness: 1, color: AppColors.hairline),
                      ],
                      const SizedBox(height: 28),
                      _buildAbout(show),
                      const SizedBox(height: 28),
                      _buildRelated(),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              _buildMiniSlot(),
            ],
          ),
        ),
      ),
    );
  }

  List<PodcastEpisode> _episodes(PodcastSeries show) {
    final List<PodcastEpisode> episodes = show.episodes;
    return _oldest ? episodes.reversed.toList() : episodes;
  }

  // --- Show header ---------------------------------------------------------

  Widget _buildHeader(PodcastSeries show) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PodcastArt(title: show.name, size: 104),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(show.name.toUpperCase(), style: AppTextStyles.playerStation),
                  const SizedBox(height: 6),
                  Text(show.publisher, style: AppTextStyles.stationProgramme),
                  const SizedBox(height: 8),
                  Text(show.category.toUpperCase(), style: AppTextStyles.sectionLabel),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ExpandableDescription(
          description: show.description,
          open: _descriptionOpen,
          onToggle: () => setState(() => _descriptionOpen = !_descriptionOpen),
        ),
        const SizedBox(height: 20),
        _FollowButton(
          following: controller.isSavedShow(show.id),
          onTap: () => controller.toggleSavedShow(show.id),
        ),
      ],
    );
  }

  /// Quiet sync metadata under the follow action: when the feed was last
  /// refreshed, or a gentle error/retry hint. Absent until there is something
  /// worth saying — no clutter on first sight.
  Widget _buildRefreshStatusLine(PodcastSeries show) {
    final FeedRefreshResult? result = _lastResult;
    final String? line;
    if (result != null && result.status == FeedRefreshStatus.networkError) {
      line = "COULDN'T REFRESH · PULL TO RETRY";
    } else if (result != null && result.status == FeedRefreshStatus.invalidFeed) {
      line = 'FEED COULD NOT BE READ';
    } else {
      final DateTime? at = _content.feedRefresh.lastSuccessfulFetch(show.id);
      line = at == null ? null : formatUpdatedAgo(at);
    }
    if (line == null) return const SizedBox(width: double.infinity);
    return Padding(
      key: const ValueKey('detail-refresh-status'),
      padding: const EdgeInsets.only(top: 10),
      child: Text(line, style: AppTextStyles.timeLabel.copyWith(color: AppColors.muted)),
    );
  }

  // --- EPISODES ------------------------------------------------------------

  Widget _buildEpisodeHeading() {
    return Row(
      children: [
        const Text('EPISODES', style: AppTextStyles.sectionLabel),
        const Spacer(),
        _SortToggle(oldest: _oldest, onChanged: (value) => setState(() => _oldest = value)),
      ],
    );
  }

  Widget _buildAbout(PodcastSeries show) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.hairline),
          bottom: BorderSide(color: AppColors.hairline),
        ),
      ),
      child: GestureDetector(
        key: const ValueKey('detail-about-toggle'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _aboutOpen = !_aboutOpen),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('ABOUT', style: AppTextStyles.sectionLabel),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _aboutOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more, size: 20, color: AppColors.ink),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _aboutOpen
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              show.description,
                              style: AppTextStyles.stationProgramme.copyWith(height: 1.4),
                            ),
                            const SizedBox(height: 14),
                            _AboutRow(label: 'PUBLISHED BY', value: show.publisher),
                            const Divider(height: 1, thickness: 1, color: AppColors.hairline),
                            _AboutRow(label: 'RELEASES', value: show.frequency ?? '—'),
                            const Divider(height: 1, thickness: 1, color: AppColors.hairline),
                            _AboutRow(label: 'CATEGORY', value: show.category),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRelated() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('YOU MAY ALSO LIKE', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 6),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _related.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final PodcastSeries show = _related[index];
              return _RelatedCard(show: show, onTap: () => _openShow(show));
            },
          ),
        ),
      ],
    );
  }

  /// The shared persistent mini-player strip, kept visible here so the user
  /// can continue listening while browsing the show. Same widgets and the
  /// same dismiss-once semantics as the shell; nothing new is built.
  Widget _buildMiniSlot() {
    final PodcastEpisode? episode = controller.currentEpisode;
    final bool podcastActive = controller.podcastActive && episode != null;
    final bool ended = controller.podcastDuration > Duration.zero &&
        controller.podcastPosition >= controller.podcastDuration;

    if (controller.radioActive && controller.currentStation != null &&
        _dismissedRadio != controller.currentStation!.name) {
      return RadioMiniPlayer(
        key: ValueKey('radio-${controller.currentStation!.name}'),
        controller: controller,
        onDismiss: () => setState(() => _dismissedRadio = controller.currentStation!.name),
      );
    }
    if (podcastActive && !ended && _dismissedEpisode != episode.id) {
      return MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: PodcastMiniPlayer(
          key: ValueKey('podcast-${episode.id}'),
          controller: controller,
          onDismiss: () => setState(() => _dismissedEpisode = episode.id),
        ),
      );
    }
    return const SizedBox(width: double.infinity);
  }
}

/// The show description with a quiet MORE / LESS expansion toggle.
class _ExpandableDescription extends StatelessWidget {
  const _ExpandableDescription({
    required this.description,
    required this.open,
    required this.onToggle,
  });

  final String description;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('detail-description-toggle'),
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Text(
              description,
              style: AppTextStyles.stationProgramme,
              maxLines: open ? null : 3,
              overflow: open ? null : TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Text(open ? 'LESS' : 'MORE', style: AppTextStyles.nowPlayingLabel),
        ],
      ),
    );
  }
}

/// The FOLLOW / SAVED action. An audio-library action: quiet, bordered and
/// full-width when unfollowed, filled ink when saved. Not a social call-to-arm.
class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.following, required this.onTap});

  final bool following;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('detail-follow'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        decoration: BoxDecoration(
          color: following ? AppColors.ink : Colors.transparent,
          border: Border.all(color: following ? AppColors.ink : AppColors.hairline),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: following
                    ? const Icon(Icons.check, size: 15, color: AppColors.background, key: ValueKey('follow-check'))
                    : const Icon(Icons.add, size: 15, color: AppColors.ink, key: ValueKey('follow-add')),
              ),
              const SizedBox(width: 8),
              Text(
                following ? 'SAVED' : 'FOLLOW',
                style: following
                    ? AppTextStyles.playerStation.copyWith(color: AppColors.background)
                    : AppTextStyles.navLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small LATEST / OLDEST ordering switch for the episode list.
class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.oldest, required this.onChanged});

  final bool oldest;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          key: const ValueKey('detail-sort-latest'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(false),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: oldest ? AppTextStyles.sectionLabel : AppTextStyles.navLabel,
            child: const Text('LATEST'),
          ),
        ),
        const SizedBox(width: 18),
        GestureDetector(
          key: const ValueKey('detail-sort-oldest'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(true),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: oldest ? AppTextStyles.navLabel : AppTextStyles.sectionLabel,
            child: const Text('OLDEST'),
          ),
        ),
      ],
    );
  }
}

/// One episode in the list. Shows title, excerpt, duration and date, and —
/// when present — a quiet playback state: partial progress with a thin line,
/// a completed "PLAYED" state, or a live indicator when it is the episode
/// currently playing. Tapping the row opens the player; the play circle on
/// the right starts playback directly so the mini player takes over.
class _DetailEpisodeRow extends StatelessWidget {
  const _DetailEpisodeRow({
    required this.episode,
    required this.controller,
    required this.onStart,
    required this.onOpen,
  });

  final PodcastEpisode episode;
  final PlaybackController controller;
  final VoidCallback onStart;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final bool active =
        controller.podcastActive && controller.currentEpisode?.id == episode.id;
    final Duration position = active ? controller.podcastPosition : episode.position;
    final bool partial = position > Duration.zero && position < episode.duration;
    final bool completed = episode.isCompleted || position >= episode.duration;
    final bool showProgress = partial || active;
    final bool isNew = controller.isNewEpisode(episode.id);

    return GestureDetector(
      key: ValueKey('detail-row-${episode.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (active) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Container(
                            key: ValueKey('detail-active-${episode.id}'),
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.podcastAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          episode.title,
                          style: AppTextStyles.stationName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (episode.about != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      episode.about!,
                      style: AppTextStyles.stationCategory,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (isNew) ...[
                        _NewBadge(episodeId: episode.id),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${formatDuration(episode.duration)} · ${episode.published?.toUpperCase() ?? ''}',
                        style: AppTextStyles.timeLabel,
                      ),
                    ],
                  ),
                  if (showProgress) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      key: ValueKey('detail-progress-${episode.id}'),
                      borderRadius: BorderRadius.circular(1),
                      child: SizedBox(
                        height: 2,
                        child: ColoredBox(
                          color: AppColors.hairline,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: episode.duration <= Duration.zero
                                ? 0
                                : (position.inMilliseconds / episode.duration.inMilliseconds)
                                    .clamp(0.0, 1.0),
                            child: const ColoredBox(color: AppColors.podcastAccent),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (completed) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 13, color: AppColors.muted),
                        const SizedBox(width: 6),
                        const Text('PLAYED', style: AppTextStyles.timeLabel),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            GestureDetector(
              key: ValueKey('detail-play-${episode.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onStart,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _PlayCircle(playing: active && controller.isPlaying),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet NEW tag for freshly discovered episodes. Disappears once the
/// listener opens/plays the episode (the controller clears the unseen flag).
class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.episodeId});

  final String episodeId;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('detail-new-$episodeId'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: AppColors.podcastAccent)),
      child: Text(
        'NEW',
        style: AppTextStyles.timeLabel.copyWith(color: AppColors.podcastAccent),
      ),
    );
  }
}

/// Small filled play circle for episode rows; swaps to pause while that
/// episode is the one actually playing.
class _PlayCircle extends StatelessWidget {  const _PlayCircle({this.playing = false});

  final bool playing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.podcastAccent,
      ),
      child: Center(
        child: Icon(
          playing ? Icons.pause : Icons.play_arrow,
          size: 18,
          color: AppColors.background,
        ),
      ),
    );
  }
}

/// A quiet label/value pair used inside the ABOUT section.
class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.sectionLabel)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.stationName,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact recommended-show card. Routes to another detail screen, so
/// browsing never dead-ends.
class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.show, required this.onTap});

  final PodcastSeries show;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('related-${show.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.hairline),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PodcastArt(title: show.name, size: 48),
            const Spacer(),
            Text(
              show.name,
              style: AppTextStyles.stationName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(show.category, style: AppTextStyles.stationCategory),
          ],
        ),
      ),
    );
  }
}