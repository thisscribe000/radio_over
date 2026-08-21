import 'package:flutter/material.dart';

import '../data/content_scope.dart';
import '../models/playback.dart';
import '../models/podcast_episode.dart';
import '../models/station.dart';
import '../playback/playback_controller.dart';
import '../screens/podcast_detail_screen.dart';
import '../screens/podcast_player_screen.dart';
import '../screens/station_detail_screen.dart';
import '../screens/history_screen.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/active_dot.dart';
import '../widgets/podcast_art.dart';
import '../widgets/radio_mini_player.dart';

/// The Library screen — the listener's personal audio space.
///
/// Where the homes answer "what's live?" and "what do I want?", this page
/// answers "what is mine?": continue the episodes that are unfinished, return
/// to saved shows and episodes and favourite stations, reach offline
/// downloads and pick up whatever was played most recently. It reads the same
/// shared stores as every other screen (favourites, saved shows, saved
/// episodes, downloads and listen history all live on the
/// [PlaybackController]), so saving in one place is instantly reflected here.
///
/// Ordered by intent:
///  1. CONTINUE LISTENING — get back into unfinished episodes
///  2. SAVED PODCASTS / SAVED EPISODES — the personal collection
///  3. FAVOURITE STATIONS — stations the listener returns to
///  4. DOWNLOADS — offline listening
///  5. RECENTLY PLAYED — quick return to what was just heard
///
/// A quiet ALL / PODCASTS / RADIO filter narrows the sections, and the shared
/// radio strip stays available at the top while a station is on air. The
/// podcast mini-player is owned by the shell, so this screen never duplicates
/// it; [active] tells this tab whether it is the one on screen so the radio
/// strip (and all section texts) only exist while the Library is visible.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.controller,
    required this.active,
    required this.onExploreAudio,
    this.content,
  });

  final PlaybackController controller;

  /// Content source; defaults to the offline mock scope when not provided.
  final AppContent? content;

  /// Whether this tab is the one currently on screen. The screen is mounted
  /// inside the shell's IndexedStack, so its content (including the radio
  /// strip) must only exist while it is visible.
  final bool active;

  /// Called by the empty state's EXPLORE AUDIO action to return to discovery.
  final VoidCallback onExploreAudio;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

enum _LibraryFilter { all, podcasts, radio }

class _LibraryScreenState extends State<LibraryScreen> {
  static const Duration _playerDuration = Duration(milliseconds: 280);

  late final AppContent _content = widget.content ?? AppContent.mock();

  _LibraryFilter _filter = _LibraryFilter.all;

  /// Name of the station the listener dismissed while on this tab; null while
  /// the strip is (or should be) visible. Choosing a different station clears
  /// it. Mirrors the Radio home so dismissal stays per-surface.
  String? _dismissedRadio;

