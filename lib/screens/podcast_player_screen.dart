import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/podcasts/podcast_transcript_service.dart';
import '../models/podcast_episode.dart';
import '../playback/playback_controller.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/now_playing_info.dart';
import '../widgets/player_icon_button.dart';
import '../widgets/player_top_bar.dart';
import '../widgets/podcast_art.dart';
import '../widgets/podcast_captions.dart';
import '../widgets/podcast_chapters.dart';
import '../widgets/podcast_progress.dart';
import '../widgets/sleep_timer_indicator.dart';
import '../widgets/sleep_timer_sheet.dart';

/// Full-screen podcast player.
///
/// The sibling of the Radio Player: same scaffold, top bar and Play/Pause
/// language, but a quieter, time-based personality — artwork, episode-first
/// typography, a scrubbable timeline, skip controls and a small set of quiet
/// secondary actions. A muted teal accent ([colors.podcastAccent]) marks
/// the podcast surfaces so they read as on-demand, different from radio's
/// live terracotta.
class PodcastPlayerScreen extends StatefulWidget {
  const PodcastPlayerScreen({
    super.key,
    required this.controller,
    this.transcriptService,
  });

  final PlaybackController controller;
  final PodcastTranscriptService? transcriptService;

  @override
  State<PodcastPlayerScreen> createState() => _PodcastPlayerScreenState();
}

class _PodcastPlayerScreenState extends State<PodcastPlayerScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  late final PodcastTranscriptService _transcriptService =
      widget.transcriptService ?? PodcastTranscriptService();

  List<PodcastCaption>? _liveCaptions;
  List<PodcastChapter>? _liveChapters;
  String? _loadedEpisodeId;

  @override
  void initState() {
    super.initState();
    _fetchMetadataIfAvailable();
  }

  void _fetchMetadataIfAvailable() {
    final PodcastEpisode? episode = widget.controller.currentEpisode;
    if (episode == null || episode.id == _loadedEpisodeId) return;
    _loadedEpisodeId = episode.id;
    _liveCaptions = episode.customCaptions;
    _liveChapters = episode.customChapters;

    if (episode.transcriptUrl != null && _liveCaptions == null) {
      _transcriptService
          .loadCaptions(episode.transcriptUrl!, type: episode.transcriptType)
          .then((captions) {
        if (mounted && captions != null && _loadedEpisodeId == episode.id) {
          setState(() {
            _liveCaptions = captions;
          });
        }
      });
    }

    if (episode.chaptersUrl != null && _liveChapters == null) {
      _transcriptService.loadChapters(episode.chaptersUrl!).then((chapters) {
        if (mounted && chapters != null && _loadedEpisodeId == episode.id) {
          setState(() {
            _liveChapters = chapters;
          });
        }
      });
    }
  }

  /// Set once the underlying listen stops (e.g. the sleep timer expires) so
  /// the route pops itself exactly once instead of once per rebuild.
  bool _exiting = false;

  Future<void> _openSleepTimer(BuildContext context) {
    return SleepTimerSheet.show(
      context,
      controller: widget.controller,
      showEndOfEpisode: true,
    );
  }

  /// Shares the current episode via the native share sheet. Guarded so the
  /// app stays quiet when sharing is unavailable (widget-test environment).
  Future<void> _shareEpisode(PodcastEpisode episode) async {
    final String text =
        'Listening to ${episode.title} on ${episode.podcastName}.';
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Podcast — ${episode.podcastName}'),
      );
    } catch (_) {
      // Sharing unavailable here; nothing to do.
    }
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (!widget.controller.podcastActive) {
          if (!_exiting) {
            _exiting = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).maybePop();
              }
            });
          }
          return const Scaffold(body: SizedBox.shrink());
        }
        _fetchMetadataIfAvailable();
        final PodcastEpisode baseEpisode = widget.controller.currentEpisode!;
        final PodcastEpisode episode = baseEpisode.copyWith(
          customCaptions: _liveCaptions,
          customChapters: _liveChapters,
        );
        final bool playing = widget.controller.isPlaying;
        final bool favourite = widget.controller.isSavedEpisode(episode.id);
        final Duration position = widget.controller.podcastPosition;
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const PlayerTopBar(label: 'PODCAST', backKey: ValueKey('podcast-back')),
                  _PlayerPageSwitch(index: _page, onChanged: _goToPage),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (page) => setState(() => _page = page),
                      children: [
                        _EpisodePanel(
                          episode: episode,
                          position: position,
                          onSeek: widget.controller.seek,
                        ),
                        PodcastChapters(
                          episode: episode,
                          position: position,
                          onTapChapter: widget.controller.seek,
                        ),
                        if (episode.transcriptAvailable)
                          PodcastCaptions(
                            episode: episode,
                            position: position,
                            onTapCaption: widget.controller.seek,
                          )
                        else
                          const _TranscriptPlaceholder(),
                      ],
                    ),
                  ),
                  _PodcastControls(
                    playing: playing,
                    onPlayPause: widget.controller.toggle,
                    onRewind: () => widget.controller.seek(
                      position - const Duration(seconds: 10),
                    ),
                    onForward: () => widget.controller.seek(
                      position + const Duration(seconds: 10),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SecondaryActions(
                    favourite: favourite,
                    onFavourite: () => widget.controller.toggleSavedEpisode(episode.id),
                    downloaded: widget.controller.isDownloaded(episode.id),
                    onDownload: () => widget.controller.toggleDownload(episode),
                    onShare: () => _shareEpisode(episode),
                    sleepActive: widget.controller.sleepActive,
                    onSleep: () => _openSleepTimer(context),
                  ),
                  if (widget.controller.sleepActive) ...[
                    const SizedBox(height: 16),
                    SleepTimerIndicator(controller: widget.controller),
                  ],
                  if (widget.controller.podcastStartFailed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        key: const ValueKey('offline-hint'),
                        "You're offline · Download this episode to listen without internet.",
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.podcastAccent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  NowPlayingInfo(title: episode.title, subtitle: episode.podcastName),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Episode-facing panel: artwork, show + episode, metadata, the scrubbable
/// timeline and the optional About section — in that priority order.
class _EpisodePanel extends StatefulWidget {
  const _EpisodePanel({
    required this.episode,
    required this.position,
    required this.onSeek,
  });

  final PodcastEpisode episode;
  final Duration position;
  final ValueChanged<Duration> onSeek;

  @override
  State<_EpisodePanel> createState() => _EpisodePanelState();
}

class _EpisodePanelState extends State<_EpisodePanel> {
  bool _aboutOpen = false;

  @override
  Widget build(BuildContext context) {
    final PodcastEpisode episode = widget.episode;
    final List<String> meta = [
      if (episode.episodeNumber != null) 'EPISODE ${episode.episodeNumber}',
      if (episode.published != null) episode.published!.toUpperCase(),
      formatDuration(episode.duration).toUpperCase(),
    ];
    final bool expandable = episode.about != null;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          PodcastArt(title: episode.podcastName, size: 110),
          const SizedBox(height: 18),
          Text(episode.podcastName.toUpperCase(), style: AppTextStyles.sectionLabel),
          const SizedBox(height: 8),
          Text(
            episode.title,
            key: const ValueKey('podcast-episode-title'),
            style: AppTextStyles.stationTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (meta.isNotEmpty) _MetaRow(pieces: meta),
          const SizedBox(height: 14),
          PodcastProgress(
            position: widget.position,
            duration: episode.duration,
            onSeek: widget.onSeek,
          ),
          if (expandable) ...[
            const SizedBox(height: 10),
            _AboutTile(episode: episode, open: _aboutOpen, onToggle: _toggleAbout),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _toggleAbout() {
    setState(() => _aboutOpen = !_aboutOpen);
  }
}

/// Small dotted metadata line, e.g. "EPISODE 184 · AUG 18 · 32:00".
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.pieces});

  final List<String> pieces;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < pieces.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '·',
                style: AppTextStyles.timeLabel.copyWith(color: colors.podcastAccent),
              ),
            ),
          Text(pieces[i], style: AppTextStyles.timeLabel),
        ],
      ],
    );
  }
}

