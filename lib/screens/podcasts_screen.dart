import 'package:flutter/material.dart';

import '../models/podcast_episode.dart';
import '../playback/playback_controller.dart';
import '../screens/podcast_detail_screen.dart';
import '../screens/podcast_player_screen.dart';
import '../screens/search_screen.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/podcast_art.dart';

/// Podcast discovery categories used by the EXPLORE section.
const List<String> podcastCategories = [
  'News',
  'Business',
  'Technology',
  'Culture',
  'Education',
  'Stories',
  'Religion',
  'Science',
  'Sports',
  'Comedy',
];

/// The Podcast Home / discovery screen.
///
/// The sibling of the Radio Home screen: the same editorial visual language,
/// but the hierarchy answers a different question. Radio asks "what's live
/// now?" — structure starts from a featured broadcast and live discovery.
/// Podcasts ask "what do I want to listen to?" — structure starts from
/// continuing what was already being heard, then curated discovery by subject.
///
/// Ordered by intent:
///  1. CONTINUE LISTENING — get back into what was already playing
///  2. FEATURED — show something interesting
///  3. LATEST EPISODES — what's new
///  4. EXPLORE — what subjects interest me
///  5. POPULAR SHOWS / YOUR SAVED PODCASTS — discover and return to shows
///
/// The persistent mini-player slot lives in the app shell, so this screen
/// only ever hands episodes to the shared [PlaybackController].
class PodcastsScreen extends StatefulWidget {
  const PodcastsScreen({super.key, required this.controller});

  final PlaybackController controller;

  @override
  State<PodcastsScreen> createState() => _PodcastsScreenState();
}

class _PodcastsScreenState extends State<PodcastsScreen> {
  /// The EXPLORE chip currently selected, if any.
  String? _exploreCategory;

  PlaybackController get controller => widget.controller;