  PlaybackController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncDismissal);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncDismissal);
    super.dispose();
  }

  void _syncDismissal() {
    final String? name = controller.currentStation?.name;
    if (!controller.radioActive || name == null) return;
    if (name != _dismissedRadio) {
      _dismissedRadio = null;
    }
  }

  // --- Helpers -------------------------------------------------------------

  PodcastEpisode? _episodeById(String id) {
    for (final PodcastEpisode episode in _content.episodes) {
      if (episode.id == id) return episode;
    }
    return null;
  }

  /// Episodes that can be picked up where they were left: the episode
  /// currently audibly in progress (live position) plus any episodes with
  /// saved progress in the catalogue. Same source as the podcast home's
  /// CONTINUE LISTENING section.
  List<PodcastEpisode> _inProgress() {
    final List<PodcastEpisode> inProgress = [];
    final PodcastEpisode? current = controller.currentEpisode;
    if (controller.podcastActive &&
        current != null &&
        controller.podcastPosition > Duration.zero &&
        controller.podcastPosition < current.duration) {
      inProgress.add(current);
    }
    for (final PodcastEpisode episode in _content.episodes) {
      if (episode.position > Duration.zero &&
          !inProgress.any((e) => e.id == episode.id)) {
        inProgress.add(episode);
      }
    }
    return inProgress;
  }

  List<PodcastSeries> get _savedShows => [
        for (final PodcastSeries show in _content.shows)
          if (controller.isSavedShow(show.id)) show,
      ];

  List<PodcastEpisode> get _savedEpisodes => [
        for (final String id in controller.savedEpisodes)
          if (_episodeById(id) case final PodcastEpisode episode) episode,
      ];

  List<PodcastEpisode> get _downloaded => [
        for (final String id in controller.downloadedEpisodes)
          if (_episodeById(id) case final PodcastEpisode episode) episode,
      ];

  List<RadioStation> get _favouriteStations =>
      controller.favouriteStationDetails;

  List<ListenRecord> get _recentRadio => [
        for (final ListenRecord record in controller.recentHistory)
          if (record.isStation) record,
      ];

  List<ListenRecord> get _recentEpisodes => [
        for (final ListenRecord record in controller.recentHistory)
          if (!record.isStation) record,
      ];

  bool get _isEmptyLibrary =>
      controller.savedShows.isEmpty &&
      controller.savedEpisodes.isEmpty &&
      controller.favouriteStations.isEmpty &&
      controller.downloadedEpisodes.isEmpty &&
      controller.recentHistory.isEmpty;

  // --- Routing -------------------------------------------------------------

  void _playEpisode(PodcastEpisode episode) {
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

  void _openStation(RadioStation station) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StationDetailScreen(station: station, controller: controller),
      ),
    );
  }

  void _playStation(RadioStation station) {
    controller.playRadioStation(station);
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(
          controller: controller,
          onExploreAudio: widget.onExploreAudio,
        ),
      ),
    );
  }

  void _openDownloads() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DownloadsPlaceholderScreen(episodes: _downloaded),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (!widget.active) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildRadioSlot(),
                const SizedBox(height: 8),
                Expanded(child: _buildBody()),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- Header --------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIBRARY',
            key: const ValueKey('library-title'),
            style: AppTextStyles.display,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your saved audio, in one place.',
            style: AppTextStyles.stationName,
          ),
        ],
      ),
    );
  }

  // --- Radio strip ---------------------------------------------------------

  /// The shared radio mini-player, pinned under the header so the listener can
  /// keep a station on air while browsing their library. The podcast strip is
  /// owned by the shell, so this screen only ever hosts [RadioMiniPlayer].
  Widget _buildRadioSlot() {
    final RadioStation? station = controller.currentStation;
    final bool active = controller.radioActive && station != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => AnimatedSize(
          duration: _playerDuration,
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: _playerDuration,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: _stripTransition,
            child: active && _dismissedRadio != station.name
                ? RadioMiniPlayer(
                    key: ValueKey('library-radio-${station.name}'),
                    controller: controller,
                    onDismiss: () => setState(() => _dismissedRadio = station.name),
                  )
                : const SizedBox(
                    width: double.infinity,
                    key: ValueKey('library-radio-none'),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _stripTransition(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-0.08, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  // --- Body ----------------------------------------------------------------

  Widget _buildBody() {
    final List<Widget> children = [
      _buildFilters(),
      const SizedBox(height: 26),
      const Text('CONTINUE LISTENING', style: AppTextStyles.sectionLabel),
      const SizedBox(height: 12),
      _buildContinue(),
    ];
    if (_isEmptyLibrary && _filter == _LibraryFilter.all) {
      children.addAll([
        const SizedBox(height: 28),
        _buildEmptyHero(),
        const SizedBox(height: 28),
        _buildDownloadsSection(),
        const SizedBox(height: 28),
        _buildHistorySection(),
      ]);
    } else {
      children.addAll(_sections());
    }
    children.add(const SizedBox(height: 16));
    return ListView(
      key: const ValueKey('library-list'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      children: children,
    );
  }

  List<Widget> _sections() {
    final List<Widget> out = [];

    void section(String label, {double gap = 6, required Widget child}) {
      out.add(Text(label, style: AppTextStyles.sectionLabel));
      out.add(SizedBox(height: gap));
      out.add(child);
    }

    final bool radioOnly = _filter == _LibraryFilter.radio;
    final bool podcastsOnly = _filter == _LibraryFilter.podcasts;

    if (radioOnly) {
      section('FAVOURITE STATIONS', child: _buildFavouriteStations());
      final List<ListenRecord> recent = _recentRadio;
      if (recent.isNotEmpty) {
        out.add(const SizedBox(height: 28));
        section('RECENTLY PLAYED', child: _buildRecent(recent));
      }
      return out;
    }

    section('SAVED PODCASTS', child: _buildSavedShows());
    out.add(const SizedBox(height: 28));
    section('SAVED EPISODES', child: _buildSavedEpisodes());
    if (!podcastsOnly) {
      out.add(const SizedBox(height: 28));
      section('FAVOURITE STATIONS', child: _buildFavouriteStations());
    }
    out.add(const SizedBox(height: 28));
    out.add(_buildDownloadsSection());
    out.add(const SizedBox(height: 28));
    out.add(_buildHistorySection());
    final List<ListenRecord> recent = podcastsOnly ? _recentEpisodes : controller.recentHistory;
    if (recent.isNotEmpty) {
      out.add(const SizedBox(height: 28));
      section('RECENTLY PLAYED', child: _buildRecent(recent));
    }
    return out;
  }

  // --- 1. CONTINUE LISTENING -----------------------------------------------

  Widget _buildContinue() {
    final List<PodcastEpisode> inProgress = _inProgress();
    if (inProgress.isEmpty) {
      return const _QuietEmpty(
        key: ValueKey('library-continue-empty'),
        title: 'No episodes in progress',
        message: 'Start one and it will appear here, ready to continue.',
      );
    }
    return Column(
      children: [
        for (final PodcastEpisode episode in inProgress.take(3)) ...[
          _ContinueRow(
            episode: episode,
            controller: controller,
            onTap: () => _playEpisode(episode),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),
        ],
      ],
    );
  }

  // --- 2. SAVED CONTENT ----------------------------------------------------

  Widget _buildSavedShows() {
    final List<PodcastSeries> shows = _savedShows;
    if (shows.isEmpty) {
      return const _QuietEmpty(
        key: ValueKey('library-saved-shows-empty'),
        title: 'No saved shows yet',
        message: 'Follow shows you love and they\'ll appear here.',
      );
    }
    return Column(
      children: [
        for (final PodcastSeries show in shows) ...[
          _SavedShowRow(show: show, onTap: () => _openShow(show)),
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),
        ],
      ],
    );
  }

  Widget _buildSavedEpisodes() {
    final List<PodcastEpisode> episodes = _savedEpisodes;
    if (episodes.isEmpty) {
      return const _QuietEmpty(
        key: ValueKey('library-saved-episodes-empty'),
        title: 'No saved episodes yet',
        message: 'Save episodes from the player and they\'ll appear here.',
      );
    }
    return Column(
      children: [
        for (final PodcastEpisode episode in episodes) ...[
          _SavedEpisodeRow(
            episode: episode,
            controller: controller,
            onTap: () => _playEpisode(episode),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),
        ],
      ],
    );
  }

  // --- 3. FAVOURITE STATIONS ------------------------------------------------

  Widget _buildFavouriteStations() {
    final List<RadioStation> stations = _favouriteStations;
    if (stations.isEmpty) {
      return const _QuietEmpty(
        key: ValueKey('library-stations-empty'),
        title: 'No stations saved yet',
        message: 'Save stations and they\'ll appear here.',
      );
    }
    return Column(
      children: [
        for (final RadioStation station in stations) ...[
          _FavouriteStationRow(
            station: station,
            controller: controller,
            onTap: () => _openStation(station),
            onPlay: () => _playStation(station),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),
        ],
      ],
    );
  }

  // --- 4. DOWNLOADS ----------------------------------------------------------

  Widget _buildDownloadsSection() {
    final int count = _downloaded.length;
    final String subtitle = count == 0
        ? 'Nothing downloaded yet'
        : '$count episode${count == 1 ? '' : 's'} available offline';
    return Column(
      children: [
        GestureDetector(
          key: const ValueKey('library-downloads'),
          behavior: HitTestBehavior.opaque,
          onTap: _openDownloads,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.download_outlined, size: 20, color: AppColors.muted),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DOWNLOADS', style: AppTextStyles.stationName),
                      const SizedBox(height: 3),
                      Text(subtitle, style: AppTextStyles.stationCategory),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.hairline),
      ],
    );
  }

  // --- 5. HISTORY ------------------------------------------------------------

  Widget _buildHistorySection() {
    final int count = controller.listeningHistory.length;
    final String subtitle = count == 0
        ? 'Nothing listened to yet'
        : '$count recent listen${count == 1 ? '' : 's'} across radio and podcasts';
    return Column(
      children: [
        GestureDetector(
          key: const ValueKey('library-history'),
          behavior: HitTestBehavior.opaque,
          onTap: _openHistory,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.history, size: 20, color: AppColors.muted),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('HISTORY', style: AppTextStyles.stationName),
                      const SizedBox(height: 3),
                      Text(subtitle, style: AppTextStyles.stationCategory),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.hairline),
      ],
    );
  }

  // --- 6. RECENTLY PLAYED ----------------------------------------------------

  Widget _buildRecent(List<ListenRecord> recent) {
    return Column(
      children: [
        for (final ListenRecord record in recent.take(6)) ...[
          if (record.isStation && record.station != null)
            _HistoryStationRow(
              station: record.station!,
              controller: controller,
              playedAt: record.playedAt,
              onTap: () => _playStation(record.station!),
            )
          else if (!record.isStation && record.episode != null)
            _HistoryEpisodeRow(
              episode: record.episode!,
              playedAt: record.playedAt,
              onTap: () => _playEpisode(record.episode!),
            ),
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),
        ],
      ],
    );
  }

  // --- Empty hero -------------------------------------------------------------

  Widget _buildEmptyHero() {
    return Container(
      key: const ValueKey('library-empty'),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      child: Column(
        children: [
          const Text(
            'Your library is empty',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'Save stations, podcasts and episodes and they\'ll appear here.',
            style: AppTextStyles.stationCategory,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          GestureDetector(
            key: const ValueKey('library-explore'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onExploreAudio,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.ink),
              ),
              child: const Text('EXPLORE AUDIO', style: AppTextStyles.navLabel),
            ),
          ),
        ],
      ),
    );
  }

  // --- Filters ------------------------------------------------------------

  Widget _buildFilters() {
    return Row(
      children: [
        _FilterChip(
          key: const ValueKey('library-filter-all'),
          label: 'ALL',
          selected: _filter == _LibraryFilter.all,
          onTap: () => setState(() => _filter = _LibraryFilter.all),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          key: const ValueKey('library-filter-podcasts'),
          label: 'PODCASTS',
          selected: _filter == _LibraryFilter.podcasts,
          onTap: () => setState(() => _filter = _LibraryFilter.podcasts),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          key: const ValueKey('library-filter-radio'),
          label: 'RADIO',
          selected: _filter == _LibraryFilter.radio,
          onTap: () => setState(() => _filter = _LibraryFilter.radio),
        ),
        const Spacer(),
        const Icon(Icons.collections_bookmark_outlined, size: 16, color: AppColors.muted),
      ],
    );
  }
}

