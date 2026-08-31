import 'package:flutter/material.dart';

import '../models/podcast_episode.dart';
import '../playback/playback_controller.dart';
import '../screens/podcast_player_screen.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'podcast_art.dart';

/// On-demand podcast strip pinned to the bottom of the screen.
///
/// Tapping the strip opens the full podcast player. A close affordance lets
/// the listener dismiss the player; the session is remembered in the shell so
/// it returns until the strip is dismissed or playback ends.
class PodcastMiniPlayer extends StatelessWidget {
  const PodcastMiniPlayer({
    super.key,
    required this.controller,
    required this.onDismiss,
  });

  final PlaybackController controller;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final PodcastEpisode episode = controller.currentEpisode!;
    final bool playing = controller.isPlaying;
    final double progress = episode.duration.inMilliseconds == 0
        ? 0
        : (episode.position.inMilliseconds / episode.duration.inMilliseconds).clamp(0.0, 1.0);

    return SafeArea(
      top: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PodcastPlayerScreen(controller: controller),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: colors.hairline),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 14, 8, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  PodcastArt(title: episode.podcastName, size: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(episode.podcastName.toUpperCase(), style: AppTextStyles.playerStation),
                        const SizedBox(height: 3),
                        Text(episode.title, style: AppTextStyles.playerProgram),
                      ],
                    ),
                  ),
                  if (controller.sleepActive) ...[
                    Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.bedtime_outlined, size: 15, color: colors.muted),
                    ),
                  ],
                  IconButton(
                    key: const ValueKey('podcast-mini-dismiss'),
                    tooltip: 'Close',
                    onPressed: onDismiss,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close, size: 20, color: colors.muted),
                  ),
                  IconButton(
                    onPressed: controller.toggle,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      playing ? Icons.pause : Icons.play_arrow_outlined,
                      size: 28,
                      color: colors.ink,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 6),
                child: Row(
                  children: [
                    Text(formatDuration(episode.position), style: AppTextStyles.timeLabel),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: SizedBox(
                          height: 2,
                          child: ColoredBox(
                            color: colors.hairline,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: ColoredBox(color: colors.podcastAccent),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(formatDuration(episode.duration), style: AppTextStyles.timeLabel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}