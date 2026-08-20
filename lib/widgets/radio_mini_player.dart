import 'package:flutter/material.dart';

import '../models/station.dart';
import '../playback/playback_controller.dart';
import '../screens/radio_player_screen.dart';
import '../theme.dart';
import 'live_badge.dart';

/// Compact live-broadcast strip shown at the top of the screen while radio is
/// on air. Tapping the strip opens the full Radio Player screen.
class RadioMiniPlayer extends StatelessWidget {
  const RadioMiniPlayer({
    super.key,
    required this.controller,
    required this.onDismiss,
  });

  final PlaybackController controller;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final RadioStation station = controller.currentStation!;
    final bool playing = controller.isPlaying;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RadioPlayerScreen(controller: controller),
          ),
        );
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.hairline),
            bottom: BorderSide(color: AppColors.hairline),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            const LiveBadge(),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(station.name.toUpperCase(), style: AppTextStyles.playerStation),
                  const SizedBox(height: 3),
                  Text(station.program, style: AppTextStyles.playerProgram),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('radio-mini-dismiss'),
              tooltip: 'Close',
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
            ),
            IconButton(
              onPressed: controller.toggle,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                playing ? Icons.pause : Icons.play_arrow_outlined,
                size: 30,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}