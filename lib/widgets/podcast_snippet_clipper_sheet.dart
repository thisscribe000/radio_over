import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../data/timeline/audio_snippet_exporter.dart';
import '../models/audio_snippet.dart';
import '../models/podcast_episode.dart';
import '../playback/playback_controller.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Modal bottom sheet allowing listeners to select Point A (Start) and Point B (End)
/// to trim highlights from any podcast episode.
///
/// Clips over 60s are automatically sectioned into an ordered Audio Thread (1/N, 2/N...).
class PodcastSnippetClipperSheet extends StatefulWidget {
  const PodcastSnippetClipperSheet({
    super.key,
    required this.controller,
    required this.episode,
  });

  final PlaybackController controller;
  final PodcastEpisode episode;

  static Future<void> show(
    BuildContext context, {
    required PlaybackController controller,
    required PodcastEpisode episode,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PodcastSnippetClipperSheet(
        controller: controller,
        episode: episode,
      ),
    );
  }

  @override
  State<PodcastSnippetClipperSheet> createState() =>
      _PodcastSnippetClipperSheetState();
}

class _PodcastSnippetClipperSheetState
    extends State<PodcastSnippetClipperSheet> {
  late double _startSec;
  late double _endSec;
  late double _maxSec;
  final TextEditingController _captionController = TextEditingController();
  bool _posting = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final double posSec =
        widget.controller.podcastPosition.inSeconds.toDouble();
    final double totalSec = widget.episode.duration.inSeconds > 30
        ? widget.episode.duration.inSeconds.toDouble()
        : 1800.0;
    _maxSec = totalSec;

    // Start at current listening position; default duration 30 seconds
    _startSec = posSec.clamp(0.0, (_maxSec - 30.0).clamp(0.0, _maxSec));
    _endSec = (_startSec + 30.0).clamp(_startSec + 5.0, _maxSec);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _setPointAToNow() {
    final double posSec =
        widget.controller.podcastPosition.inSeconds.toDouble();
    final double clipLen = (_endSec - _startSec).clamp(5.0, _maxSec);
    setState(() {
      _startSec = posSec.clamp(0.0, (_maxSec - 5.0).clamp(0.0, _maxSec));
      _endSec = (_startSec + clipLen).clamp(_startSec + 5.0, _maxSec);
    });
  }

  void _setPointBToNow() {
    final double posSec =
        widget.controller.podcastPosition.inSeconds.toDouble();
    setState(() {
      if (posSec > _startSec + 5.0) {
        _endSec = posSec.clamp(_startSec + 5.0, _maxSec);
      } else {
        _endSec = (_startSec + 30.0).clamp(_startSec + 5.0, _maxSec);
      }
    });
  }

  void _setDurationPreset(double seconds) {
    setState(() {
      _endSec = (_startSec + seconds).clamp(_startSec + 5.0, _maxSec);
    });
  }

  void _nudgeStart(double deltaSec) {
    setState(() {
      _startSec = (_startSec + deltaSec).clamp(0.0, _endSec - 2.0);
    });
  }

  void _nudgeEnd(double deltaSec) {
    setState(() {
      _endSec = (_endSec + deltaSec).clamp(_startSec + 2.0, _maxSec);
    });
  }

  Future<void> _postSnippet() async {
    if (_posting) return;
    setState(() => _posting = true);

    final String baseCaption = _captionController.text.trim().isNotEmpty
        ? _captionController.text.trim()
        : 'Highlight from ${widget.episode.title}';

    final double totalLen = _endSec - _startSec;
    final int partCount = (totalLen / 60.0).ceil().clamp(1, 10);
    final String currentUserName = widget.controller.username.isNotEmpty
        ? widget.controller.username
        : 'Community Listener';

    final bool isVerifiedCreator = widget.controller.userRole.isCreator;

    if (partCount > 1) {
      // Create multi-part Audio Thread
      final String threadId = 'thread-${DateTime.now().millisecondsSinceEpoch}';
      final List<AudioSnippet> threadItems = [];

      for (int i = 0; i < partCount; i++) {
        final double partStart = _startSec + (i * 60.0);
        final double partEnd = math.min(_endSec, partStart + 60.0);
        final String partCaption = '(${(i + 1)}/$partCount) $baseCaption';

        threadItems.add(
          AudioSnippet(
            id: 'snippet-${DateTime.now().millisecondsSinceEpoch}-$i',
            userId: 'user-current',
            userName: currentUserName,
            isVerified: isVerifiedCreator,
            podcastId: widget.episode.podcastId,
            podcastName: widget.episode.podcastName,
            episodeId: widget.episode.id,
            episodeTitle: widget.episode.title,
            episodeImageUrl: widget.episode.imageUrl,
            audioUrl: widget.episode.audioUrl,
            start: Duration(seconds: partStart.round()),
            end: Duration(seconds: partEnd.round()),
            caption: partCaption,
            threadId: threadId,
            threadIndex: i + 1,
            threadTotal: partCount,
            createdAt: DateTime.now().add(Duration(milliseconds: i * 10)),
          ),
        );
      }

      await widget.controller.createSnippetThread(threadItems);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio Thread ($partCount parts) posted to Timeline!'),
            backgroundColor: AppColors.of(context).podcastAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Single Audio Snippet
      final AudioSnippet snippet = AudioSnippet(
        id: 'snippet-${DateTime.now().millisecondsSinceEpoch}',
        userId: 'user-current',
        userName: currentUserName,
        isVerified: isVerifiedCreator,
        podcastId: widget.episode.podcastId,
        podcastName: widget.episode.podcastName,
        episodeId: widget.episode.id,
        episodeTitle: widget.episode.title,
        episodeImageUrl: widget.episode.imageUrl,
        audioUrl: widget.episode.audioUrl,
        start: Duration(seconds: _startSec.round()),
        end: Duration(seconds: _endSec.round()),
        caption: baseCaption,
        threadIndex: 1,
        threadTotal: 1,
        createdAt: DateTime.now(),
      );

      await widget.controller.createSnippet(snippet);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Snippet posted to Community Timeline!'),
            backgroundColor: AppColors.of(context).podcastAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportSnippetAudio() async {
    setState(() => _exporting = true);
    final String baseCaption = _captionController.text.trim().isNotEmpty
        ? _captionController.text.trim()
        : 'Highlight from ${widget.episode.title}';

    final AudioSnippet snippet = AudioSnippet(
      id: 'snippet-export-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'user-current',
      userName: 'Listener',
      podcastId: widget.episode.podcastId,
      podcastName: widget.episode.podcastName,
      episodeId: widget.episode.id,
      episodeTitle: widget.episode.title,
      episodeImageUrl: widget.episode.imageUrl,
      audioUrl: widget.episode.audioUrl,
      start: Duration(seconds: _startSec.round()),
      end: Duration(seconds: _endSec.round()),
      caption: baseCaption,
      createdAt: DateTime.now(),
    );

    try {
      final exporter = AudioSnippetExporter();
      await exporter.exportAndShare(
        snippet: snippet,
        downloadManager: widget.controller.downloads,
      );
    } catch (_) {}

    if (mounted) {
      setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final int clipDurationSec = math.max(1, (_endSec - _startSec).round());
    final int partCount = (clipDurationSec / 60.0).ceil();
    final bool isThread = partCount > 1;

    return Container(
      key: const ValueKey('clipper-sheet'),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.hairline, width: 1),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
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
                Icon(Icons.content_cut, size: 20, color: colors.podcastAccent),
                const SizedBox(width: 8),
                Text(
                  'CLIP AUDIO SNIPPET',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: colors.ink,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: colors.muted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.episode.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.episode.podcastName.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colors.muted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 14),

            // Quick Duration Preset Row
            Row(
              children: [
                const Text('DURATION: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                for (final MapEntry<String, double> preset in const [
                  MapEntry('15s', 15.0),
                  MapEntry('30s', 30.0),
                  MapEntry('60s', 60.0),
                  MapEntry('2m', 120.0),
                  MapEntry('3m', 180.0),
                ]) ...[
                  InkWell(
                    onTap: () => _setDurationPreset(preset.value),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: (clipDurationSec == preset.value.round())
                            ? colors.podcastAccent
                            : colors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (clipDurationSec == preset.value.round())
                              ? colors.podcastAccent
                              : colors.hairline,
                        ),
                      ),
                      child: Text(
                        preset.key,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: (clipDurationSec == preset.value.round())
                              ? Colors.white
                              : colors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isThread
                        ? colors.accent.withValues(alpha: 0.2)
                        : colors.podcastAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isThread ? colors.accent : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${clipDurationSec}s TOTAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isThread ? colors.accent : colors.podcastAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // THREAD WARNING / INFO BANNER IF OVER 60s
            if (isThread) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Text('🧵', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AUDIO THREAD · $partCount PARTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colors.accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Clips over 60s are automatically split into an ordered thread (1/$partCount, 2/$partCount...).',
                            style: TextStyle(fontSize: 10.5, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // POINT A (START) CARD & SLIDER
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.podcastAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'POINT A (START)',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatDuration(Duration(seconds: _startSec.round())),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.ink),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _setPointAToNow,
                        child: Text(
                          'SET TO PLAYHEAD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colors.podcastAccent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Slider(
                    value: _startSec.clamp(0.0, _maxSec),
                    min: 0,
                    max: _maxSec > 0 ? _maxSec : 100,
                    activeColor: colors.podcastAccent,
                    inactiveColor: colors.hairline,
                    onChanged: (val) {
                      setState(() {
                        _startSec = val;
                        if (_endSec < _startSec + 5.0) {
                          _endSec = (_startSec + 30.0).clamp(_startSec + 5.0, _maxSec);
                        }
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _NudgeBtn(label: '-10s', onTap: () => _nudgeStart(-10)),
                      const SizedBox(width: 4),
                      _NudgeBtn(label: '-1s', onTap: () => _nudgeStart(-1)),
                      const SizedBox(width: 4),
                      _NudgeBtn(label: '+1s', onTap: () => _nudgeStart(1)),
                      const SizedBox(width: 4),
                      _NudgeBtn(label: '+10s', onTap: () => _nudgeStart(10)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // POINT B (END) CARD & SLIDER
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'POINT B (END)',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatDuration(Duration(seconds: _endSec.round())),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.ink),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _setPointBToNow,
                        child: Text(
                          'SET TO PLAYHEAD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colors.accent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Slider(
                    value: _endSec.clamp(0.0, _maxSec),
                    min: 0,
                    max: _maxSec > 0 ? _maxSec : 100,
                    activeColor: colors.accent,
                    inactiveColor: colors.hairline,
                    onChanged: (val) {
                      setState(() {
                        _endSec = val;
                        if (_startSec > _endSec - 5.0) {
                          _startSec = (_endSec - 30.0).clamp(0.0, _endSec - 5.0);
                        }
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _NudgeBtn(label: '-10s', onTap: () => _nudgeEnd(-10)),
                      const SizedBox(width: 4),
                      _NudgeBtn(label: '-1s', onTap: () => _nudgeEnd(-1)),
                      const SizedBox(width: 4),
                      _NudgeBtn(label: '+1s', onTap: () => _nudgeEnd(1)),
                      const SizedBox(width: 4),
                      _NudgeBtn(label: '+10s', onTap: () => _nudgeEnd(10)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Waveform Graphic
            _WaveformGraphic(
              startFrac: _maxSec > 0 ? _startSec / _maxSec : 0.0,
              endFrac: _maxSec > 0 ? _endSec / _maxSec : 1.0,
              accentColor: isThread ? colors.accent : colors.podcastAccent,
              mutedColor: colors.hairline,
            ),
            const SizedBox(height: 12),

            // Caption / Quote input
            TextField(
              key: const ValueKey('clipper-caption-input'),
              controller: _captionController,
              maxLines: 2,
              style: TextStyle(fontSize: 13, color: colors.ink),
              decoration: InputDecoration(
                hintText: isThread
                    ? 'Add a topic or thought for this thread...'
                    : 'Add a thought, quote, or highlight note...',
                hintStyle: TextStyle(fontSize: 13, color: colors.muted),
                filled: true,
                fillColor: colors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isThread ? colors.accent : colors.podcastAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('clipper-preview-btn'),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('PREVIEW'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.ink,
                      side: BorderSide(color: colors.hairline),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      widget.controller.seek(Duration(seconds: _startSec.round()));
                      if (!widget.controller.isPlaying) {
                        widget.controller.toggle();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    key: const ValueKey('clipper-post-btn'),
                    icon: Icon(
                      isThread ? Icons.view_carousel_rounded : Icons.send_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      _posting
                          ? 'POSTING...'
                          : (isThread
                              ? 'SHARE THREAD ($partCount PARTS)'
                              : 'SHARE TO TIMELINE'),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isThread ? colors.accent : colors.podcastAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _posting ? null : _postSnippet,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('clipper-export-btn'),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  _exporting ? 'EXPORTING AUDIO...' : 'EXPORT AUDIO FILE (.MP3)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.podcastAccent,
                  side: BorderSide(color: colors.podcastAccent.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _exporting ? null : _exportSnippetAudio,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NudgeBtn extends StatelessWidget {
  const _NudgeBtn({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.hairline),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.muted),
        ),
      ),
    );
  }
}

class _WaveformGraphic extends StatelessWidget {
  const _WaveformGraphic({
    required this.startFrac,
    required this.endFrac,
    required this.accentColor,
    required this.mutedColor,
  });

  final double startFrac;
  final double endFrac;
  final Color accentColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const int barCount = 36;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (index) {
              final double frac = index / (barCount - 1);
              final bool isInClip = frac >= startFrac && frac <= endFrac;
              final double height = 4.0 + 14.0 * (0.5 + 0.5 * math.sin(index * 0.75)).abs();
              return Container(
                width: 3.5,
                height: height,
                decoration: BoxDecoration(
                  color: isInClip ? accentColor : mutedColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
