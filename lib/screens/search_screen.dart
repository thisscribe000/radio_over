import 'dart:async';

import 'package:flutter/material.dart';

import '../data/content_scope.dart';
import '../models/podcast_episode.dart';
import '../models/station.dart';
import '../playback/playback_controller.dart';
import '../screens/podcast_detail_screen.dart';
import '../screens/podcast_player_screen.dart';
import '../screens/radio_player_screen.dart';
import '../search/recent_searches.dart';
import '../search/search_engine.dart';
import '../search/search_result.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/active_dot.dart';
import '../widgets/live_badge.dart';
import '../widgets/podcast_art.dart';
import '../widgets/podcast_mini_player.dart';
import '../widgets/radio_mini_player.dart';

/// Global audio search.
///
/// One field searches the whole catalogue — stations, podcasts and episodes —
/// so the listener never has to first decide whether the thing they want is
/// radio or on-demand. Type once, find the audio.
///
/// The screen is deliberately quiet: a back button and a bordered field up
/// top, then content. Before typing it shows RECENT SEARCHES and TRENDING;
/// while typing it shows a TOP RESULT and grouped RADIO / PODCAST / EPISODE
/// rows routed into the existing screens. The shared mini-player slot stays
/// pinned at the bottom so the current broadcast or episode keeps playing.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.controller,
    this.recentSearches,
    this.content,
  });

  final PlaybackController controller;

  /// Store for search history; defaults to a fresh in-memory store so it can
  /// be hosted above this screen (or persisted) without UI changes.
  final RecentSearches? recentSearches;

  /// Content source; defaults to the offline mock scope when not provided.
  final AppContent? content;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const Duration _debounceDuration = Duration(milliseconds: 180);

  final TextEditingController _query = TextEditingController();
  late final AppContent _content = widget.content ?? AppContent.mock();
  late final SearchEngine _engine = SearchEngine(content: _content);
  late final RecentSearches _recentSearches =
      widget.recentSearches ?? RecentSearches();

  Timer? _debounce;
  String _term = '';
  SearchResultSet _results = const SearchResultSet();

  /// Titles/ids of the currently dismissed mini players; null while the strip
  /// is visible. Choosing something else clears. Mirrors the detail screen.
  String? _dismissedEpisode;
  String? _dismissedRadio;

  PlaybackController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_syncDismissal);
  }

  @override
  void dispose() {
    controller.removeListener(_syncDismissal);
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _syncDismissal() {
    final PodcastEpisode? episode = controller.currentEpisode;
    if (controller.podcastActive && episode != null && episode.id != _dismissedEpisode) {
      _dismissedEpisode = null;
    }
    final RadioStation? station = controller.currentStation;
    if (controller.radioActive && station != null && station.name != _dismissedRadio) {
      _dismissedRadio = null;
    }
  }

  // --- Query plumbing -----------------------------------------------------

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => _runSearch(value));
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    _runSearch(value);
    _record(value);
  }

  void _runSearch(String value) {
    final String term = value.trim();
    if (term.isEmpty) {
      setState(() {
        _term = '';
        _results = const SearchResultSet();
      });
      return;
    }
    setState(() => _term = term);
    unawaited(_fetch(term));
  }

  Future<void> _fetch(String term) async {
    final SearchResultSet results = await _engine.search(term);
    if (!mounted || term != _term) return;
    setState(() => _results = results);
  }

  /// Sets the field to [value] and searches immediately (trending/recent/chip
  /// taps), also recording it as a recent search.
  void _setQuery(String value) {
    _debounce?.cancel();
    _query.text = value;
    _query.selection = TextSelection.collapsed(offset: value.length);
    _runSearch(value);
    _record(value);
  }

  void _clear() {
    _debounce?.cancel();
    _query.clear();
    setState(() {
      _term = '';
      _results = const SearchResultSet();
    });
  }

  void _record(String value) {
    _recentSearches.add(value);
  }

  // --- Routing into existing screens --------------------------------------

  void _playStation(RadioStation station) {
    if (controller.currentStation?.name == station.name && controller.isPlaying) {
      controller.toggle();
    } else {
      controller.playRadioStation(station);
    }
  }

  void _openStationPlayer(RadioStation station) {
    if (controller.currentStation?.name != station.name) {
      controller.playRadioStation(station);
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RadioPlayerScreen(controller: controller),
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

  void _openEpisode(PodcastEpisode episode) {
    controller.playPodcastEpisode(episode);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PodcastPlayerScreen(controller: controller),
      ),
    );
  }

  void _onResultTap(SearchResult result) {
    _record(_term);
    switch (result) {
      case StationResult(:final station):
        _playStation(station);
      case PodcastResult(:final show):
        _openShow(show);
      case EpisodeResult(:final episode):
        _openEpisode(episode);
    }
  }

  void _onTopResultTap(SearchResult result) {
    _record(_term);
    switch (result) {
      case StationResult(:final station):
        _openStationPlayer(station);
      case PodcastResult(:final show):
        _openShow(show);
      case EpisodeResult():
        break;
    }
  }

  // --- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([controller, _recentSearches]),
          builder: (context, _) => Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _term.isEmpty
                    ? _buildDiscovery()
                    : _results.isEmpty
                        ? _buildNoResults()
                        : _buildResults(),
              ),
              _buildMiniSlot(),
            ],
          ),
        ),
      ),
    );
  }

  /// The back button and the prominent bordered search field.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('search-back'),
            tooltip: 'Back',
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, size: 22, color: AppColors.ink),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.hairline),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: AppColors.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('search-field'),
                      controller: _query,
                      onChanged: _onChanged,
                      onSubmitted: _onSubmitted,
                      textInputAction: TextInputAction.search,
                      style: AppTextStyles.stationName,
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Search radio, podcasts & episodes',
                        hintStyle: AppTextStyles.stationCategory,
                      ),
                    ),
                  ),
                  if (_query.text.isNotEmpty)
                    IconButton(
                      key: const ValueKey('search-clear'),
                      tooltip: 'Clear',
                      visualDensity: VisualDensity.compact,
                      onPressed: _clear,
                      icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty query: recent searches (removable, clearable) and trending terms.
  Widget _buildDiscovery() {
    final List<String> recent = _recentSearches.entries;
    return ListView(
      key: const ValueKey('search-discovery'),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              const Text('RECENT SEARCHES', style: AppTextStyles.sectionLabel),
              const Spacer(),
              GestureDetector(
                key: const ValueKey('search-recent-clear'),
                behavior: HitTestBehavior.opaque,
                onTap: _recentSearches.clear,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text('CLEAR', style: AppTextStyles.nowPlayingLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final String term in recent) ...[
            _RecentRow(
              term: term,
              onTap: () => _setQuery(term),
              onRemove: () => _recentSearches.remove(term),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.hairline),
          ],
          const SizedBox(height: 28),
        ],
        const Text('TRENDING', style: AppTextStyles.sectionLabel),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final String term in SearchEngine.trending)
              _Chip(
                key: ValueKey('search-trend-$term'),
                label: term,
                onTap: () => _setQuery(term),
              ),
          ],
        ),
      ],
    );
  }

  /// Grouped active results: one top result, then per-type sections.
  Widget _buildResults() {
    return ListView(
      key: const ValueKey('search-results'),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      children: [
        if (_results.top != null) ...[
          _TopResultCard(
            result: _results.top!,
            controller: controller,
            onTap: () => _onTopResultTap(_results.top!),
          ),
          const SizedBox(height: 28),
        ],
        if (_results.stations.isNotEmpty) ...[
          const Text('RADIO STATIONS', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 4),
          for (final SearchResult result in _results.stations) ...[
            _ResultRow(
              result: result,
              controller: controller,
              onTap: () => _onResultTap(result),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.hairline),
          ],
          const SizedBox(height: 24),
        ],
        if (_results.podcasts.isNotEmpty) ...[
          const Text('PODCASTS', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 4),
          for (final SearchResult result in _results.podcasts) ...[
            _ResultRow(
              result: result,
              controller: controller,
              onTap: () => _onResultTap(result),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.hairline),
          ],
          const SizedBox(height: 24),
        ],
        if (_results.episodes.isNotEmpty) ...[
          const Text('EPISODES', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 4),
          for (final SearchResult result in _results.episodes) ...[
            _ResultRow(
              result: result,
              controller: controller,
              onTap: () => _onResultTap(result),
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.hairline),
          ],
        ],
      ],
    );
  }

  /// Thoughtful no-results state with a few suggested terms.
  Widget _buildNoResults() {
    return ListView(
      key: const ValueKey('search-no-results'),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      children: [
        const SizedBox(height: 20),
        const Text(
          'No results found',
          textAlign: TextAlign.center,
          style: AppTextStyles.stationName,
        ),
        const SizedBox(height: 8),
        const Text(
          'Try searching for a station, podcast or episode.',
          textAlign: TextAlign.center,
          style: AppTextStyles.stationCategory,
        ),
        const SizedBox(height: 30),
        const Text('TRY', textAlign: TextAlign.center, style: AppTextStyles.sectionLabel),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final String term in SearchEngine.fallbackSuggestions)
              _Chip(
                key: ValueKey('search-suggest-$term'),
                label: term,
                onTap: () => _setQuery(term),
              ),
          ],
        ),
      ],
    );
  }

  /// The shared persistent mini-player slot, kept visible so the listener can
  /// keep a session going while searching. Same widgets/semantics as the
  /// detail screen; nothing new is built.
  Widget _buildMiniSlot() {
    final PodcastEpisode? episode = controller.currentEpisode;
    final bool podcastActive = controller.podcastActive && episode != null;
    final bool ended = controller.podcastDuration > Duration.zero &&
        controller.podcastPosition >= controller.podcastDuration;

    if (controller.radioActive &&
        controller.currentStation != null &&
        _dismissedRadio != controller.currentStation!.name) {
      return RadioMiniPlayer(
        key: ValueKey('search-radio-${controller.currentStation!.name}'),
        controller: controller,
        onDismiss: () => setState(() => _dismissedRadio = controller.currentStation!.name),
      );
    }
    if (podcastActive && !ended && _dismissedEpisode != episode.id) {
      return MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: PodcastMiniPlayer(
          key: ValueKey('search-podcast-${episode.id}'),
          controller: controller,
          onDismiss: () => setState(() => _dismissedEpisode = episode.id),
        ),
      );
    }
    return const SizedBox(width: double.infinity);
  }
}