/// A quiet expandable "About this episode" block. Collapses back to a single
/// hairline-topped row so it never crowds the controls.
class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.episode,
    required this.open,
    required this.onToggle,
  });

  final PodcastEpisode episode;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (episode.about == null) return const SizedBox.shrink();
    return GestureDetector(
      key: const ValueKey('podcast-about-toggle'),
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colors.hairline),
            bottom: BorderSide(color: colors.hairline),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('ABOUT THIS EPISODE', style: AppTextStyles.sectionLabel),
                const Spacer(),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more, size: 20, color: colors.ink),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: open
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        episode.about!,
                        style: AppTextStyles.stationProgramme.copyWith(height: 1.4),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet stand-in for episodes without a full transcript. Keeps the CAPTIONS
/// page navigable and explains what would otherwise be an empty grey area.
class _TranscriptPlaceholder extends StatelessWidget {
  const _TranscriptPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 34, color: colors.muted),
            const SizedBox(height: 16),
            const Text(
              'TRANSCRIPT',
              key: ValueKey('transcript-placeholder'),
              style: AppTextStyles.sectionLabel,
            ),
            const SizedBox(height: 10),
            Text(
              "A full transcript isn't available for this episode yet. "
              'Chapters still pick out the moments.',
              style: AppTextStyles.stationProgramme.copyWith(height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small three-part switcher above the player body: EPISODE | CHAPTERS |
/// CAPTIONS. Swiping the body also moves between the pages.
class _PlayerPageSwitch extends StatelessWidget {
  const _PlayerPageSwitch({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _segment(0, 'EPISODE'),
          const SizedBox(width: 18),
          _segment(1, 'CHAPTERS'),
          const SizedBox(width: 18),
          _segment(2, 'CAPTIONS'),
        ],
      ),
    );
  }

  Widget _segment(int target, String label) {
    final bool selected = index == target;
    return GestureDetector(
      key: ValueKey(
        target == 0
            ? 'player-page-episode'
            : target == 1
                ? 'player-page-chapters'
                : 'player-page-captions',
      ),
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(target),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 180),
        style: selected ? AppTextStyles.navLabel : AppTextStyles.sectionLabel,
        child: Text(label),
      ),
    );
  }
}

