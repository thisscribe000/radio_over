import 'package:flutter/material.dart';

import '../theme.dart';

/// A dynamic, generative, and highly editorial podcast artwork placeholder.
///
/// Instead of loading standard heavy image files, it procedurally draws a unique
/// minimal vector illustration (such as radio waves, audio spectrums, or cassette spools)
/// using a `CustomPainter` seeded by a hash of the podcast's title.
class PodcastArt extends StatelessWidget {
  const PodcastArt({
    super.key,
    required this.title,
    this.size = 140,
    this.showInitials = true,
  });

  /// The podcast/show name used to seed the generative artwork.
  final String title;

  final double size;

  /// Whether to overlay the show's initials in the center.
  final bool showInitials;

  String get _initials {
    final List<String> parts = title.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  int get _titleHash {
    int hash = 0;
    for (int i = 0; i < title.length; i++) {
      hash = title.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return hash.abs();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final int hash = _titleHash;
    final int patternType = hash % 3;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.hairline),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Generative line-art background
          Positioned.fill(
            child: CustomPaint(
              painter: _LineArtGeneratorPainter(
                hash: hash,
                patternType: patternType,
                color: colors.podcastAccent.withValues(alpha: 0.22),
                lineColor: colors.hairline.withValues(alpha: 0.4),
              ),
            ),
          ),
          // Central monogram
          if (showInitials)
            Container(
              width: size * 0.46,
              height: size * 0.46,
              decoration: BoxDecoration(
                color: colors.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.podcastAccent.withValues(alpha: 0.45),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.background,
                    blurRadius: 4,
                    spreadRadius: 4,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _initials,
                style: TextStyle(
                  fontFamily: 'Ahem', // Fallback/Test safe
                  fontSize: size * 0.15,
                  fontWeight: FontWeight.bold,
                  color: colors.podcastAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LineArtGeneratorPainter extends CustomPainter {
  _LineArtGeneratorPainter({
    required this.hash,
    required this.patternType,
    required this.color,
    required this.lineColor,
  });

  final int hash;
  final int patternType;
  final Color color;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final Paint borderPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;

    if (patternType == 0) {
      // Pattern 0: Concentric Radio Waves
      final int circlesCount = 4 + (hash % 4);
      final double step = (w * 0.45) / circlesCount;
      for (int i = 1; i <= circlesCount; i++) {
        canvas.drawCircle(Offset(cx, cy), i * step, fillPaint);
      }
      // Draw grid diagonals
      canvas.drawLine(Offset(0, 0), Offset(w, h), borderPaint);
      canvas.drawLine(Offset(w, 0), Offset(0, h), borderPaint);
    } else if (patternType == 1) {
      // Pattern 1: Waveform Spectrum
      final int linesCount = 8 + (hash % 6);
      final double spacing = w / (linesCount + 1);
      for (int i = 0; i < linesCount; i++) {
        final double x = spacing * (i + 1);
        final double amplitude = 0.2 + 0.6 * ((hash ^ (i * 99)) % 10) / 10.0;
        final double lineHeight = h * 0.7 * amplitude;
        final double yTop = cy - lineHeight / 2;
        final double yBottom = cy + lineHeight / 2;
        canvas.drawLine(Offset(x, yTop), Offset(x, yBottom), fillPaint);
      }
      // Horizontal centerline
      canvas.drawLine(Offset(0, cy), Offset(w, cy), borderPaint);
    } else {
      // Pattern 2: Cassette Spools / Reel-to-Reel wireframe
      final double spoolRadius = w * 0.15;
      final double offset = w * 0.22;

      // Draw two tape spools
      canvas.drawCircle(Offset(cx - offset, cy), spoolRadius, fillPaint);
      canvas.drawCircle(Offset(cx + offset, cy), spoolRadius, fillPaint);

      // Inner spindles
      canvas.drawCircle(Offset(cx - offset, cy), spoolRadius * 0.4, borderPaint);
      canvas.drawCircle(Offset(cx + offset, cy), spoolRadius * 0.4, borderPaint);

      // Connecting tape line
      canvas.drawLine(
        Offset(cx - offset, cy + spoolRadius),
        Offset(cx + offset, cy + spoolRadius),
        fillPaint,
      );
      canvas.drawLine(
        Offset(cx - offset, cy - spoolRadius),
        Offset(cx + offset, cy - spoolRadius),
        fillPaint,
      );
    }

    // Outer thin square grid line
    canvas.drawRect(
      Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.84, h * 0.84),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LineArtGeneratorPainter oldDelegate) =>
      oldDelegate.hash != hash || oldDelegate.patternType != patternType;
}