import 'package:flutter/material.dart';

import '../models/podcast_episode.dart';
import '../theme.dart';

/// Spotify-style timed captions for the podcast player.
///
/// The current caption is emphasised while the rest recede; the list
/// auto-scrolls to follow it, and tapping any caption seeks to that moment.
class PodcastCaptions extends StatefulWidget {
  const PodcastCaptions({
    super.key,
    required this.episode,
    required this.position,
    required this.onTapCaption,
  });

  final PodcastEpisode episode;
  final Duration position;
  final ValueChanged<Duration> onTapCaption;

  @override
  State<PodcastCaptions> createState() => _PodcastCaptionsState();
}

class _PodcastCaptionsState extends State<PodcastCaptions> {
  static const double _itemExtent = 112;
  static const int _fadeDurationMs = 180;

  final ScrollController _scroll = ScrollController();
  int _highlightedIndex = -1;

  List<PodcastCaption> get _captions => widget.episode.captions;

  int _indexAt(Duration position) {
    int index = 0;
    for (int i = 0; i < _captions.length; i++) {
      if (_captions[i].start <= position) index = i;
    }
    return index;
  }

  @override
  void didUpdateWidget(PodcastCaptions oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int index = _indexAt(widget.position);
    if (index != _highlightedIndex) {
      _highlightedIndex = index;
      _scrollTo(index);
    }
  }

  void _scrollTo(int index) {
    if (!_scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(index));
      return;
    }
    final double target =
        (index * _itemExtent - 12).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_highlightedIndex == -1) {
      _highlightedIndex = _indexAt(widget.position);
    }
    return ListView.builder(
      controller: _scroll,
      itemExtent: _itemExtent,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _captions.length,
      itemBuilder: (context, index) {
        final PodcastCaption caption = _captions[index];
        final bool active = index == _highlightedIndex;
        return GestureDetector(
          key: ValueKey('caption-$index'),
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onTapCaption(caption.start),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: _fadeDurationMs),
              curve: Curves.easeOut,
              style: active
                  ? const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: AppColors.ink,
                    )
                  : const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      color: AppColors.muted,
                    ),
              child: Text(
                caption.text,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}