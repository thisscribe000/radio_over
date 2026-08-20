import 'package:flutter/material.dart';

import '../models/podcast_episode.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Chapter markers for the podcast player, one per "segment" of the show.
///
/// A quiet editorial list: each chapter shows its title and start time, the
/// chapter currently playing is emphasised while the rest recede, and tapping
/// any row seeks to that moment — the same language the captions page uses.
class PodcastChapters extends StatelessWidget {
  const PodcastChapters({
    super.key,
    required this.episode,
    required this.position,
    required this.onTapChapter,
  });

  final PodcastEpisode episode;
  final Duration position;
  final ValueChanged<Duration> onTapChapter;

  int get _activeIndex {
    final List<PodcastChapter> chapters = episode.chapters;
    int index = 0;
    for (int i = 0; i < chapters.length; i++) {
      if (chapters[i].start <= position) index = i;
    }
    return index;
  }

  @override
  Widget build(BuildContext context) {
    final List<PodcastChapter> chapters = episode.chapters;
    final int active = _activeIndex;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: chapters.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),
      itemBuilder: (context, index) {
        final PodcastChapter chapter = chapters[index];
        final bool current = index == active;
        return GestureDetector(
          key: ValueKey('chapter-$index'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onTapChapter(chapter.start),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    style: current
                        ? const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: AppColors.ink,
                          )
                        : const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                            color: AppColors.muted,
                          ),
                    child: Text(chapter.title),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 42,
                  child: Text(
                    formatDuration(chapter.start),
                    style: AppTextStyles.timeLabel.copyWith(
                      color: current ? AppColors.podcastAccent : AppColors.muted,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}