// --- Widgets ---------------------------------------------------------------

/// A quiet bordered filter chip, same language as the home category chips.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? AppColors.ink : AppColors.hairline),
        ),
        child: Text(
          label,
          style: selected ? AppTextStyles.navLabel : AppTextStyles.sectionLabel,
        ),
      ),
    );
  }
}

/// A restrained empty block used across the library's sections.
class _QuietEmpty extends StatelessWidget {
  const _QuietEmpty({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: AppTextStyles.stationCategory,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A continue-listening row: artwork, show + episode, a thin progress line,
/// the elapsed/total time and a quiet RESUME call-to-action.
class _ContinueRow extends StatelessWidget {
  const _ContinueRow({
    required this.episode,
    required this.controller,
    required this.onTap,
  });

  final PodcastEpisode episode;
  final PlaybackController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = controller.podcastActive && controller.currentEpisode?.id == episode.id;
    final Duration position = active ? controller.podcastPosition : episode.position;
    final double fraction = episode.duration.inMilliseconds == 0
        ? 0
        : (position.inMilliseconds / episode.duration.inMilliseconds).clamp(0.0, 1.0);

    return GestureDetector(
      key: ValueKey('library-continue-${episode.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PodcastArt(title: episode.podcastName, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(episode.podcastName.toUpperCase(), style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 3),
                  Text(
                    episode.title,
                    style: AppTextStyles.stationName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  _ProgressLine(fraction: fraction),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${formatDuration(position)} / ${formatDuration(episode.duration)}',
                        style: AppTextStyles.timeLabel,
                      ),
                      const Spacer(),
                      const Text('RESUME', style: AppTextStyles.navLabel),
                      const SizedBox(width: 8),
                      const _PodcastPlayCircle(size: 26),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A saved-show row that opens the show's detail screen.
class _SavedShowRow extends StatelessWidget {
  const _SavedShowRow({required this.show, required this.onTap});

  final PodcastSeries show;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('library-saved-show-${show.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            PodcastArt(title: show.name, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(show.name, style: AppTextStyles.stationName),
                  const SizedBox(height: 3),
                  Text(
                    '${show.category.toUpperCase()} · ${show.episodes.length} EPISODES',
                    style: AppTextStyles.timeLabel,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// A saved-episode row with its playback state; tapping resumes it.
class _SavedEpisodeRow extends StatelessWidget {
  const _SavedEpisodeRow({
    required this.episode,
    required this.controller,
    required this.onTap,
  });

  final PodcastEpisode episode;
  final PlaybackController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = controller.podcastActive && controller.currentEpisode?.id == episode.id;
    final Duration position = active ? controller.podcastPosition : episode.position;
    final bool partial = position > Duration.zero && position < episode.duration;
    final bool completed = episode.isCompleted || position >= episode.duration;
    final bool showProgress = partial || active;

    return GestureDetector(
      key: ValueKey('library-saved-episode-${episode.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            PodcastArt(title: episode.podcastName, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(episode.podcastName.toUpperCase(), style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 3),
                  Text(
                    episode.title,
                    style: AppTextStyles.stationName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        '${formatDuration(episode.duration)} · ${episode.published?.toUpperCase() ?? ''}',
                        style: AppTextStyles.timeLabel,
                      ),
                      if (completed) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle_outline, size: 12, color: AppColors.muted),
                        const SizedBox(width: 4),
                        const Text('PLAYED', style: AppTextStyles.timeLabel),
                      ],
                    ],
                  ),
                  if (showProgress) ...[
                    const SizedBox(height: 8),
                    _ProgressLine(
                      fraction: episode.duration.inMilliseconds == 0
                          ? 0
                          : (position.inMilliseconds / episode.duration.inMilliseconds)
                              .clamp(0.0, 1.0),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            const _PodcastPlayCircle(size: 30),
          ],
        ),
      ),
    );
  }
}

/// A favourite-station row; tapping opens Station Detail, the play circle
/// starts broadcasting straight away.
class _FavouriteStationRow extends StatelessWidget {
  const _FavouriteStationRow({
    required this.station,
    required this.controller,
    required this.onTap,
    required this.onPlay,
  });

  final RadioStation station;
  final PlaybackController controller;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final bool active = controller.radioActive &&
        controller.currentStation?.stationId == station.stationId;
    final bool unavailable =
        !station.isOnline || (station.streamUrl?.isEmpty ?? true);
    return GestureDetector(
      key: ValueKey('library-station-${station.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            _Monogram(name: station.name, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.name,
                    style: AppTextStyles.stationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(station.category,
                            style: AppTextStyles.stationCategory,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (unavailable) ...[
                        const SizedBox(width: 8),
                        const Text('OFFLINE',
                            key: ValueKey('library-station-offline'),
                            style: AppTextStyles.nowPlayingLabel),
                      ] else if (active) ...[
                        const SizedBox(width: 10),
                        const ActiveDot(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              key: ValueKey('library-station-play-${station.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: onPlay,
              child: _RadioPlayCircle(
                playing: active && controller.isPlaying,
                onPressed: onPlay,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A recently-played station row.
class _HistoryStationRow extends StatelessWidget {
  const _HistoryStationRow({
    required this.station,
    required this.controller,
    required this.playedAt,
    required this.onTap,
  });

  final RadioStation station;
  final PlaybackController controller;
  final DateTime playedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool active =
        controller.radioActive && controller.currentStation?.name == station.name;
    return GestureDetector(
      key: ValueKey('library-recent-station-${station.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            _Monogram(name: station.name, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.name,
                    style: AppTextStyles.stationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${station.category.toUpperCase()} · ${station.program}',
                    style: AppTextStyles.timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(formatListenedAt(playedAt), style: AppTextStyles.timeLabel),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              key: ValueKey('library-recent-station-play-${station.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: _RadioPlayCircle(
                playing: active && controller.isPlaying,
                onPressed: onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A recently-played episode row.
class _HistoryEpisodeRow extends StatelessWidget {
  const _HistoryEpisodeRow({
    required this.episode,
    required this.playedAt,
    required this.onTap,
  });

  final PodcastEpisode episode;
  final DateTime playedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('library-recent-episode-${episode.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            PodcastArt(title: episode.podcastName, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(episode.podcastName.toUpperCase(), style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 3),
                  Text(
                    episode.title,
                    style: AppTextStyles.stationName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${formatDuration(episode.duration)} · ${episode.published?.toUpperCase() ?? ''}',
                    style: AppTextStyles.timeLabel,
                  ),
                  const SizedBox(height: 3),
                  Text(formatListenedAt(playedAt), style: AppTextStyles.timeLabel),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const _PodcastPlayCircle(size: 30),
          ],
        ),
      ),
    );
  }
}

/// The station initials circle used by the library's radio rows.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.name, required this.size});

  final String name;
  final double size;

  String get _initials {
    final List<String> parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text(_initials, style: AppTextStyles.playerStation),
    );
  }
}

/// A thin 2px progress line, in the same family as the podcast surfaces.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(1),
      child: SizedBox(
        height: 2,
        child: ColoredBox(
          color: AppColors.hairline,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: const ColoredBox(color: AppColors.podcastAccent),
          ),
        ),
      ),
    );
  }
}

/// The small filled play circle for podcast rows.
class _PodcastPlayCircle extends StatelessWidget {
  const _PodcastPlayCircle({this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.podcastAccent,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(left: size * 0.06),
            child: Icon(
              Icons.play_arrow,
              size: size * 0.58,
              color: AppColors.background,
            ),
          ),
        ),
      ),
    );
  }
}

/// The small play/pause circle for radio rows.
class _RadioPlayCircle extends StatelessWidget {
  const _RadioPlayCircle({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      color: AppColors.accent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: Icon(
              playing ? Icons.pause : Icons.play_arrow,
              size: 20,
              color: AppColors.background,
            ),
          ),
        ),
      ),
    );
  }
}

