import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists RSS feed URLs imported by the listener.
abstract class PodcastFeedStore {
  Future<List<String>> load();
  Future<void> save(List<String> feedUrls);
}

class InMemoryPodcastFeedStore implements PodcastFeedStore {
  List<String> _urls = const [];

  @override
  Future<List<String>> load() async => List<String>.of(_urls);

  @override
  Future<void> save(List<String> feedUrls) async {
    _urls = List<String>.of(feedUrls);
  }
}

class SharedPreferencesPodcastFeedStore implements PodcastFeedStore {
  static const String _key = 'podcast-feeds-v1';

  @override
  Future<List<String>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final List<dynamic> values = jsonDecode(raw) as List<dynamic>;
      return [
        for (final dynamic value in values)
          if (value is String && value.trim().isNotEmpty) value.trim(),
      ];
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> save(List<String> feedUrls) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(feedUrls));
  }
}
