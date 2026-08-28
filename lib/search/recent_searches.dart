import 'dart:async';

import 'package:flutter/foundation.dart';

import 'recent_search_store.dart';

/// The listener's saved search terms, most recent first.
///
/// The whole list is the store's public surface. Persistence is delegated to
/// an injectable [RecentSearchStore] (in-memory by default so widget tests are
/// deterministic); the real app wires [SharedPreferences] via [main].
class RecentSearches extends ChangeNotifier {
  RecentSearches({
    int limit = defaultLimit,
    RecentSearchStore? store,
  })  : _limit = limit,
        _store = store ?? _InMemoryRecentSearchStore();

  static const int defaultLimit = 10;

  final int _limit;
  final RecentSearchStore _store;
  final List<String> _entries = [];

  List<String> get entries => List.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

  /// Restores a previously persisted history. Must be awaited before the
  /// list is shown; safe to call once at startup.
  Future<void> restore() async {
    final List<String> saved = await _store.load();
    _entries
      ..clear()
      ..addAll(saved.take(_limit));
    notifyListeners();
  }

  void add(String term) {
    final String trimmed = term.trim();
    if (trimmed.isEmpty) return;
    _entries.removeWhere(
      (e) => e.toLowerCase() == trimmed.toLowerCase(),
    );
    _entries.insert(0, trimmed);
    if (_entries.length > _limit) {
      _entries.removeRange(_limit, _entries.length);
    }
    notifyListeners();
    unawaited(_store.save(_entries));
  }

  void remove(String term) {
    final String trimmed = term.trim();
    _entries.removeWhere(
      (e) => e.toLowerCase() == trimmed.toLowerCase(),
    );
    notifyListeners();
    unawaited(_store.save(_entries));
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
    unawaited(_store.save(_entries));
  }
}

/// Session-only store for the default `RecentSearches()`, so widget tests stay
/// deterministic and off platform channels.
class _InMemoryRecentSearchStore implements RecentSearchStore {
  List<String> _terms = const [];

  @override
  Future<List<String>> load() async => List<String>.of(_terms);

  @override
  Future<void> save(List<String> terms) async {
    _terms = List<String>.of(terms);
  }
}