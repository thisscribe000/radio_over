import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AppColors — ThemeExtension
//
// Resolved color tokens for the current brightness.
//
// Light anchor: Silk Ivory  (#FFFFF0) — warm editorial paper.
// Dark anchor:  Eclipse Abyss (#0D0D0D) — rich near-black.
//
// Usage inside any build() method:
//   final colors = AppColors.of(context);
//   colors.ink, colors.muted, colors.accent, …
// ---------------------------------------------------------------------------
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.card,
    required this.ink,
    required this.muted,
    required this.hairline,
    required this.accent,
    required this.podcastAccent,
  });

  final Color background;
  final Color card;
  final Color ink;
  final Color muted;
  final Color hairline;
  final Color accent;
  final Color podcastAccent;

  // ── Light theme — Silk Ivory canvas ──────────────────────────────────────
  static const AppColors light = AppColors(
    background: Color(0xFFFFFFF0),    // Silk Ivory
    card: Color(0xFFF5F5F5),          // Moonstone Gray
    ink: Color(0xFF1A1815),           // warm charcoal
    muted: Color(0xFF8A857B),
    hairline: Color(0xFFEAE8E1),      // Muted Sage
    accent: Color(0xFFA03A2C),        // terracotta
    podcastAccent: Color(0xFF2F5D6B), // muted teal
  );

  // ── Dark theme — Eclipse Abyss canvas ────────────────────────────────────
  static const AppColors dark = AppColors(
    background: Color(0xFF0D0D0D),    // Eclipse Abyss
    card: Color(0xFF1A1A1A),
    ink: Color(0xFFFFFFF0),           // Silk Ivory (inverted)
    muted: Color(0xFFADAA9F),         // warm mid-grey — legible on #0D0D0D
    hairline: Color(0xFF2E2E2E),
    accent: Color(0xFFCF6679),        // soft rose
    podcastAccent: Color(0xFF6DBBA1), // sage green
  );

  /// Resolve the [AppColors] tokens for the current [BuildContext].
  ///
  /// Falls back to [light] if the extension is somehow missing.
  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  // ── ThemeExtension boilerplate ───────────────────────────────────────────
  @override
  AppColors copyWith({
    Color? background,
    Color? card,
    Color? ink,
    Color? muted,
    Color? hairline,
    Color? accent,
    Color? podcastAccent,
  }) {
    return AppColors(
      background: background ?? this.background,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      hairline: hairline ?? this.hairline,
      accent: accent ?? this.accent,
      podcastAccent: podcastAccent ?? this.podcastAccent,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      podcastAccent: Color.lerp(podcastAccent, other.podcastAccent, t)!,
    );
  }
}

// ---------------------------------------------------------------------------
// AppTextStyles — typography without hardcoded colors.
//
// Colors are intentionally omitted here and applied at each call site with
// .copyWith(color: colors.ink) so the correct dark/light token is used.
// ---------------------------------------------------------------------------
abstract final class AppTextStyles {
  static const TextStyle display = TextStyle(
    fontSize: 40,
    height: 0.95,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );

  static const TextStyle stationName = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle stationCategory = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle playerStation = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.3,
  );

  static const TextStyle playerProgram = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle live = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  static const TextStyle timeLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );

  static const TextStyle navLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
  );

  static const TextStyle stationTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    height: 1.1,
  );

  static const TextStyle stationProgramme = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle nowPlayingLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );

  static const TextStyle nowPlayingProgramme = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );
}

// ---------------------------------------------------------------------------
// buildAppTheme
// ---------------------------------------------------------------------------
ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final bool isDark = brightness == Brightness.dark;
  final AppColors colors = isDark ? AppColors.dark : AppColors.light;

  final ColorScheme scheme = isDark
      ? ColorScheme.dark(
          primary: colors.ink,
          onPrimary: colors.background,
          secondary: colors.accent,
          onSecondary: colors.background,
          surface: colors.card,
          onSurface: colors.ink,
          error: colors.accent,
          onError: colors.background,
        )
      : ColorScheme.light(
          primary: colors.ink,
          onPrimary: colors.background,
          secondary: colors.accent,
          onSecondary: Colors.white,
          surface: colors.card,
          onSurface: colors.ink,
          error: colors.accent,
          onError: Colors.white,
        );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    cardColor: colors.card,
    dividerColor: colors.hairline,
    // Default text color follows theme so unlabelled Text widgets are correct.
    textTheme: ThemeData(brightness: brightness)
        .textTheme
        .apply(bodyColor: colors.ink, displayColor: colors.ink),
    extensions: [colors],
  );
}