// --- Discovery widgets ----------------------------------------------------

/// A single recent-search row with a quiet remove control.
class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.term,
    required this.onTap,
    required this.onRemove,
  });

  final String term;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('search-recent-$term'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(term, style: AppTextStyles.stationName),
            ),
            GestureDetector(
              key: ValueKey('search-recent-remove-$term'),
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, size: 16, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet bordered chip (trending term, suggestion). Same language as the
/// home screens' category filters.
class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.hairline),
        ),
        child: Text(label, style: AppTextStyles.sectionLabel),
      ),
    );
  }
}

// --- Result rows ------------------------------------------------------------

/// The TOP RESULT card: a single strong name-level match. Understated like the
/// home screens' featured blocks, but compact — a type label, identity lines
/// and one play affordance.
class _TopResultCard extends StatelessWidget {
  const _TopResultCard({
    required this.result,
    required this.controller,
    required this.onTap,
  });

  final SearchResult result;
  final PlaybackController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isStation = result.type == SearchResultType.radioStation;
    final bool playing = isStation &&
        controller.radioActive &&
        controller.currentStation?.name == result.title &&
        controller.isPlaying;
    final String meta = result.metadata.join(' · ');

    return GestureDetector(
      key: const ValueKey('search-top-result'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.hairline),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(result.type.label.toUpperCase(), style: AppTextStyles.sectionLabel),
                const Spacer(),
                if (isStation) const LiveBadge(),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              result.title.toUpperCase(),
              style: AppTextStyles.stationTitle,
            ),
            if (result.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(result.subtitle!, style: AppTextStyles.stationProgramme),
            ],
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(meta, style: AppTextStyles.timeLabel),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  isStation ? 'PLAY' : 'OPEN',
                  style: AppTextStyles.nowPlayingLabel,
                ),
                const Spacer(),
                _PlayCircle(
                  playing: playing,
                  accent: isStation ? AppColors.accent : AppColors.podcastAccent,
                  size: 40,
                  onPressed: onTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single result row. Type indicator, identity and metadata on the left and
/// a type-appropriate trailing affordance (play circle, duration/date).
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.result,
    required this.controller,
    required this.onTap,
  });

  final SearchResult result;
  final PlaybackController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isStation = result.type == SearchResultType.radioStation;
    final bool active = isStation &&
        controller.radioActive &&
        controller.currentStation?.name == result.title;
    final String meta = [
      result.type.label.toUpperCase(),
      ...result.metadata,
    ].join(' · ');

    return GestureDetector(
      key: ValueKey('search-result-${result.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ResultArtwork(result: result, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: AppTextStyles.stationName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(meta, style: AppTextStyles.timeLabel),
                  if (result is EpisodeResult)
                    _EpisodeStateLine(
                      episode: (result as EpisodeResult).episode,
                      controller: controller,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildTrailing(active),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailing(bool active) {
    switch (result) {
      case StationResult():
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) ...[
              const ActiveDot(),
              const SizedBox(width: 6),
            ],
            _PlayCircle(
              playing: active && controller.isPlaying,
              accent: AppColors.accent,
              size: 32,
              onPressed: onTap,
            ),
          ],
        );
      case PodcastResult():
        return _PlayCircle(
          playing: false,
          accent: AppColors.podcastAccent,
          size: 32,
          onPressed: onTap,
        );
      case EpisodeResult(:final episode):
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatDuration(episode.duration), style: AppTextStyles.timeLabel),
            const SizedBox(height: 4),
            Text(episode.published?.toUpperCase() ?? '', style: AppTextStyles.timeLabel),
          ],
        );
    }
  }
}

