import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/audio_snippet.dart';
import '../playback/playback_controller.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'snippet_comments_sheet.dart';
import 'verified_badge.dart';

/// Modal bottom sheet displaying all connected parts of an Audio Thread
/// with interactive playback, continuous autoplay, and full thread details.
class SnippetThreadSheet extends StatelessWidget {
  const SnippetThreadSheet({
    super.key,
    required this.controller,
    required this.rootSnippet,
  });

  final PlaybackController controller;
  final AudioSnippet rootSnippet;

  static Future<void> show(
    BuildContext context, {
    required PlaybackController controller,
    required AudioSnippet rootSnippet,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SnippetThreadSheet(
        controller: controller,
        rootSnippet: rootSnippet,
      ),
    );
  }

  void _shareThread(List<AudioSnippet> parts) async {
    final String title = rootSnippet.episodeTitle;
    final String show = rootSnippet.podcastName;
    final String text =
        '🧵 Audio Thread (${parts.length} parts) on "$title" ($show).\n\n'
        'Listen to the full highlight thread on radio_over!';
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Audio Thread — $show'),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final List<AudioSnippet> parts = rootSnippet.threadId != null
            ? controller.threadSnippets(rootSnippet.threadId!)
            : [rootSnippet];

        final int totalSec = parts.fold<int>(
          0,
          (sum, p) => sum + p.snippetDuration.inSeconds,
        );

        return Container(
          key: const ValueKey('snippet-thread-sheet'),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 24,
          ),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: colors.hairline, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🧵', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(
                          'AUDIO THREAD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colors.accent,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (rootSnippet.isVerified) ...[
                    const SizedBox(width: 8),
                    const VerifiedBadge(size: 13, showLabel: true, label: 'CREATOR'),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.share_outlined, size: 20, color: colors.ink),
                    onPressed: () => _shareThread(parts),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: colors.muted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Episode Info & Creator
              Text(
                rootSnippet.episodeTitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Text(
                    'by ${rootSnippet.userName}',
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                  const SizedBox(width: 8),
                  Text('•', style: TextStyle(fontSize: 12, color: colors.muted)),
                  const SizedBox(width: 8),
                  Text(
                    '${parts.length} parts (${totalSec}s total)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.podcastAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: colors.hairline),
              const SizedBox(height: 12),

              // Parts List with Timeline Thread Line
              Expanded(
                child: ListView.builder(
                  itemCount: parts.length,
                  itemBuilder: (context, index) {
                    final AudioSnippet part = parts[index];
                    final bool isLast = index == parts.length - 1;
                    final bool isPlayingThis = controller.isPlaying &&
                        controller.playingSnippet?.id == part.id;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Vertical Timeline Connector
                          SizedBox(
                            width: 28,
                            child: Column(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isPlayingThis
                                        ? colors.accent
                                        : colors.podcastAccent,
                                    border: Border.all(
                                      color: colors.card,
                                      width: 2,
                                    ),
                                  ),
                                  child: isPlayingThis
                                      ? const Center(
                                          child: Icon(
                                            Icons.play_arrow,
                                            size: 8,
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                                if (!isLast)
                                  Expanded(
                                    child: Container(
                                      width: 2,
                                      color: colors.hairline,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Part Card
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isPlayingThis
                                      ? colors.accent.withValues(alpha: 0.08)
                                      : colors.background,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isPlayingThis
                                        ? colors.accent
                                        : colors.hairline,
                                    width: isPlayingThis ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Part Index & Duration Pill
                                    Row(
                                      children: [
                                        Text(
                                          'PART ${part.threadIndex} OF ${part.threadTotal}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                            color: isPlayingThis
                                                ? colors.accent
                                                : colors.muted,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.card,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: colors.hairline),
                                          ),
                                          child: Text(
                                            '${formatDuration(part.start)} - ${formatDuration(part.end)} (${part.snippetDuration.inSeconds}s)',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: colors.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Caption
                                    Text(
                                      part.caption,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.35,
                                        fontWeight: FontWeight.w500,
                                        color: colors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Playback Row
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            if (isPlayingThis) {
                                              controller.toggle();
                                            } else {
                                              controller.playSnippet(part);
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isPlayingThis
                                                  ? colors.accent
                                                  : colors.podcastAccent,
                                            ),
                                            child: Icon(
                                              isPlayingThis
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _MiniWaveform(
                                            isPlaying: isPlayingThis,
                                            activeColor: colors.accent,
                                            inactiveColor: colors.hairline,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        IconButton(
                                          icon: Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 16,
                                            color: colors.muted,
                                          ),
                                          onPressed: () =>
                                              SnippetCommentsSheet.show(
                                            context,
                                            controller: controller,
                                            snippet: part,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            part.isLiked
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            size: 18,
                                            color: part.isLiked
                                                ? Colors.redAccent
                                                : colors.muted,
                                          ),
                                          onPressed: () =>
                                              controller.toggleLikeSnippet(part.id),
                                        ),
                                        Text(
                                          '${part.likesCount}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MiniWaveform extends StatelessWidget {
  const _MiniWaveform({
    required this.isPlaying,
    required this.activeColor,
    required this.inactiveColor,
  });

  final bool isPlaying;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(24, (index) {
          final double height =
              4.0 + 10.0 * (0.4 + 0.6 * math.sin(index * 0.9)).abs();
          return Container(
            width: 2.5,
            height: height,
            decoration: BoxDecoration(
              color: isPlaying ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
}
