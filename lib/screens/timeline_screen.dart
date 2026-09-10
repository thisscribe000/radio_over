import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/timeline/audio_snippet_exporter.dart';
import '../models/audio_snippet.dart';
import '../playback/playback_controller.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/podcast_art.dart';
import '../widgets/snippet_comments_sheet.dart';
import '../widgets/snippet_thread_sheet.dart';
import '../widgets/verified_badge.dart';
import 'podcast_player_screen.dart';
import 'user_profile_screen.dart';

/// Community timeline screen displaying podcast audio highlights and threads in a modern social feed.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({
    super.key,
    required this.controller,
  });

  final PlaybackController controller;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  int _activeTab = 0; // 0 = For you, 1 = Following

  Future<void> _shareSnippet(AudioSnippet snippet) async {
    final String text = snippet.isThread
        ? '🧵 Audio Thread (${snippet.threadTotal} clips) from "${snippet.episodeTitle}" (${snippet.podcastName}).'
        : '“${snippet.caption}” — Clip from ${snippet.episodeTitle} on ${snippet.podcastName}.';
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Podcast Highlight — ${snippet.podcastName}'),
      );
    } catch (_) {}
  }

  Future<void> _exportSnippetAudio(AudioSnippet snippet) async {
    try {
      final exporter = AudioSnippetExporter();
      await exporter.exportAndShare(
        snippet: snippet,
        downloadManager: widget.controller.downloads,
      );
    } catch (_) {}
  }

  void _openFullEpisode(BuildContext context, AudioSnippet snippet) {
    widget.controller.playSnippet(snippet);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PodcastPlayerScreen(controller: widget.controller),
      ),
    );
  }

  void _openThread(BuildContext context, AudioSnippet rootSnippet) {
    SnippetThreadSheet.show(
      context,
      controller: widget.controller,
      rootSnippet: rootSnippet,
    );
  }

  void _openComments(BuildContext context, AudioSnippet snippet) {
    SnippetCommentsSheet.show(
      context,
      controller: widget.controller,
      snippet: snippet,
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar: "For you | Following" + User Avatar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // For You Tab
                  GestureDetector(
                    key: const ValueKey('timeline-tab-for-you'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _activeTab = 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'For you',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                            color: _activeTab == 0 ? colors.ink : colors.muted,
                          ),
                        ),
                        if (_activeTab == 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            height: 2.5,
                            width: 24,
                            decoration: BoxDecoration(
                              color: colors.podcastAccent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Following Tab
                  GestureDetector(
                    key: const ValueKey('timeline-tab-following'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _activeTab = 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Following',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                            color: _activeTab == 1 ? colors.ink : colors.muted,
                          ),
                        ),
                        if (_activeTab == 1)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            height: 2.5,
                            width: 28,
                            decoration: BoxDecoration(
                              color: colors.podcastAccent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // User Avatar button
                  GestureDetector(
                    key: const ValueKey('timeline-profile-avatar'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openProfile(context),
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: colors.podcastAccent.withValues(alpha: 0.15),
                      child: Text(
                        widget.controller.username.isNotEmpty
                            ? widget.controller.username[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.podcastAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: colors.hairline),

            // Feed Content
            Expanded(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final List<AudioSnippet> allSnippets = widget.controller.snippets;
                  // Main feed surfaces root cards of threads and standalone snippets
                  List<AudioSnippet> feedSnippets =
                      allSnippets.where((s) => s.isThreadRoot).toList();

                  if (_activeTab == 1) {
                    feedSnippets = feedSnippets.where((s) {
                      return widget.controller.isFollowingCreator(s.userName) ||
                          widget.controller.isSavedShow(s.podcastId);
                    }).toList();
                  }

                  if (feedSnippets.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _activeTab == 1 ? Icons.people_outline : Icons.content_cut,
                              size: 48,
                              color: colors.muted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _activeTab == 1 ? 'NO FOLLOWED HIGHLIGHTS' : 'NO HIGHLIGHTS YET',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: colors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _activeTab == 1
                                  ? 'Follow podcast shows or creators to see their clips and highlights here.'
                                  : 'Play any podcast episode and tap the scissors icon to clip single moments or multi-part threads with the community.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: colors.muted, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    key: const ValueKey('timeline-list'),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    itemCount: feedSnippets.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final AudioSnippet snippet = feedSnippets[index];
                      final bool isPlayingThis = widget.controller.isPlaying &&
                          widget.controller.playingSnippet?.id == snippet.id;

                      final int commentsCount =
                          widget.controller.commentsCountFor(snippet.id);

                      return _SnippetCard(
                        snippet: snippet,
                        commentsCount: commentsCount,
                        isPlaying: isPlayingThis,
                        onPlayPause: () {
                          if (isPlayingThis) {
                            widget.controller.toggle();
                          } else {
                            widget.controller.playSnippet(snippet);
                          }
                        },
                        onLike: () => widget.controller.toggleLikeSnippet(snippet.id),
                        onShare: () => _shareSnippet(snippet),
                        onExportAudio: () => _exportSnippetAudio(snippet),
                        onComments: () => _openComments(context, snippet),
                        onFullEpisode: () => _openFullEpisode(context, snippet),
                        onOpenThread: snippet.isThread
                            ? () => _openThread(context, snippet)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visual card presenting one trimmed audio snippet or stacked thread root.
class _SnippetCard extends StatelessWidget {
  const _SnippetCard({
    required this.snippet,
    required this.commentsCount,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onLike,
    required this.onShare,
    this.onExportAudio,
    required this.onComments,
    required this.onFullEpisode,
    this.onOpenThread,
  });

  final AudioSnippet snippet;
  final int commentsCount;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback? onExportAudio;
  final VoidCallback onComments;
  final VoidCallback onFullEpisode;
  final VoidCallback? onOpenThread;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final String initial =
        snippet.userName.isNotEmpty ? snippet.userName[0].toUpperCase() : 'U';

    final Widget mainCard = Container(
      key: ValueKey('snippet-card-${snippet.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPlaying ? colors.podcastAccent : colors.hairline,
          width: isPlaying ? 1.5 : 1,
        ),
        boxShadow: isPlaying
            ? [
                BoxShadow(
                  color: colors.podcastAccent.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Creator Header & Verified Badge
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: snippet.isVerified
                    ? colors.accent.withValues(alpha: 0.18)
                    : colors.podcastAccent.withValues(alpha: 0.15),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: snippet.isVerified ? colors.accent : colors.podcastAccent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            snippet.userName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (snippet.isVerified) ...[
                          const SizedBox(width: 4),
                          const VerifiedBadge(size: 13),
                        ],
                        const SizedBox(width: 6),
                        Text(
                          '• ${formatUpdatedAgo(snippet.createdAt)}',
                          style: TextStyle(fontSize: 11, color: colors.muted),
                        ),
                      ],
                    ),
                    if (snippet.isThread)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Text('🧵', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 3),
                            Text(
                              'THREAD (${snippet.threadTotal} CLIPS)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colors.accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.podcastAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 12, color: colors.podcastAccent),
                    const SizedBox(width: 3),
                    Text(
                      snippet.isThread
                          ? 'Part 1 of ${snippet.threadTotal}'
                          : '${snippet.snippetDuration.inSeconds}s',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.podcastAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // User Caption / Thought
          Text(
            snippet.caption,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 14),

          // Audio Clip Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.hairline),
            ),
            child: Row(
              children: [
                // Episode Art
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: PodcastArt(
                      title: snippet.podcastName,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Episode and Timestamp details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snippet.episodeTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${snippet.podcastName} · ${formatDuration(snippet.start)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Play / Pause Circle
                IconButton(
                  key: ValueKey('snippet-play-${snippet.id}'),
                  icon: Icon(
                    isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 34,
                    color: colors.podcastAccent,
                  ),
                  onPressed: onPlayPause,
                ),
              ],
            ),
          ),

          // View Thread Affordance if thread
          if (snippet.isThread && onOpenThread != null) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: onOpenThread,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.view_headline_rounded, size: 14, color: colors.accent),
                    const SizedBox(width: 6),
                    Text(
                      'VIEW FULL THREAD (${snippet.threadTotal} CLIPS)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, size: 16, color: colors.accent),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Social Action Pills Row: Comments, Share, Like, Full Episode
          Row(
            children: [
              // Comment Button Pill
              GestureDetector(
                key: ValueKey('snippet-comment-${snippet.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: onComments,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.hairline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 14, color: colors.muted),
                      const SizedBox(width: 5),
                      Text(
                        '$commentsCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Like Button Pill
              GestureDetector(
                key: ValueKey('snippet-like-${snippet.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: onLike,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: snippet.isLiked
                        ? colors.accent.withValues(alpha: 0.12)
                        : colors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: snippet.isLiked
                          ? colors.accent.withValues(alpha: 0.3)
                          : colors.hairline,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        snippet.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 14,
                        color: snippet.isLiked ? colors.accent : colors.muted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${snippet.likesCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: snippet.isLiked ? colors.accent : colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Share Button Pill
              GestureDetector(
                key: ValueKey('snippet-share-${snippet.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: onShare,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.hairline),
                  ),
                  child: Icon(Icons.ios_share, size: 14, color: colors.muted),
                ),
              ),

              if (onExportAudio != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  key: ValueKey('snippet-export-${snippet.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onExportAudio,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.hairline),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_rounded, size: 13, color: colors.podcastAccent),
                        const SizedBox(width: 3),
                        Text(
                          'MP3',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colors.podcastAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // Jump to Full Episode Button
              TextButton.icon(
                key: ValueKey('snippet-full-${snippet.id}'),
                icon: const Icon(Icons.headphones, size: 13),
                label: const Text('FULL EPISODE'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.podcastAccent,
                  textStyle: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onPressed: onFullEpisode,
              ),
            ],
          ),
        ],
      ),
    );

    // If it's a thread, wrap in a "Stacked Cards" visual design
    if (snippet.isThread) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Stack Layer 2
          Positioned(
            left: 12,
            right: 12,
            bottom: -8,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: colors.card.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.hairline),
              ),
            ),
          ),
          // Background Stack Layer 1
          Positioned(
            left: 6,
            right: 6,
            bottom: -4,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: colors.card.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.hairline),
              ),
            ),
          ),
          // Main Front Card
          mainCard,
        ],
      );
    }

    return mainCard;
  }
}