/// Playback state for an episode row: a thin progress line for partial
/// progress, a quiet "PLAYED" for completed ones, nothing otherwise.
class _EpisodeStateLine extends StatelessWidget {
  const _EpisodeStateLine({required this.episode, required this.controller});

  final PodcastEpisode episode;
  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final bool active =
        controller.podcastActive && controller.currentEpisode?.id == episode.id;
    final Duration position = active ? controller.podcastPosition : episode.position;
    final bool partial = position > Duration.zero && position < episode.duration;
    final bool completed = episode.isCompleted || position >= episode.duration;
    if (!partial && !completed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: completed
          ? Row(
              key: ValueKey('search-episode-played-${episode.id}'),
              children: [
                const Icon(Icons.check_circle_outline, size: 13, color: AppColors.muted),
                const SizedBox(width: 6),
                const Text('PLAYED', style: AppTextStyles.timeLabel),
              ],
            )
          : ClipRRect(
              key: ValueKey('search-episode-progress-${episode.id}'),
              borderRadius: BorderRadius.circular(1),
              child: SizedBox(
                height: 2,
                child: ColoredBox(
                  color: AppColors.hairline,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: episode.duration.inMilliseconds == 0
                        ? 0
                        : (position.inMilliseconds / episode.duration.inMilliseconds)
                            .clamp(0.0, 1.0),
                    child: const ColoredBox(color: AppColors.podcastAccent),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Artwork for a result row: a station monogram circle or podcast artwork.
class _ResultArtwork extends StatelessWidget {
  const _ResultArtwork({required this.result, required this.size});

  final SearchResult result;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (result is StationResult) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.hairline),
        ),
        child: Text(
          _initials(result.artworkTitle),
          style: AppTextStyles.playerStation,
        ),
      );
    }
    return PodcastArt(title: result.artworkTitle, size: size);
  }

  String _initials(String title) {
    final List<String> parts = title.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// The small filled play/pause circle used across result rows.
class _PlayCircle extends StatelessWidget {
  const _PlayCircle({
    required this.playing,
    required this.accent,
    required this.size,
    required this.onPressed,
  });

  final bool playing;
  final Color accent;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent,
        ),
        child: Center(
          child: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            size: size * 0.56,
            color: AppColors.background,
          ),
        ),
      ),
    );
  }
}