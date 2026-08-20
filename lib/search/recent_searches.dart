import 'package:flutter/foundation.dart';

/// The listener's saved search terms, most recent first.
///
/// In-memory for now (the app has no persistence layer yet). The whole list is
/// the store's public surface, so connecting SharedPreferences or a backend
/// later only needs to implement the same add/remove/clear contract.
class RecentSearches extends ChangeNotifier {
  RecentSearches({int limit = defaultLimit}) : _limit = limit;

  static const int defaultLimit = 10;

  final int _limit;
  final List<String> _entries = [];

  List<String> get entries => List.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

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
  }

  void remove(String term) {
    final String trimmed = term.trim();
    _entries.removeWhere(
      (e) => e.toLowerCase() == trimmed.toLowerCase(),
    );
    notifyListeners();
  }

  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }
}