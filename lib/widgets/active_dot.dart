import 'package:flutter/material.dart';

import '../theme.dart';

/// The small accent dot marking the currently active item.
class ActiveDot extends StatelessWidget {
  const ActiveDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent,
      ),
    );
  }
}