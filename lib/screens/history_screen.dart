import 'package:flutter/material.dart';

import '../data/content_scope.dart';
import '../models/podcast_episode.dart';
import '../models/playback.dart';
import '../models/station.dart';
import '../playback/playback_controller.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/podcast_art.dart';
import '../widgets/podcast_mini_player.dart';
import '../widgets/radio_mini_player.dart';
import 'podcast_player_screen.dart';
import 'station_detail_screen.dart';

/// One resolved history entry: the stored [ListeningHistoryItem] plus the
/// content it references, resolved against the existing mock catalogue.
class _Entry {
  const _Entry(this.item, {this.station, this.episode});

  final ListeningHistoryItem item;
  final RadioStation? station;
  final PodcastEpisode? episode;

  RadioStation? get stationOrNull => station;
  PodcastEpisode? get episodeOrNull => episode;
}

/// A header for a chronological group of history entries.
class _Group {
  const _Group(this.label, this.entries);

  final String label;
  final List<_Entry> entries;
}

/// The Listening History screen — everything the listener played recently.
///
/// Chronological and personal: radio stations and podcast episodes are grouped
/// by day (TODAY, YESTERDAY, EARLIER THIS WEEK, OLDER) so the page reads like a
/// quiet log of the listener's activity rather than a discovery feed. Rows are
/// deliberately small: a monogram or artwork tile, the names, the time it was
/// listened, and a subtle play affordance. A small overflow menu on each row
/// offers Open / Remove from history without cluttering the page.
///
/// History is intentionally distinct from the library's saved content and from
/// CONTINUE LISTENING: those answer "what do I keep?" and "what is unfinished?"
/// while this answers "what did I listen to?".
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.controller,
    this.content,
    this.onExploreAudio,
  });

  final PlaybackController controller;
  final AppContent? content;

  /// Called by the empty state's EXPLORE AUDIO action (after popping back to
  /// the shell) to return to the discovery home.
  final VoidCallback? onExploreAudio;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const Duration _playerDuration = Duration(milliseconds: 280);

  late final AppContent _content = widget.content ?? AppContent.mock();

  /// Id of the audio the listener dismissed from the slot (a contentId
  /// prefixed with its type); null while the slot is (or should be) visible.
  String? _dismissedId;

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
    final String? id = _activeAudioId;
    if (id != null && id != _dismissedId) {
      _dismissedId = null;
    }
  }

  String? get _activeAudioId {
    if (controller.radioActive && controller.currentStation != null) {
      return 'radio:${controller.currentStation!.stationId}';
    }
    if (controller.podcastActive && controller.currentEpisode != null) {
      return 'episode:${controller.currentEpisode!.id}';
    }
    return null;
  }

  // --- Content resolution ---------------------------------------------------

  RadioStation? _stationById(String id) {
    for (final RadioStation station in _content.stations) {
      if (station.stationId == id) return station;
    }
    for (final RadioStation station in controller.favouriteStationDetails) {
      if (station.stationId == id) return station;
    }
    for (final RadioStation station in mockStations) {
      if (station.stationId == id) return station;
    }
    return null;
  }

  PodcastEpisode? _episodeById(String id) {
    final PodcastEpisode? episode = _content.episodeById(id);
    if (episode != null) return episode;
    for (final PodcastEpisode ep in mockPodcastEpisodes) {
      if (ep.id == id) return ep;
    }
    return null;
  }

  /// Resolves the stored history into displayable entries, skipping any whose
  /// content no longer exists in the catalogue.
  List<_Entry> _resolveEntries() {
    final List<_Entry> entries = [];
    for (final ListeningHistoryItem item in controller.listeningHistory) {
      switch (item.contentType) {
        case HistoryContentType.radio:
          final RadioStation? station = _stationById(item.contentId);
          if (station != null) {
            entries.add(_Entry(item, station: station));
          }
        case HistoryContentType.podcast:
          final PodcastEpisode? episode = _episodeById(item.contentId);
          if (episode != null) {
            entries.add(_Entry(item, episode: episode));
          }
      }
    }
    return entries;
  }

  int _dayDiff(DateTime at) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(at.year, at.month, at.day);
    return today.difference(day).inDays;
  }

  String _groupLabel(int diff) {
    if (diff <= 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    if (diff < 7) return 'EARLIER THIS WEEK';
    return 'OLDER';
  }

  List<_Group> _groupEntries(List<_Entry> entries) {
    final List<_Group> groups = [];
    for (final _Entry entry in entries) {
      final String label = _groupLabel(_dayDiff(entry.item.listenedAt));
      if (groups.isNotEmpty && groups.last.label == label) {
        groups.last.entries.add(entry);
      } else {
        groups.add(_Group(label, [entry]));
      }
    }
    return groups;
  }

  // --- Routing -------------------------------------------------------------

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

  void _playEpisode(PodcastEpisode episode) {
    controller.playPodcastEpisode(episode);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PodcastPlayerScreen(controller: controller),
      ),
    );
  }

  void _showMenu(_Entry entry) {
    final String tag = entry.item.id;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
    final colors = AppColors.of(context);
        return SafeArea(
          child: Column(
            key: const ValueKey('history-sheet'),
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: ValueKey('history-sheet-open-$tag'),
                leading: Icon(Icons.play_arrow_outlined, size: 22, color: colors.ink),
                title: const Text('Open', style: AppTextStyles.stationName),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openEntry(entry);
                },
              ),
              ListTile(
                key: ValueKey('history-sheet-remove-$tag'),
                leading: Icon(Icons.delete_outline, size: 22, color: colors.muted),
                title: const Text('Remove from history', style: AppTextStyles.stationName),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.removeFromListeningHistory(entry.item.id);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _openEntry(_Entry entry) {
    if (entry.station != null) {
      _openStation(entry.station!);
    } else if (entry.episode != null) {
      _playEpisode(entry.episode!);
    }
  }

  // --- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildAudioSlot(),
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
    final colors = AppColors.of(context);
    final bool hasHistory = controller.listeningHistory.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('history-back'),
            tooltip: 'Back',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, size: 22, color: colors.ink),
          ),
          const Expanded(
            child: Center(child: Text('HISTORY', style: AppTextStyles.navLabel)),
          ),
          SizedBox(
            width: 48,
            child: hasHistory
                ? TextButton(
                    key: const ValueKey('history-clear'),
                    onPressed: _confirmClear,
                    child: const Text('CLEAR', style: AppTextStyles.timeLabel),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  // --- Audio slot ------------------------------------------------------------

  /// The shared mini-player pinned under the header so playback stays visible
  /// while browsing history. Radio uses [RadioMiniPlayer] and podcasts use the
  /// existing [PodcastMiniPlayer], mirroring the home surfaces.
  Widget _buildAudioSlot() {
    final String? id = _activeAudioId;
    final bool dismissed = id != null && id == _dismissedId;
    final bool radioActive = id?.startsWith('radio:') == true;
    final bool podcastActive = id?.startsWith('episode:') == true &&
        !(controller.podcastDuration > Duration.zero &&
            controller.podcastPosition >= controller.podcastDuration);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: AnimatedSize(
        duration: _playerDuration,
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: _playerDuration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: _stripTransition,
          child: !dismissed && radioActive
              ? RadioMiniPlayer(
                  key: ValueKey('history-radio-${controller.currentStation!.name}'),
                  controller: controller,
                  onDismiss: () => setState(() => _dismissedId = id),
                )
              : !dismissed && podcastActive
                  ? PodcastMiniPlayer(
                      key: ValueKey('history-podcast-${controller.currentEpisode!.title}'),
                      controller: controller,
                      onDismiss: () => setState(() => _dismissedId = id),
                    )
                  : const SizedBox(
                      width: double.infinity,
                      key: ValueKey('history-audio-none'),
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
    final List<_Entry> entries = _resolveEntries();
    if (entries.isEmpty) {
      return ListView(
        key: const ValueKey('history-list'),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        children: [_buildEmptyState()],
      );
    }

    final List<_Group> groups = _groupEntries(entries);
    final List<Widget> children = [];
    for (final _Group group in groups) {
    final colors = AppColors.of(context);
      children.add(Text(group.label, style: AppTextStyles.sectionLabel));
      children.add(const SizedBox(height: 6));
      children.add(Column(
        children: [
          for (final _Entry entry in group.entries) ...[
            _buildRow(entry),
            Divider(height: 1, thickness: 1, color: colors.hairline),
          ],
        ],
      ));
      children.add(const SizedBox(height: 28));
    }
    return ListView(
      key: const ValueKey('history-list'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      children: children,
    );
  }

  Widget _buildRow(_Entry entry) {
    if (entry.station != null) {
      return _HistoryStationRow(
        entry: entry,
        controller: controller,
        onTap: () => _openStation(entry.station!),
        onPlay: () => _playStation(entry.station!),
        onMore: () => _showMenu(entry),
      );
    }
    return _HistoryEpisodeRow(
      entry: entry,
      controller: controller,
      onTap: () => _playEpisode(entry.episode!),
      onMore: () => _showMenu(entry),
    );
  }

  // --- Empty state ----------------------------------------------------------

  Widget _buildEmptyState() {
    final colors = AppColors.of(context);
    return Container(
      key: const ValueKey('history-empty'),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: colors.hairline),
      ),
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      child: Column(
        children: [
          Text(
            'No listening history yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'Start listening and your recent activity will appear here.',
            style: AppTextStyles.stationCategory,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          GestureDetector(
            key: const ValueKey('history-explore'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).pop();
              widget.onExploreAudio?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(color: colors.ink),
              ),
              child: const Text('EXPLORE AUDIO', style: AppTextStyles.navLabel),
            ),
          ),
        ],
      ),
    );
  }

  // --- Clear confirmation ---------------------------------------------------

  void _confirmClear() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
    final colors = AppColors.of(context);
        return AlertDialog(
          key: const ValueKey('history-clear-dialog'),
          title: Text(
            'Clear listening history?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.ink),
          ),
          content: Text(
            'This will remove your recent listening activity.',
            style: AppTextStyles.stationCategory,
          ),
          actions: [
            TextButton(
              key: const ValueKey('history-clear-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CANCEL', style: AppTextStyles.timeLabel),
            ),
            TextButton(
              key: const ValueKey('history-clear-confirm'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                controller.clearListeningHistory();
              },
              child: const Text('CLEAR HISTORY', style: AppTextStyles.timeLabel),
            ),
          ],
        );
      },
    );
  }
}

