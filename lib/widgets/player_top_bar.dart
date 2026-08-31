import 'package:flutter/material.dart';

import '../theme.dart';

/// Minimal top bar for full-screen players: back button on the left, a small
/// centered screen label, and a balancing spacer on the right.
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({super.key, required this.label, required this.backKey});

  final String label;
  final Key backKey;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        IconButton(
          key: backKey,
          tooltip: 'Back',
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back, size: 22, color: colors.ink),
        ),
        Expanded(
          child: Center(
            child: Text(label, style: AppTextStyles.navLabel),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}