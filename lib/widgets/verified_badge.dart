import 'package:flutter/material.dart';

import '../theme.dart';

/// A verified badge icon indicating native podcast creators and verified hosts.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({
    super.key,
    this.size = 14.0,
    this.showLabel = false,
    this.label = 'VERIFIED',
  });

  final double size;
  final bool showLabel;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final Color badgeColor = colors.accent;

    final Widget icon = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.check,
          size: size * 0.7,
          color: Colors.white,
        ),
      ),
    );

    if (!showLabel) {
      return Tooltip(
        message: 'Verified Native Creator',
        child: icon,
      );
    }

    return Tooltip(
      message: 'Verified Native Creator',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 0.8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: size * 0.65,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
