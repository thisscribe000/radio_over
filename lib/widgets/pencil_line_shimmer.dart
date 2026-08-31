import 'package:flutter/material.dart';

import '../theme.dart';

/// A minimal, editorial pulsing skeleton/shimmer placeholder.
///
/// Instead of a heavy, high-contrast gradient, it animates the opacity of the
/// app's signature hairline color (`colors.hairline`) in a repeating loop.
/// This matches the off-white canvas and pencil-line visual aesthetic.
class PencilLineShimmer extends StatefulWidget {
  const PencilLineShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
    this.child,
  });

  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? margin;
  final Widget? child;

  @override
  State<PencilLineShimmer> createState() => _PencilLineShimmerState();
}

class _PencilLineShimmerState extends State<PencilLineShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.3, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: child,
        );
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: colors.hairline,
          borderRadius: widget.borderRadius ?? BorderRadius.zero,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Renders a list of minimal placeholder episode rows.
class EditorialEpisodeListShimmer extends StatelessWidget {
  const EditorialEpisodeListShimmer({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < count; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Episode Title Shimmer line 1
                      const PencilLineShimmer(
                        height: 14,
                        width: double.infinity,
                      ),
                      const SizedBox(height: 6),
                      // Episode Title Shimmer line 2
                      const PencilLineShimmer(
                        height: 14,
                        width: 180,
                      ),
                      const SizedBox(height: 8),
                      // Description line 1
                      const PencilLineShimmer(
                        height: 10,
                        width: double.infinity,
                      ),
                      const SizedBox(height: 4),
                      // Description line 2
                      const PencilLineShimmer(
                        height: 10,
                        width: 240,
                      ),
                      const SizedBox(height: 12),
                      // Date / Duration info line
                      const PencilLineShimmer(
                        height: 10,
                        width: 100,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                // Play circle shimmer
                const PencilLineShimmer(
                  width: 32,
                  height: 32,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ],
            ),
          ),
          if (i < count - 1)
            Divider(height: 1, thickness: 1, color: colors.hairline),
        ],
      ],
    );
  }
}

/// Renders a list of card shimmers (e.g. for horizontal popular show rows).
class EditorialShowCardsShimmer extends StatelessWidget {
  const EditorialShowCardsShimmer({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return Container(
            width: 176,
            decoration: BoxDecoration(
              border: Border.all(color: colors.hairline),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    // Show Art
                    PencilLineShimmer(
                      width: 44,
                      height: 44,
                    ),
                    Spacer(),
                    // Bookmark icon
                    PencilLineShimmer(
                      width: 18,
                      height: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Show Name
                const PencilLineShimmer(
                  width: 120,
                  height: 14,
                ),
                const SizedBox(height: 6),
                // Show Category
                const PencilLineShimmer(
                  width: 60,
                  height: 10,
                ),
                const Spacer(),
                Row(
                  children: const [
                    PencilLineShimmer(
                      width: 16,
                      height: 16,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    SizedBox(width: 4),
                    PencilLineShimmer(
                      width: 40,
                      height: 10,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Renders a shimmer for the featured show block.
class EditorialFeaturedShimmer extends StatelessWidget {
  const EditorialFeaturedShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: colors.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show artwork
              const PencilLineShimmer(
                width: 76,
                height: 76,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    // Show Name
                    PencilLineShimmer(
                      width: 120,
                      height: 12,
                    ),
                    SizedBox(height: 8),
                    // Episode Title line 1
                    PencilLineShimmer(
                      width: double.infinity,
                      height: 14,
                    ),
                    SizedBox(height: 6),
                    // Episode Title line 2
                    PencilLineShimmer(
                      width: 160,
                      height: 14,
                    ),
                    SizedBox(height: 8),
                    // Metadata line
                    PencilLineShimmer(
                      width: 140,
                      height: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Description lines
          const PencilLineShimmer(
            width: double.infinity,
            height: 12,
          ),
          const SizedBox(height: 6),
          const PencilLineShimmer(
            width: double.infinity,
            height: 12,
          ),
          const SizedBox(height: 6),
          const PencilLineShimmer(
            width: 180,
            height: 12,
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              PencilLineShimmer(
                width: 80,
                height: 12,
              ),
              Spacer(),
              PencilLineShimmer(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
