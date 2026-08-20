import 'package:flutter/material.dart';

/// A thin, quiet icon button used for secondary player controls.
class PlayerIconButton extends StatelessWidget {
  const PlayerIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: icon,
    );
  }
}