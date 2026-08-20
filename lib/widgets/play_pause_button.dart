import 'package:flutter/material.dart';

import '../theme.dart';

/// The strong central playback action shared by all full-screen players.
/// A filled ink circle; the icon cross-fades with a gentle scale on toggle.
class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({
    super.key,
    required this.playing,
    required this.onPressed,
  });

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Material(
        shape: const CircleBorder(),
        color: AppColors.ink,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Icon(
                playing ? Icons.pause : Icons.play_arrow,
                key: ValueKey(playing ? 'icon-pause' : 'icon-play'),
                size: 34,
                color: AppColors.background,
              ),
            ),
          ),
        ),
      ),
    );
  }
}