import 'package:flutter/material.dart';

import '../theme.dart';

/// Restrained podcast artwork placeholder: a quiet square tile with the show's
/// monogram. Deliberately not a giant Spotify-style cover — artwork supports
/// the layout instead of dominating it.
class PodcastArt extends StatelessWidget {
  const PodcastArt({super.key, required this.title, this.size = 140});

  /// The podcast/show name used to derive the monogram.
  final String title;

  final double size;

  String get _initials {
    final List<String> parts = title.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Center(
        child: Container(
          width: size * 0.46,
          height: size * 0.46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.podcastAccent.withValues(alpha: 0.55)),
          ),
          alignment: Alignment.center,
          child: Text(
            _initials,
            style: AppTextStyles.playerStation.copyWith(color: AppColors.podcastAccent),
          ),
        ),
      ),
    );
  }
}