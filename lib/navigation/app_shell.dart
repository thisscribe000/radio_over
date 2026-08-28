import 'package:flutter/material.dart';

import '../data/content_scope.dart';
import '../models/podcast_episode.dart';
import '../playback/playback_controller.dart';
import '../screens/library_screen.dart';
import '../screens/podcasts_screen.dart';
import '../screens/radio_screen.dart';
import '../search/recent_searches.dart';
import '../theme.dart';
import '../widgets/podcast_mini_player.dart';

/// Top-level navigation shell.
///
/// Hosts the tab bar (RADIO / PODCASTS / LIBRARY) and the shared bottom
/// podcast mini-player slot, which persists across tabs. The visible tab moves
/// freely; the podcast strip stays put so the listener can keep a session
/// going while browsing. Dismissing the strip hides it until a new episode is
/// chosen.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.controller,
    this.content,
    this.recentSearches,
  });

  final PlaybackController controller;

  /// Content repositories/source of truth. Defaults to the offline mock scope
  /// so the shell works standalone (and every widget test) without a backend.
  final AppContent? content;

  /// Search history store; defaults to a fresh in-memory instance so the
  /// shell works standalone without persistence.
  final RecentSearches? recentSearches;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final AppContent _content = widget.content ?? AppContent.mock();
  late final RecentSearches _recentSearches =
      widget.recentSearches ?? RecentSearches();
  int _index = 0;

  /// Title of the episode the listener dismissed; null while the strip is
  /// (or should be) visible. Choosing a different episode clears it.
  String? _dismissedEpisode;

  static const Duration _playerDuration = Duration(milliseconds: 280);

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
    final String? title = widget.controller.currentEpisode?.title;
    if (!widget.controller.podcastActive || title == null) return;
    if (title != _dismissedEpisode) {
      _dismissedEpisode = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          RadioScreen(controller: widget.controller, content: _content),
          PodcastsScreen(
            controller: widget.controller,
            content: _content,
            recentSearches: _recentSearches,
          ),
          LibraryScreen(
            controller: widget.controller,
            content: _content,
            active: _index == 2,
            onExploreAudio: () => setState(() => _index = 1),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => AnimatedSize(
              duration: _playerDuration,
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: _playerDuration,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: _bottomPlayerTransition,
                child: _buildPodcastSlot(),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: _TabBar(index: _index, onChanged: (i) => setState(() => _index = i)),
          ),
        ],
      ),
    );
  }

  Widget _buildPodcastSlot() {
    final PodcastEpisode? episode = widget.controller.currentEpisode;
    final bool active = widget.controller.podcastActive && episode != null;
    final bool ended = widget.controller.podcastDuration > Duration.zero &&
        widget.controller.podcastPosition >= widget.controller.podcastDuration;
    if (active && !ended && _dismissedEpisode != episode.title) {
      return MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: PodcastMiniPlayer(
          key: ValueKey('podcast-${episode.title}'),
          controller: widget.controller,
          onDismiss: () => setState(() => _dismissedEpisode = episode.title),
        ),
      );
    }
    return const SizedBox(width: double.infinity, key: ValueKey('podcast-none'));
  }

  Widget _bottomPlayerTransition(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Row(
        children: [
          _TabItem(label: 'RADIO', selected: index == 0, onTap: () => onChanged(0)),
          _TabItem(label: 'PODCASTS', selected: index == 1, onTap: () => onChanged(1)),
          _TabItem(label: 'LIBRARY', selected: index == 2, onTap: () => onChanged(2)),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        key: ValueKey('tab-$label'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              label,
              style: selected ? AppTextStyles.navLabel : AppTextStyles.sectionLabel,
            ),
          ),
        ),
      ),
    );
  }
}