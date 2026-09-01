import 'package:flutter/material.dart';

import '../playback/playback_controller.dart';
import '../theme.dart';

/// Preset equalizer modes for podcast and voice audio.
enum AudioEnhancementPreset {
  speechFocus('Vocal Clarity', 'Enhances dialog & removes low-end rumble for maximum speech intelligibility.', Icons.record_voice_over),
  balanced('Balanced Natural', 'Standard studio audio tuning with flat frequency response.', Icons.graphic_eq),
  bassBoost('Bass Boost', 'Rich low frequencies for immersive narrative score & ambiance.', Icons.speaker),
  trebleBoost('Treble Boost', 'Bright highs for crisp articulation.', Icons.hearing);

  const AudioEnhancementPreset(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}

/// Modal bottom sheet allowing users to tune audio enhancement presets and voice clarity.
class AudioEqualizerSheet extends StatefulWidget {
  const AudioEqualizerSheet({
    super.key,
    required this.controller,
  });

  final PlaybackController controller;

  static Future<void> show(
    BuildContext context, {
    required PlaybackController controller,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AudioEqualizerSheet(controller: controller),
    );
  }

  @override
  State<AudioEqualizerSheet> createState() => _AudioEqualizerSheetState();
}

class _AudioEqualizerSheetState extends State<AudioEqualizerSheet> {
  AudioEnhancementPreset _selectedPreset = AudioEnhancementPreset.speechFocus;
  bool _voiceClarityEnabled = true;
  bool _volumeLevelingEnabled = true;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      key: const ValueKey('audio-equalizer-sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.hairline, width: 1),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.muted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Icon(Icons.tune, size: 20, color: colors.podcastAccent),
              const SizedBox(width: 10),
              Text(
                'AUDIO TUNING & VOICING',
                style: TextStyle(
                  fontFamily: 'Ahem',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: colors.ink,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, size: 20, color: colors.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Presets List
          Text(
            'AUDIO PROFILES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: colors.muted,
            ),
          ),
          const SizedBox(height: 10),

          Column(
            children: AudioEnhancementPreset.values.map((preset) {
              final bool isSelected = _selectedPreset == preset;
              return GestureDetector(
                key: ValueKey('preset-${preset.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedPreset = preset),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.podcastAccent.withValues(alpha: 0.1)
                        : colors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? colors.podcastAccent : colors.hairline,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        preset.icon,
                        size: 18,
                        color: isSelected ? colors.podcastAccent : colors.muted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preset.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? colors.podcastAccent : colors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              preset.description,
                              style: TextStyle(fontSize: 11, color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, size: 18, color: colors.podcastAccent),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Intelligent Enhancements Toggles
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.hairline),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    'Intelligent Voice Clarity',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.ink),
                  ),
                  subtitle: Text(
                    'Isolates speech and reduces background noise',
                    style: TextStyle(fontSize: 10.5, color: colors.muted),
                  ),
                  activeThumbColor: colors.podcastAccent,
                  activeTrackColor: colors.podcastAccent.withValues(alpha: 0.4),
                  value: _voiceClarityEnabled,
                  onChanged: (val) => setState(() => _voiceClarityEnabled = val),
                ),
                Divider(height: 1, color: colors.hairline),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    'Auto Volume Leveling',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.ink),
                  ),
                  subtitle: Text(
                    'Normalizes quiet and loud speakers evenly',
                    style: TextStyle(fontSize: 10.5, color: colors.muted),
                  ),
                  activeThumbColor: colors.podcastAccent,
                  activeTrackColor: colors.podcastAccent.withValues(alpha: 0.4),
                  value: _volumeLevelingEnabled,
                  onChanged: (val) => setState(() => _volumeLevelingEnabled = val),
                ),
              ],
            ),
          ),
        ],
      ),
    ),);
  }
}