  void _playEpisode(PodcastEpisode episode) {
    controller.playPodcastEpisode(episode);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PodcastPlayerScreen(controller: controller),
      ),
    );
  }

  /// Opens the Podcast Detail screen for a show. The detail screen owns
  /// browsing, following and starting episodes; it connects onwards to the
  /// existing Podcast Player and the shared mini-player slot.
  void _openShow(PodcastSeries show) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PodcastDetailScreen(
          show: show,
          controller: controller,
        ),
      ),
    );
  }

  /// Opens the global search surface from the home screen's search entry.
  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchScreen(controller: controller),
      ),
    );
  }

  /// Episodes that can be picked up where they were left: the episode
  /// currently audibly in progress (live position) plus any episodes with
  /// saved progress in the catalogue. Data-driven so a real backend simply
  /// supplies positions and this section lights up.
  List<PodcastEpisode> _inProgress() {
    final List<PodcastEpisode> inProgress = [];
    final PodcastEpisode? current = controller.currentEpisode;
    if (controller.podcastActive &&
        current != null &&
        controller.podcastPosition > Duration.zero &&
        controller.podcastPosition < current.duration) {
      inProgress.add(current);
    }
    for (final PodcastEpisode episode in mockPodcastEpisodes) {
      if (episode.position > Duration.zero &&
          !inProgress.any((e) => e.id == episode.id)) {
        inProgress.add(episode);
      }
    }
    return inProgress;
  }

  List<PodcastSeries> get _savedShows =>
      [for (final PodcastSeries show in mockPodcasts) if (controller.isSavedShow(show.id)) show];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Expanded(
                child: Text(
                  'PODCASTS',
                  key: ValueKey('podcasts-title'),
                  style: AppTextStyles.display,
                ),
              ),
              _SearchEntry(key: const ValueKey('podcast-search'), onTap: _openSearch),
            ],
          ),
        ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text('Find something worth hearing.', style: AppTextStyles.stationName),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => ListView(
                  key: const ValueKey('podcast-home-list'),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  children: [
                    _buildContinueListening(),
                    const SizedBox(height: 34),
                    _buildFeatured(),
                    const SizedBox(height: 34),
                    _buildLatest(),
                    const SizedBox(height: 34),
                    _buildExplore(),
                    const SizedBox(height: 34),
                    _buildPopular(),
                    const SizedBox(height: 34),
                    _buildSaved(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. CONTINUE LISTENING ----------------------------------------------

  Widget _buildContinueListening() {
    final List<PodcastEpisode> inProgress = _inProgress();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CONTINUE LISTENING', key: ValueKey('section-continue'), style: AppTextStyles.sectionLabel),
        const SizedBox(height: 12),
        if (inProgress.isEmpty)
          _ContinueEmpty()
        else
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: inProgress.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final PodcastEpisode episode = inProgress[index];
                return _ContinueCard(
                  episode: episode,
                  onTap: () => _playEpisode(episode),
                );
              },
            ),
          ),
      ],
    );
  }

  // --- 2. FEATURED --------------------------------------------------------

  Widget _buildFeatured() {
    final PodcastSeries show = featuredPodcast;
    final PodcastEpisode episode = featuredEpisode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FEATURED', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 12),
        _FeaturedBlock(
          show: show,
          episode: episode,
          onTap: () => _openShow(show),
        ),
      ],
    );
  }

  // --- 3. LATEST EPISODES --------------------------------------------------

  Widget _buildLatest() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LATEST EPISODES', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 6),
        for (final PodcastEpisode episode in mockPodcastEpisodes) ...[
          _LatestRow(episode: episode, onTap: () => _playEpisode(episode)),
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),
        ],
      ],
    );
  }

  // --- 4. EXPLORE ----------------------------------------------------------

  Widget _buildExplore() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('EXPLORE', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final String category in podcastCategories)
              _ExploreChip(
                label: category,
                selected: _exploreCategory == category,
                onTap: () => setState(() {
                  _exploreCategory = _exploreCategory == category ? null : category;
                }),
              ),
          ],
        ),
      ],
    );
  }

  // --- 5. POPULAR SHOWS ----------------------------------------------------

  Widget _buildPopular() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('POPULAR SHOWS', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 4),
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: mockPodcasts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final PodcastSeries show = mockPodcasts[index];
              return _ShowCard(
                show: show,
                saved: controller.isSavedShow(show.id),
                onTap: () => _openShow(show),
                onSave: () => controller.toggleSavedShow(show.id),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 6. YOUR SAVED PODCASTS ----------------------------------------------

  Widget _buildSaved() {
    final List<PodcastSeries> saved = _savedShows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('YOUR SAVED PODCASTS', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 6),
        if (saved.isEmpty)
          const _SavedEmpty()
        else
          for (final PodcastSeries show in saved) ...[
            _SavedRow(
              show: show,
              onTap: () => _openShow(show),
              onRemove: () => controller.toggleSavedShow(show.id),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.hairline),
          ],
      ],
    );
  }
}

