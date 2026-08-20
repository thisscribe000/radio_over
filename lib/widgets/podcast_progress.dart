import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/format.dart';

/// On-demand progress treatment for the podcast player.
///
/// A calm, static bar field where the elapsed portion is tinted and the rest
/// sits in hairline — plus elapsed/total time. Tapping or dragging seeks.
/// It deliberately reads as *recorded, scrubbable* time, unlike the radio
/// player's animated live waveform.
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
                height: 64,
                child: CustomPaint(
                  painter: _BarsPainter(fraction: fraction),
                ),
              ),
              const SizedBox(height: 14),
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

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.fraction});

  final double fraction;

  static const List<double> _heights = [
    0.20, 0.36, 0.50, 0.58, 0.40, 0.28, 0.38, 0.56,
    0.64, 0.46, 0.30, 0.34, 0.48, 0.62, 0.52, 0.36,
    0.24, 0.40, 0.54, 0.60, 0.46, 0.34, 0.24, 0.30,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final double slot = size.width / _heights.length;
    final Paint elapsed = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AppColors.podcastAccent.withValues(alpha: 0.6);
    final Paint remaining = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AppColors.hairline;

    for (int i = 0; i < _heights.length; i++) {
      final double height = math.max(6, size.height * _heights[i]);
      final double x = slot * (i + 0.5);
      final double top = size.height / 2 - height / 2;
      final bool played = i / _heights.length <= fraction;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + height),
        played ? elapsed : remaining,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}