/// Primary transport: speed, rewind, the dominant Play/Pause, forward, equalizer settings.
class _PodcastControls extends StatefulWidget {
  const _PodcastControls({
    required this.playing,
    required this.onPlayPause,
    required this.onRewind,
    required this.onForward,
  });

  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback onRewind;
  final VoidCallback onForward;

  @override
  State<_PodcastControls> createState() => _PodcastControlsState();
}

class _PodcastControlsState extends State<_PodcastControls> {
  static const List<double> _speeds = [1, 1.5, 2];
  int _speedIndex = 0;

  void _cycleSpeed() {
    setState(() => _speedIndex = (_speedIndex + 1) % _speeds.length);
  }

  String _formatSpeed(double speed) {
    final String text = speed == speed.roundToDouble()
        ? speed.toInt().toString()
        : speed.toString();
    return '${text}x';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Playback speed
        GestureDetector(
          key: const ValueKey('podcast-speed'),
          behavior: HitTestBehavior.opaque,
          onTap: _cycleSpeed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Text(
                _formatSpeed(_speeds[_speedIndex]),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.ink,
                ),
              ),
            ),
          ),
        ),

        // Rewind 10s
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colors.ink.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            key: const ValueKey('podcast-rewind'),
            tooltip: 'Rewind 10 seconds',
            onPressed: widget.onRewind,
            icon: Icon(Icons.replay_10, size: 24, color: colors.ink),
          ),
        ),

        // Play/Pause squircle button
        SizedBox(
          key: const ValueKey('podcast-play-pause'),
          width: 88,
          height: 64,
          child: Material(
            borderRadius: BorderRadius.circular(20),
            color: colors.ink,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onPlayPause,
              child: Center(
                child: Icon(
                  widget.playing ? Icons.pause : Icons.play_arrow,
                  key: ValueKey(widget.playing ? 'icon-pause' : 'icon-play'),
                  size: 32,
                  color: colors.background,
                ),
              ),
            ),
          ),
        ),

        // Forward 10s
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colors.ink.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            key: const ValueKey('podcast-forward'),
            tooltip: 'Forward 10 seconds',
            onPressed: widget.onForward,
            icon: Icon(Icons.forward_10, size: 24, color: colors.ink),
          ),
        ),

        // Equalizer settings icon
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: Icon(Icons.tune, size: 22, color: colors.ink),
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}

/// Quiet secondary actions beneath the transport controls: favourite,
/// download, sleep timer, share. Playback-affecting options
/// are lightweight UI state only until the audio service grows.
class _SecondaryActions extends StatefulWidget {
  const _SecondaryActions({
    required this.favourite,
    required this.onFavourite,
    required this.downloaded,
    required this.onDownload,
    required this.onShare,
    required this.sleepActive,
    required this.onSleep,
  });

  final bool favourite;
  final VoidCallback onFavourite;
  final bool downloaded;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  final bool sleepActive;
  final VoidCallback onSleep;

  @override
  State<_SecondaryActions> createState() => _SecondaryActionsState();
}

class _SecondaryActionsState extends State<_SecondaryActions> {
  bool _optimisticDownloaded = false;

  @override
  void initState() {
    super.initState();
    _optimisticDownloaded = widget.downloaded;
  }

  @override
  void didUpdateWidget(covariant _SecondaryActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.downloaded != widget.downloaded) {
      _optimisticDownloaded = widget.downloaded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bool downloaded = widget.downloaded || _optimisticDownloaded;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.hairline),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PlayerIconButton(
            key: const ValueKey('podcast-favourite'),
            tooltip: 'Toggle favourite',
            onPressed: widget.onFavourite,
            icon: Icon(
              widget.favourite ? Icons.favorite : Icons.favorite_border,
              size: 21,
              color: widget.favourite ? colors.accent : colors.ink,
            ),
          ),
          PlayerIconButton(
            key: const ValueKey('podcast-download'),
            tooltip: downloaded ? 'Downloaded' : 'Download',
            onPressed: () {
              setState(() => _optimisticDownloaded = !downloaded);
              widget.onDownload();
            },
            icon: Icon(
              downloaded ? Icons.download_done : Icons.download_outlined,
              size: 22,
              color: downloaded ? colors.podcastAccent : colors.ink,
            ),
          ),
          PlayerIconButton(
            key: const ValueKey('podcast-sleep'),
            tooltip: 'Sleep timer',
            onPressed: widget.onSleep,
            icon: Icon(
              Icons.bedtime_outlined,
              size: 21,
              color: widget.sleepActive ? colors.podcastAccent : colors.ink,
            ),
          ),
          PlayerIconButton(
            key: const ValueKey('podcast-share'),
            tooltip: 'Share',
            onPressed: widget.onShare,
            icon: Icon(Icons.ios_share, size: 21, color: colors.ink),
          ),
        ],
      ),
    );
  }
}