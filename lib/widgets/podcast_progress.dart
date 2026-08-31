import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/format.dart';

/// Segmented progress bar (Image 2 style) for the podcast player.
/// Displays a pill-shaped track with colored segments, highlight pins (📍),
/// and a vertical playhead cursor.
class PodcastProgress extends StatelessWidget {
  const PodcastProgress({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double fraction =
            duration.inMilliseconds == 0
                ? 0
                : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _seekAt(width, details.localPosition.dx),
          onHorizontalDragUpdate: (details) => _seekAt(width, details.localPosition.dx),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width,
                height: 56,
                child: CustomPaint(
                  painter: _SegmentedTrackPainter(fraction: fraction, colors: colors),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(formatDuration(position), style: AppTextStyles.timeLabel),
                  const Spacer(),
                  Text(formatDuration(duration), style: AppTextStyles.timeLabel),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _seekAt(double width, double dx) {
    if (width <= 0) return;
    final double ratio = (dx / width).clamp(0.0, 1.0);
    onSeek(Duration(milliseconds: (duration.inMilliseconds * ratio).round()));
  }
}

class _PodcastTrackSegment {
  const _PodcastTrackSegment(this.start, this.end, this.color);
  final double start;
  final double end;
  final Color color;
}

class _SegmentedTrackPainter extends CustomPainter {
  _SegmentedTrackPainter({required this.fraction, required this.colors});

  final double fraction;
  final AppColors colors;

  // Visual segments representing speaker/chapter highlights
  static const List<_PodcastTrackSegment> _segments = [
    _PodcastTrackSegment(0.0, 0.15, Color(0xFFC5E1A5)), // Soft light green
    _PodcastTrackSegment(0.15, 0.28, Color(0xFFE1BEE7)), // Soft purple
    _PodcastTrackSegment(0.28, 0.50, Color(0xFF81C784)), // Green
    _PodcastTrackSegment(0.50, 0.68, Color(0xFFBA68C8)), // Purple
    _PodcastTrackSegment(0.68, 0.82, Color(0xFFC5E1A5)),
    _PodcastTrackSegment(0.82, 1.0, Color(0xFFE1BEE7)),
  ];

  // Highlights / Pins markers positions (0.0 to 1.0)
  static const List<double> _pinFractions = [0.08, 0.13];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double trackHeight = 10.0;
    final double yCenter = size.height / 2;
    final double trackTop = yCenter - trackHeight / 2;

    // Draw the overall background rounded track (pill shape)
    final RRect trackRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, trackTop, size.width, trackHeight),
      const Radius.circular(5),
    );

    // Clip the canvas to the track's rounded boundary so segments stay pill-shaped
    canvas.save();
    canvas.clipRRect(trackRRect);

    // Draw each segment
    for (final segment in _segments) {
      final double xStart = segment.start * size.width;
      final double xEnd = segment.end * size.width;
      final double segmentWidth = xEnd - xStart;

      final bool isSegmentElapsed = segment.end <= fraction;
      final bool isSegmentCurrent = fraction >= segment.start && fraction < segment.end;

      if (isSegmentElapsed) {
        // Fully played: Draw with solid full color
        final Paint paint = Paint()..color = segment.color;
        canvas.drawRect(Rect.fromLTWH(xStart, trackTop, segmentWidth, trackHeight), paint);
      } else if (isSegmentCurrent) {
        // Partially played: Split at current fraction
        final double xSplit = fraction * size.width;
        
        // Played part
        final Paint playedPaint = Paint()..color = segment.color;
        canvas.drawRect(Rect.fromLTWH(xStart, trackTop, xSplit - xStart, trackHeight), playedPaint);

        // Muted/remaining part
        final Paint remainingPaint = Paint()
          ..color = segment.color.withValues(alpha: 0.25);
        canvas.drawRect(Rect.fromLTWH(xSplit, trackTop, xEnd - xSplit, trackHeight), remainingPaint);
      } else {
        // Fully remaining: Draw with muted color
        final Paint paint = Paint()
          ..color = segment.color.withValues(alpha: 0.25);
        canvas.drawRect(Rect.fromLTWH(xStart, trackTop, segmentWidth, trackHeight), paint);
      }
    }
    canvas.restore();

    // Draw Pin Markers (📍) above the track
    for (final pinFrac in _pinFractions) {
      final double x = pinFrac * size.width;
      // Paint vertical needle of the pin
      final Paint pinNeedlePaint = Paint()
        ..color = colors.ink.withValues(alpha: 0.5)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(x, trackTop - 12),
        Offset(x, trackTop),
        pinNeedlePaint,
      );

      // Paint unicode emoji 📍 using TextPainter
      final TextPainter pinPainter = TextPainter(
        text: const TextSpan(
          text: '📍',
          style: TextStyle(fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      );
      pinPainter.layout();
      pinPainter.paint(
        canvas,
        Offset(x - pinPainter.width / 2, trackTop - 25),
      );
    }

    // Draw Vertical Playhead Cursor Line
    final double cursorX = fraction * size.width;
    final Paint cursorPaint = Paint()
      ..color = colors.ink
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cursorX, trackTop - 6),
      Offset(cursorX, trackTop + trackHeight + 6),
      cursorPaint,
    );
  }

  @override
  bool shouldRepaint(_SegmentedTrackPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}