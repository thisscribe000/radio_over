import 'package:flutter/material.dart';

import '../playback/playback_controller.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Subtle live sleep-timer countdown shown by both full-screen players, e.g.
/// "Sleep · 29:42". Renders nothing while no timer is running. The remaining
/// time is recomputed against the controller's clock on every rebuild, so it
/// stays current without running its own ticking counter.
class SleepTimerIndicator extends StatelessWidget {
  const SleepTimerIndicator({super.key, required this.controller});

  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.sleepActive) return const SizedBox.shrink();
    final Duration? remaining = controller.sleepRemaining;
    final String text = remaining == null
        ? 'Sleep · End of episode'
        : 'Sleep · ${formatDuration(remaining)}';
    return Text(
      text,
      key: const ValueKey('sleep-countdown'),
      style: AppTextStyles.timeLabel,
    );
  }
}