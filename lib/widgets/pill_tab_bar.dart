import 'package:flutter/material.dart';

import '../theme.dart';

/// A destination in a [PillTabBar]: a label and the icon it morphs into.
class PillTabDestination {
  const PillTabDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Reusable, state-driven bottom navigation.
///
/// The active destination is shown as its **text label only**, and every
/// inactive destination as its **icon only** — no pill, no background, no
/// border, no shadow. Selecting a tab makes the icon theatrically *become* the
/// label: the outgoing label fades back into its muted icon while the newly
/// chosen icon fades into its ink label (Radio → 📻 and simultaneously
/// 🎙️ → Podcasts).
///
/// The crossfade is subtle and fast — a short fade combined with a gentle
/// horizontal size settle ([FadeTransition] + [SizeTransition] on an
/// [AnimatedSwitcher]). No bouncing, scaling, sliding or shells around the
/// items. Inactive tabs genuinely have no label in the tree, and the active
/// tab has no icon.
///
/// Fully route/index driven: pass the shell's current tab index in
/// [selectedIndex] and the item follows whichever route is active. The three
/// destinations stay balanced with [MainAxisAlignment.spaceEvenly] and a
/// comfortable minimum width per item so the active label never cramps narrow
/// screens. The label's position is not fixed — it sits wherever its
/// (center-aligned) flex slot places it.
class PillTabBar extends StatelessWidget {
  const PillTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.duration = const Duration(milliseconds: 220),
  });

  final List<PillTabDestination> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Length of the icon↔label morph. Kept short so switching feels immediate.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (int i = 0; i < tabs.length; i++)
              Flexible(
                fit: FlexFit.loose,
                child: _PillTabItem(
                  key: ValueKey('tab-${tabs[i].label}'),
                  icon: tabs[i].icon,
                  label: tabs[i].label,
                  selected: i == selectedIndex,
                  duration: duration,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillTabItem extends StatelessWidget {
  const _PillTabItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = selected
        ? Text(
            label,
            key: ValueKey('$label-label'),
            style: AppTextStyles.navLabel.copyWith(color: AppColors.ink),
          )
        : Icon(
            icon,
            key: ValueKey('$label-icon'),
            size: 22,
            color: AppColors.muted,
          );

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Center(
              child: AnimatedSwitcher(
                duration: duration,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axis: Axis.horizontal,
                    axisAlignment: 0,
                    child: child,
                  ),
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
