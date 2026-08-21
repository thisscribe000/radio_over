import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/download.dart';

/// Persists download state across restarts. Stores [DownloadItem] records
/// only — never episode objects and never file contents.
abstract class DownloadStore {
  Future<List<DownloadItem>> load();

  Future<void> save(List<DownloadItem> items);
}

/// Session-only store: the default so widget tests behave deterministically
/// without touching platform channels.
class InMemoryDownloadStore implements DownloadStore {
  List<DownloadItem> _data = const [];

  @override
  Future<List<DownloadItem>> load() async => List<DownloadItem>.of(_data);

  @override
  Future<void> save(List<DownloadItem> items) async {
    _data = List<DownloadItem>.of(items);
  }
}

/// [SharedPreferences]-backed store used by the real app entrypoint.
class SharedPreferencesDownloadStore implements DownloadStore {
  static const String _key = 'podcast-downloads-v1';

  @override
  Future<List<DownloadItem>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return <DownloadItem>[
        for (final dynamic entry in list)
          if (entry is Map<String, dynamic>) DownloadItem.fromJson(entry),
      ];
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> save(List<DownloadItem> items) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final DownloadItem item in items) item.toJson()]),
    );
  }
}
