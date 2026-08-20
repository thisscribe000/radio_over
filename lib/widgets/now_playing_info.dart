import 'package:flutter/material.dart';

import '../theme.dart';

/// Understated bottom information block shared by the full-screen players.
class NowPlayingInfo extends StatelessWidget {
  const NowPlayingInfo({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.hairline),
        ),
      ),
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NOW PLAYING', style: AppTextStyles.nowPlayingLabel),
          const SizedBox(height: 10),
          Text(title, style: AppTextStyles.nowPlayingProgramme),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTextStyles.stationCategory),
        ],
      ),
    );
  }
}