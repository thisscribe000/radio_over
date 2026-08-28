import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the listener's recent search terms, most recent first.
///
/// Stores simple search strings only — as they were typed — so restoring the
/// history needs no content resolution. Defaults to in-memory so widget tests
/// never touch platform channels; the real app wires [SharedPreferences]
/// (key `recent-searches-v1`).
abstract class RecentSearchStore {
  /// Restores the saved terms, most recent first.
  Future<List<String>> load();

  /// Replaces the entire history with [terms], most recent first.
  Future<void> save(List<String> terms);
}

/// Session-only store: recreated per instance so behaviour is deterministic.
class InMemoryRecentSearchStore implements RecentSearchStore {
  InMemoryRecentSearchStore();

  List<String> _terms = const [];

  @override
  Future<List<String>> load() async => List<String>.of(_terms);

  @override
  Future<void> save(List<String> terms) async {
    _terms = List<String>.of(terms);
  }
}

/// [SharedPreferences]-backed store used by the real app entrypoint.
class SharedPreferencesRecentSearchStore implements RecentSearchStore {
  static const String _key = 'recent-searches-v1';

  @override
  Future<List<String>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return <String>[
        for (final dynamic term in list)
          if (term is String && term.trim().isNotEmpty) term,
      ];
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> save(List<String> terms) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(terms));
  }
}
