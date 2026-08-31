import 'package:flutter/material.dart';

import '../data/content_scope.dart';
import '../models/podcast_episode.dart';
import '../playback/playback_controller.dart';
import '../theme.dart';
import '../widgets/podcast_art.dart';
import '../widgets/podcast_mini_player.dart';
import '../widgets/radio_mini_player.dart';
import 'podcast_detail_screen.dart';

/// Renders a host/publisher creator profile page.
///
/// Under the Hybrid Creator Ramp strategy, this shows the creator's identity,
/// lists all shows they host/publish, consolidates all their episodes,
/// and allows the listener to follow them.
class CreatorProfileScreen extends StatefulWidget {
  const CreatorProfileScreen({
    super.key,
    required this.creatorName,
    required this.controller,
    required this.content,
  });

  final String creatorName;
  final PlaybackController controller;
  final AppContent content;

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  String? _dismissedRadio;
  String? _dismissedPodcast;

  PlaybackController get controller => widget.controller;

  List<PodcastSeries> get _creatorShows => widget.content.shows
      .where((s) => s.publisher.toLowerCase() == widget.creatorName.toLowerCase())
      .toList();

  List<PodcastEpisode> get _combinedEpisodes {
    final List<PodcastEpisode> list = [];
    for (final PodcastSeries show in _creatorShows) {
      list.addAll(show.episodes);
    }
    // Sort latest episodes first by episode number or name fallback
    list.sort((a, b) => (b.episodeNumber ?? 0).compareTo(a.episodeNumber ?? 0));
    return list;
  }

  @override
  void initState() {
    super.initState();
    controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _toggleFollow() {
    controller.toggleFollowCreator(widget.creatorName);
  }

  void _openShow(PodcastSeries show) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PodcastDetailScreen(
          show: show,
          controller: controller,
          content: widget.content,
        ),
      ),
    );
  }

  void _playEpisode(PodcastEpisode episode) {
    controller.playPodcastEpisode(episode);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bool isFollowing = controller.isFollowingCreator(widget.creatorName);
    final List<PodcastSeries> shows = _creatorShows;
    final List<PodcastEpisode> episodes = _combinedEpisodes;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            Container(
              height: 56,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.hairline)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    child: IconButton(
                      key: const ValueKey('creator-back'),
                      icon: Icon(Icons.arrow_back, color: colors.ink),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Text(
                    'CREATOR PROFILE',
                    style: TextStyle(
                      fontFamily: 'Ahem',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: colors.ink,
                    ),
                  ),
                ],
              ),
            ),
            // Profile Body
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 96),
                      children: [
                        // Profile Card
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PodcastArt(
                              title: widget.creatorName,
                              size: 76,
                              showInitials: true,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.creatorName,
                                    style: TextStyle(
                                      fontFamily: 'Ahem',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: colors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${shows.length} shows · ${episodes.length} episodes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  GestureDetector(
                                    key: const ValueKey('creator-follow-button'),
                                    onTap: _toggleFollow,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isFollowing
                                              ? colors.podcastAccent
                                              : colors.hairline,
                                        ),
                                        color: isFollowing
                                            ? colors.podcastAccent.withValues(alpha: 0.06)
                                            : Colors.transparent,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        isFollowing ? 'FOLLOWING' : 'FOLLOW CREATOR',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isFollowing
                                              ? colors.podcastAccent
                                              : colors.ink,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Bio description
                        Text(
                          'Host, creator, and storyteller exploring modern cultures, technology, and narratives. Uploads distributed under the Radio Over Creator Portal.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: colors.muted,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Section 1: SHOWS
                        const Text('PUBLISHED SHOWS', style: AppTextStyles.sectionLabel),
                        const SizedBox(height: 10),
                        if (shows.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'No published shows yet.',
                              style: TextStyle(color: colors.muted),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: shows.length,
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, color: colors.hairline),
                            itemBuilder: (context, index) {
                              final PodcastSeries show = shows[index];
                              return ListTile(
                                key: ValueKey('creator-show-${show.id}'),
                                contentPadding: EdgeInsets.zero,
                                leading: PodcastArt(title: show.name, size: 44),
                                title: Text(
                                  show.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  show.category,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: const Icon(Icons.chevron_right, size: 18),
                                onTap: () => _openShow(show),
                              );
                            },
                          ),

                        const SizedBox(height: 32),

                        // Section 2: COMBINED TIMELINE
                        const Text('EPISODES FEED', style: AppTextStyles.sectionLabel),
                        const SizedBox(height: 10),
                        if (episodes.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'No episodes available.',
                              style: TextStyle(color: colors.muted),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: episodes.length,
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, color: colors.hairline),
                            itemBuilder: (context, index) {
                              final PodcastEpisode ep = episodes[index];
                              final bool isCurrent =
                                  controller.currentEpisode?.id == ep.id;
                              final bool isPlaying =
                                  isCurrent && controller.isPlaying;

                              return ListTile(
                                key: ValueKey('creator-episode-${ep.id}'),
                                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                title: Text(
                                  ep.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isCurrent ? colors.podcastAccent : colors.ink,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    '${ep.podcastName} · ${ep.published}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                    color: isCurrent ? colors.podcastAccent : colors.ink,
                                    size: 28,
                                  ),
                                  onPressed: () => _playEpisode(ep),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  // Mini Players
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (controller.radioActive &&
                            controller.currentStation != null &&
                            _dismissedRadio != controller.currentStation!.name)
                          RadioMiniPlayer(
                            controller: controller,
                            onDismiss: () => setState(() =>
                                _dismissedRadio = controller.currentStation!.name),
                          ),
                        if (controller.podcastActive &&
                            controller.currentEpisode != null &&
                            _dismissedPodcast != controller.currentEpisode!.title)
                          PodcastMiniPlayer(
                            controller: controller,
                            onDismiss: () => setState(() =>
                                _dismissedPodcast = controller.currentEpisode!.title),
                          ),
                      ],
                    ),
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
