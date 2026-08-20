import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/podcast_episode.dart';
import '../playback/playback_controller.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/now_playing_info.dart';
import '../widgets/play_pause_button.dart';
import '../widgets/player_icon_button.dart';
import '../widgets/player_top_bar.dart';
import '../widgets/podcast_art.dart';
import '../widgets/podcast_captions.dart';
import '../widgets/podcast_chapters.dart';
import '../widgets/podcast_progress.dart';

/// Full-screen podcast player.
///
/// The sibling of the Radio Player: same scaffold, top bar and Play/Pause
/// language, but a quieter, time-based personality — artwork, episode-first
/// typography, a scrubbable timeline, skip controls and a small set of quiet
/// secondary actions. A muted teal accent ([AppColors.podcastAccent]) marks
/// the podcast surfaces so they read as on-demand, different from radio's
/// live terracotta.
class PodcastPlayerScreen extends StatefulWidget {
  const PodcastPlayerScreen({super.key, required this.controller});

  final PlaybackController controller;

  @override
  State<PodcastPlayerScreen> createState() => _PodcastPlayerScreenState();
}

class _PodcastPlayerScreenState extends State<PodcastPlayerScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

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
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final PodcastEpisode episode = widget.controller.currentEpisode!;
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
                    onDownload: () => widget.controller.toggleDownloaded(episode.id),
                    onShare: () => _shareEpisode(episode),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < pieces.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '·',
                style: AppTextStyles.timeLabel.copyWith(color: AppColors.podcastAccent),
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
    if (episode.about == null) return const SizedBox.shrink();
    return GestureDetector(
      key: const ValueKey('podcast-about-toggle'),
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.hairline),
            bottom: BorderSide(color: AppColors.hairline),
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
                  child: const Icon(Icons.expand_more, size: 20, color: AppColors.ink),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.article_outlined, size: 34, color: AppColors.muted),
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

/// Primary transport: rewind, the dominant Play/Pause, forward.
class _PodcastControls extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PlayerIconButton(
                key: const ValueKey('podcast-rewind'),
                tooltip: 'Rewind 10 seconds',
                onPressed: onRewind,
                icon: const Icon(Icons.replay_10, size: 24, color: AppColors.ink),
              ),
              const SizedBox(width: 24),
            ],
          ),
        ),
        PlayPauseButton(
          key: const ValueKey('podcast-play-pause'),
          playing: playing,
          onPressed: onPlayPause,
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(width: 24),
              PlayerIconButton(
                key: const ValueKey('podcast-forward'),
                tooltip: 'Forward 10 seconds',
                onPressed: onForward,
                icon: const Icon(Icons.forward_10, size: 24, color: AppColors.ink),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Quiet secondary actions beneath the transport controls: favourite,
/// download, playback speed, sleep timer, share. Playback-affecting options
/// are lightweight UI state only until the audio service grows.
class _SecondaryActions extends StatefulWidget {
  const _SecondaryActions({
    required this.favourite,
    required this.onFavourite,
    required this.downloaded,
    required this.onDownload,
    required this.onShare,
  });

  final bool favourite;
  final VoidCallback onFavourite;
  final bool downloaded;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  @override
  State<_SecondaryActions> createState() => _SecondaryActionsState();
}

class _SecondaryActionsState extends State<_SecondaryActions> {
  static const List<double> _speeds = [1, 1.5, 2];
  int _speedIndex = 0;
  bool _sleep = false;

  void _cycleSpeed() {
    setState(() => _speedIndex = (_speedIndex + 1) % _speeds.length);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.hairline),
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
              color: widget.favourite ? AppColors.accent : AppColors.ink,
            ),
          ),
          PlayerIconButton(
            key: const ValueKey('podcast-download'),
            tooltip: widget.downloaded ? 'Downloaded' : 'Download',
            onPressed: widget.onDownload,
            icon: Icon(
              widget.downloaded ? Icons.download_done : Icons.download_outlined,
              size: 22,
              color: widget.downloaded ? AppColors.podcastAccent : AppColors.ink,
            ),
          ),
          PlayerIconButton(
            key: const ValueKey('podcast-speed'),
            tooltip: 'Playback speed',
            onPressed: _cycleSpeed,
            icon: Text(
              _formatSpeed(_speeds[_speedIndex]),
              style: AppTextStyles.playerStation.copyWith(fontSize: 12),
            ),
          ),
          PlayerIconButton(
            key: const ValueKey('podcast-sleep'),
            tooltip: 'Sleep timer',
            onPressed: () => setState(() => _sleep = !_sleep),
            icon: Icon(
              Icons.bedtime_outlined,
              size: 21,
              color: _sleep ? AppColors.podcastAccent : AppColors.ink,
            ),
          ),
          PlayerIconButton(
            key: const ValueKey('podcast-share'),
            tooltip: 'Share',
            onPressed: widget.onShare,
            icon: const Icon(Icons.ios_share, size: 21, color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  String _formatSpeed(double speed) {
    final String text = speed == speed.roundToDouble()
        ? speed.toInt().toString()
        : speed.toString();
    return '${text}x';
  }
}