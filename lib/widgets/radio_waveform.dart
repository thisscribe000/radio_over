import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../theme.dart';

/// A restrained live-broadcast treatment: a row of thin vertical bars whose
/// heights drift gently while the station is live, settling to a flat line
/// when paused. Never read as a scrub-able track timeline.
class RadioWaveform extends StatefulWidget {
  const RadioWaveform({super.key, required this.active});

  final bool active;

  @override
  State<RadioWaveform> createState() => _RadioWaveformState();
}

class _RadioWaveformState extends State<RadioWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.value = 0;
    }
  }

  @override
  void didUpdateWidget(RadioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _WavePainter(
                phase: _controller.value,
                active: widget.active,
                colors: colors,
              ),
            );
          },
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.phase, required this.active, required this.colors});

  final double phase;
  final bool active;
  final AppColors colors;

  static const int _barCount = 13;
  static const double _barWidth = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Paint paint = Paint()
      ..strokeWidth = _barWidth
      ..strokeCap = StrokeCap.round
      ..color = active
          ? colors.accent.withValues(alpha: 0.55)
          : colors.hairline;

    if (!active) {
      final double lineY = size.height / 2;
      final double lineWidth = math.min(size.width, _barCount * 10.0);
      canvas.drawLine(Offset((size.width - lineWidth) / 2, lineY),
          Offset((size.width + lineWidth) / 2, lineY), paint);
      return;
    }

    final double span = size.width / _barCount;
    for (int i = 0; i < _barCount; i++) {
      final double wave =
          0.5 + 0.5 * math.sin(2 * math.pi * phase + i * 0.75 + 0.35 * i);
      final double amplitude = 0.12 + wave * 0.36;
      final double barHeight = math.max(4, size.height * amplitude);
      final double x = span * (i + 0.5);
      final double top = size.height / 2 - barHeight / 2;
      canvas.drawLine(Offset(x, top), Offset(x, top + barHeight), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.active != active;
  }
}