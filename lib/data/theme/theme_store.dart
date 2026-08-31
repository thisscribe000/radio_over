import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the active theme mode selection across restarts.
abstract class ThemeStore {
  Future<ThemeMode> loadThemeMode();
  Future<void> saveThemeMode(ThemeMode mode);
}

/// Simple in-memory fallback for widget tests to avoid platform channels.
class InMemoryThemeStore implements ThemeStore {
  InMemoryThemeStore({ThemeMode initial = ThemeMode.system}) : _mode = initial;

  ThemeMode _mode;

  @override
  Future<ThemeMode> loadThemeMode() async => _mode;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    _mode = mode;
  }
}

/// SharedPreferences-backed store used in production.
class SharedPreferencesThemeStore implements ThemeStore {
  static const String _key = 'theme-mode-v1';

  @override
  Future<ThemeMode> loadThemeMode() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? value = prefs.getString(_key);
      if (value == 'light') return ThemeMode.light;
      if (value == 'dark') return ThemeMode.dark;
      return ThemeMode.system;
    } catch (_) {
      return ThemeMode.system;
    }
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String value = 'system';
      if (mode == ThemeMode.light) value = 'light';
      if (mode == ThemeMode.dark) value = 'dark';
      await prefs.setString(_key, value);
    } catch (_) {
      // Best-effort.
    }
  }
}
