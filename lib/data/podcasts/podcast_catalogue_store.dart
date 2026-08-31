import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/podcast_episode.dart';

/// Persists resolved show metadata and episode lists so shows load instantly.
abstract class PodcastCatalogueStore {
  Future<List<PodcastSeries>> load();
  Future<void> save(List<PodcastSeries> shows);
}

class InMemoryPodcastCatalogueStore implements PodcastCatalogueStore {
  List<PodcastSeries> _shows = const [];

  @override
  Future<List<PodcastSeries>> load() async => List<PodcastSeries>.of(_shows);

  @override
  Future<void> save(List<PodcastSeries> shows) async {
    _shows = List<PodcastSeries>.of(shows);
  }
}

class SharedPreferencesPodcastCatalogueStore implements PodcastCatalogueStore {
  static const String _key = 'podcast-catalogue-v1';

  @override
  Future<List<PodcastSeries>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final List<dynamic> values = jsonDecode(raw) as List<dynamic>;
      return [
        for (final dynamic value in values)
          if (value is Map<String, dynamic>) PodcastSeries.fromJson(value),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> save(List<PodcastSeries> shows) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> values = [
      for (final PodcastSeries show in shows) show.toJson()
    ];
    await prefs.setString(_key, jsonEncode(values));
  }
}