/// Quiet search entry point. Search lives on its own surface; this affordance
/// opens it so the home screen stays a discovery page.
class _SearchEntry extends StatelessWidget {
  const _SearchEntry({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            const Icon(Icons.search, size: 17, color: AppColors.muted),
            const SizedBox(width: 6),
            Text('SEARCH', style: AppTextStyles.navLabel.copyWith(color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

/// Tasteful empty state for CONTINUE LISTENING before any episode is started.
class _ContinueEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('podcast-continue-empty'),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      child: Column(
        children: const [
          Text(
            'Nothing in progress',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink),
          ),
          SizedBox(height: 8),
          Text(
            'Episodes you start will appear here, ready to continue.',
            style: AppTextStyles.stationCategory,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A horizontal continue-listening card: artwork, show + episode, a thin
/// progress line with the time remaining, and a quiet play affordance.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.episode, required this.onTap});

  final PodcastEpisode episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double fraction = episode.duration.inMilliseconds == 0
        ? 0
        : (episode.position.inMilliseconds / episode.duration.inMilliseconds).clamp(0.0, 1.0);
    return GestureDetector(
      key: ValueKey('continue-${episode.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.hairline),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PodcastArt(title: episode.podcastName, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(episode.podcastName.toUpperCase(), style: AppTextStyles.playerStation),
                      const SizedBox(height: 4),
                      Text(
                        episode.title,
                        style: AppTextStyles.stationName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
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
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${formatDuration(episode.position)} / ${formatDuration(episode.duration)}',
                  style: AppTextStyles.timeLabel,
                ),
                const Spacer(),
                const _PodcastPlayCircle(size: 26),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The FEATURED show: artwork, show and episode identity, the show's short
/// description, then a play action. Bordered and editorial — not a banner.
class _FeaturedBlock extends StatelessWidget {
  const _FeaturedBlock({
    required this.show,
    required this.episode,
    required this.onTap,
  });

  final PodcastSeries show;
  final PodcastEpisode episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String meta = [
      show.category.toUpperCase(),
      if (episode.episodeNumber != null) 'EPISODE ${episode.episodeNumber}',
      episode.published?.toUpperCase(),
    ].whereType<String>().join(' · ');

    return GestureDetector(
      key: const ValueKey('podcast-featured'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.hairline),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PodcastArt(title: show.name, size: 76),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(show.name.toUpperCase(), style: AppTextStyles.playerStation),
                      const SizedBox(height: 6),
                      Text(
                        episode.title,
                        style: AppTextStyles.stationName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(meta, style: AppTextStyles.timeLabel),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              show.description,
              style: AppTextStyles.stationProgramme,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text('PLAY EPISODE', style: AppTextStyles.nowPlayingLabel),
                const Spacer(),
                const _PodcastPlayCircle(
                  key: ValueKey('podcast-featured-play'),
                  size: 40,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single latest-episode row: artwork, show and episode identity on the
/// left, duration and date stacked on the right, a play circle at the end.
class _LatestRow extends StatelessWidget {
  const _LatestRow({required this.episode, required this.onTap});

  final PodcastEpisode episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('latest-${episode.id}'),
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
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatDuration(episode.duration), style: AppTextStyles.timeLabel),
                const SizedBox(height: 4),
                Text(episode.published?.toUpperCase() ?? '', style: AppTextStyles.timeLabel),
              ],
            ),
            const SizedBox(width: 14),
            const _PodcastPlayCircle(size: 30),
          ],
        ),
      ),
    );
  }
}

/// A compact, selectable EXPLORE chip. Single-select; tapping again clears.
class _ExploreChip extends StatelessWidget {
  const _ExploreChip({
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
      key: ValueKey('podcast-category-$label'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? AppColors.ink : AppColors.hairline),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: selected ? AppTextStyles.navLabel : AppTextStyles.sectionLabel,
          child: Text(label),
        ),
      ),
    );
  }
}

/// A compact podcast-level card for POPULAR SHOWS. Tapping opens the show
/// (via its latest episode for now); the bookmark toggles it in SAVED.
class _ShowCard extends StatelessWidget {
  const _ShowCard({
    required this.show,
    required this.saved,
    required this.onTap,
    required this.onSave,
  });

  final PodcastSeries show;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('show-${show.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 176,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.hairline),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PodcastArt(title: show.name, size: 44),
                const Spacer(),
                GestureDetector(
                  key: ValueKey('save-${show.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onSave,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      saved ? Icons.bookmark : Icons.bookmark_border,
                      size: 18,
                      color: saved ? AppColors.podcastAccent : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              show.name,
              style: AppTextStyles.stationName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(show.category, style: AppTextStyles.stationCategory),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.play_arrow_rounded, size: 18, color: AppColors.ink),
                const SizedBox(width: 2),
                const Text('LISTEN', style: AppTextStyles.nowPlayingLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A saved-show row in YOUR SAVED PODCASTS, with a quiet remove control.
class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.show,
    required this.onTap,
    required this.onRemove,
  });

  final PodcastSeries show;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('saved-${show.id}'),
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
                  Text(show.category.toUpperCase(), style: AppTextStyles.sectionLabel),
                ],
              ),
            ),
            GestureDetector(
              key: ValueKey('unsave-${show.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.bookmark, size: 20, color: AppColors.podcastAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clean empty state for YOUR SAVED PODCASTS.
class _SavedEmpty extends StatelessWidget {
  const _SavedEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('podcast-saved-empty'),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      child: Column(
        children: const [
          Text(
            'Nothing saved yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.ink),
          ),
          SizedBox(height: 8),
          Text(
            'Save podcasts and episodes to find them here later.',
            style: AppTextStyles.stationCategory,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The small filled play circle used across the podcast home. Purely the
/// call-to-action visual — activation happens on the parent row or card so
/// taps never need to thread through a nested button.
class _PodcastPlayCircle extends StatelessWidget {
  const _PodcastPlayCircle({super.key, this.size = 32});

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