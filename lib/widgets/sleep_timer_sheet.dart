import 'package:flutter/material.dart';

import '../playback/playback_controller.dart';
import '../theme.dart';

/// The quiet sleep-timer picker shown from both full-screen players.
///
/// Radio surfaces pass [showEndOfEpisode] false; podcasts also offer
/// END OF EPISODE. Picking an option replaces any active timer; while one is
/// running a "Turn Off Sleep Timer" row appears that leaves audio playing.
class SleepTimerSheet extends StatelessWidget {
  const SleepTimerSheet({
    super.key,
    required this.controller,
    this.showEndOfEpisode = true,
  });

  final PlaybackController controller;
  final bool showEndOfEpisode;

  static Future<void> show(
    BuildContext context, {
    required PlaybackController controller,
    required bool showEndOfEpisode,
  }) {
    final colors = AppColors.of(context);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.background,
      builder: (_) => SleepTimerSheet(
        controller: controller,
        showEndOfEpisode: showEndOfEpisode,
      ),
    );
  }

  void _pick(BuildContext context, Duration duration) {
    controller.startSleepTimer(duration);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(sleepActive: controller.sleepActive),
          if (controller.sleepActive)
            _Option(
              key: const ValueKey('sleep-timer-off'),
              label: 'TURN OFF SLEEP TIMER',
              onTap: () {
                controller.cancelSleepTimer();
                Navigator.of(context).pop();
              },
            ),
          _Option(
            key: const ValueKey('sleep-timer-15'),
            label: '15 MINUTES',
            onTap: () => _pick(context, const Duration(minutes: 15)),
          ),
          _Option(
            key: const ValueKey('sleep-timer-30'),
            label: '30 MINUTES',
            onTap: () => _pick(context, const Duration(minutes: 30)),
          ),
          _Option(
            key: const ValueKey('sleep-timer-45'),
            label: '45 MINUTES',
            onTap: () => _pick(context, const Duration(minutes: 45)),
          ),
          _Option(
            key: const ValueKey('sleep-timer-60'),
            label: '60 MINUTES',
            onTap: () => _pick(context, const Duration(minutes: 60)),
          ),
          if (showEndOfEpisode)
            _Option(
              key: const ValueKey('sleep-timer-end'),
              label: 'END OF EPISODE',
              onTap: () {
                controller.startSleepTimerEndOfEpisode();
                Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.sleepActive});

  final bool sleepActive;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
      child: Row(
        children: [
          Icon(Icons.bedtime_outlined, size: 18, color: colors.muted),
          const SizedBox(width: 10),
          Text(
            sleepActive ? 'SLEEP TIMER · ACTIVE' : 'SLEEP TIMER',
            style: AppTextStyles.sectionLabel,
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.hairline)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        child: Text(label, style: AppTextStyles.navLabel),
      ),
    );
  }
}