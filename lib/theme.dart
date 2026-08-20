import 'package:flutter/material.dart';

/// Central design tokens.
///
/// The app follows a minimal, editorial visual language: an off-white canvas,
/// near-black ink, thin hairlines and generous whitespace.
abstract final class AppColors {
  static const Color background = Color(0xFFF6F4EF);
  static const Color ink = Color(0xFF1B1A16);
  static const Color muted = Color(0xFF8A857B);
  static const Color hairline = Color(0xFFE3DFD6);
  static const Color accent = Color(0xFFA03A2C);

  /// Muted teal used by podcast surfaces only, so podcasts read as recorded
  /// time while radio keeps its live terracotta accent. Deliberately subtle:
  /// the two players stay in the same visual family.
  static const Color podcastAccent = Color(0xFF2F5D6B);
}

/// Shared text styles. Typography carries the design.
abstract final class AppTextStyles {
  static const TextStyle display = TextStyle(
    fontSize: 40,
    height: 0.95,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.ink,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: AppColors.muted,
  );

  static const TextStyle stationName = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );

  static const TextStyle stationCategory = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );

  static const TextStyle playerStation = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.3,
    color: AppColors.ink,
  );

  static const TextStyle playerProgram = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );

  static const TextStyle live = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: AppColors.accent,
  );

  static const TextStyle timeLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    color: AppColors.muted,
  );

  /// Small label in a screen's top bar (e.g. "RADIO" on the player).
  static const TextStyle navLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: AppColors.ink,
  );

  /// Emphasis station name inside the player.
  static const TextStyle stationTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    height: 1.1,
    color: AppColors.ink,
  );

  /// Secondary programme line inside the player.
  static const TextStyle stationProgramme = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );

  /// Small uppercase label above the player's bottom information.
  static const TextStyle nowPlayingLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: AppColors.muted,
  );

  static const TextStyle nowPlayingProgramme = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: AppColors.ink,
  );
}

ThemeData buildAppTheme() {
  const ColorScheme scheme = ColorScheme.light(
    primary: AppColors.ink,
    onPrimary: AppColors.background,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    surface: AppColors.background,
    onSurface: AppColors.ink,
    error: AppColors.accent,
    onError: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
  );
}