// --- Row widgets ------------------------------------------------------------

/// A station history row: monogram, name, programme, when it was listened,
/// a subtle play affordance and an overflow menu.
class _HistoryStationRow extends StatelessWidget {
  const _HistoryStationRow({
    required this.entry,
    required this.controller,
    required this.onTap,
    required this.onPlay,
    required this.onMore,
  });

  final _Entry entry;
  final PlaybackController controller;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final RadioStation station = entry.station!;
    final ListeningHistoryItem item = entry.item;
    final bool active =
        controller.radioActive && controller.currentStation?.stationId == station.stationId;

    return GestureDetector(
      key: ValueKey('history-station-${station.stationId}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            _HistoryMonogram(name: station.name),
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
                    '${station.program}${station.category.isEmpty ? '' : ' · ${station.category.toUpperCase()}'}',
                    style: AppTextStyles.timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatListenedAt(item.listenedAt),
                    style: AppTextStyles.timeLabel,
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('history-more-${item.id}'),
              tooltip: 'More',
              visualDensity: VisualDensity.compact,
              onPressed: onMore,
              icon: Icon(Icons.more_horiz, size: 20, color: colors.muted),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              key: ValueKey('history-station-play-${station.stationId}'),
              behavior: HitTestBehavior.opaque,
              onTap: onPlay,
              child: _HistoryPlayCircle(
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

/// A podcast episode history row: artwork, show, episode title, when it was
/// listened, subtle progress treatment and an overflow menu.
class _HistoryEpisodeRow extends StatelessWidget {
  const _HistoryEpisodeRow({
    required this.entry,
    required this.controller,
    required this.onTap,
    required this.onMore,
  });

  final _Entry entry;
  final PlaybackController controller;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final PodcastEpisode episode = entry.episode!;
    final ListeningHistoryItem item = entry.item;
    final bool active = controller.podcastActive && controller.currentEpisode?.id == episode.id;
    final Duration position = active ? controller.podcastPosition : episode.position;
    final bool partial = position > Duration.zero && position < episode.duration;
    final bool completed = episode.isCompleted || position >= episode.duration;

    return GestureDetector(
      key: ValueKey('history-episode-${episode.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    formatListenedAt(item.listenedAt),
                    style: AppTextStyles.timeLabel,
                  ),
                  if (partial) ...[
                    const SizedBox(height: 8),
                    _HistoryProgressLine(
                      fraction: episode.duration.inMilliseconds == 0
                          ? 0
                          : (position.inMilliseconds / episode.duration.inMilliseconds)
                              .clamp(0.0, 1.0),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (partial || completed)
                    Row(
                      children: [
                        Text(
                          '${formatDuration(position)} / ${formatDuration(episode.duration)}',
                          style: AppTextStyles.timeLabel,
                        ),
                        if (completed) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.check_circle_outline, size: 12, color: colors.muted),
                          const SizedBox(width: 4),
                          const Text('PLAYED', style: AppTextStyles.timeLabel),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey('history-more-${item.id}'),
              tooltip: 'More',
              visualDensity: VisualDensity.compact,
              onPressed: onMore,
              icon: Icon(Icons.more_horiz, size: 20, color: colors.muted),
            ),
            const SizedBox(width: 4),
            const _HistoryPlayCircle(playing: false, onPressed: null),
          ],
        ),
      ),
    );
  }
}

/// The station initials circle used by history's radio rows.
class _HistoryMonogram extends StatelessWidget {
  const _HistoryMonogram({required this.name});

  final String name;

  String get _initials {
    final List<String> parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.hairline),
      ),
      child: Text(_initials, style: AppTextStyles.playerStation),
    );
  }
}

/// A thin 2px progress line, in the same family as the podcast surfaces.
class _HistoryProgressLine extends StatelessWidget {
  const _HistoryProgressLine({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(1),
      child: SizedBox(
        height: 2,
        child: ColoredBox(
          color: colors.hairline,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            child: ColoredBox(color: colors.podcastAccent),
          ),
        ),
      ),
    );
  }
}

/// The small play/pause circle for radio rows. A quiet trailing affordance:
/// it either plays (radio) or marks the row as playable (podcast).
class _HistoryPlayCircle extends StatelessWidget {
  const _HistoryPlayCircle({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      shape: const CircleBorder(),
      color: onPressed == null ? colors.podcastAccent : colors.accent,
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
              color: colors.background,
            ),
          ),
        ),
      ),
    );
  }
}