/// A minimal stand-in for the future dedicated Downloads screen. Only the
/// navigation entry is built now; this stub lists what is already offline.
class _DownloadsPlaceholderScreen extends StatelessWidget {
  const _DownloadsPlaceholderScreen({required this.episodes});

  final List<PodcastEpisode> episodes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('downloads-back'),
                    tooltip: 'Back',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, size: 22, color: AppColors.ink),
                  ),
                  const Expanded(
                    child: Center(child: Text('DOWNLOADS', style: AppTextStyles.navLabel)),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('downloads-list'),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                children: [
                  const Text('READY OFFLINE', style: AppTextStyles.sectionLabel),
                  const SizedBox(height: 6),
                  Text(
                    episodes.isEmpty
                        ? 'No downloads yet'
                        : '${episodes.length} episode${episodes.length == 1 ? '' : 's'} available',
                    style: AppTextStyles.stationCategory,
                  ),
                  const SizedBox(height: 12),
                  if (episodes.isEmpty)
                    Container(
                      key: const ValueKey('downloads-empty'),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.hairline),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
                      child: Column(
                        children: const [
                          Text(
                            'Offline listening is coming soon',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Download episodes from the player and manage them here.',
                            style: AppTextStyles.stationCategory,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    for (final PodcastEpisode episode in episodes) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            PodcastArt(title: episode.podcastName, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    episode.title,
                                    style: AppTextStyles.stationName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    episode.podcastName.toUpperCase(),
                                    style: AppTextStyles.timeLabel,
                                  ),
                                ],
                              ),
                            ),
                            Text(formatDuration(episode.duration), style: AppTextStyles.timeLabel),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: AppColors.hairline),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}