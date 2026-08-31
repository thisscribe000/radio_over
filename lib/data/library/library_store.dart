import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the listener's saved (bookmarked) podcast episodes and followed
/// podcast shows across restarts.
///
/// Stores stable ids only — never episode/show objects. This is deliberately
/// separate from downloads, playback progress and listen history so that each
/// of those states stays independent (unsaving an episode does not touch its
/// download, progress or history).
abstract class LibraryStore {
  /// Restores the saved episode ids (in the order they were saved).
  Future<List<String>> loadSavedEpisodes();

  /// Restores the followed show ids (in the order they were followed).
  Future<List<String>> loadSavedShows();

  /// Restores the followed creator ids (in the order they were followed).
  Future<List<String>> loadSavedCreators();

  /// Replaces the entire saved-episode set with [episodes].
  Future<void> saveSavedEpisodes(List<String> episodes);

  /// Replaces the entire followed-shows set with [shows].
  Future<void> saveSavedShows(List<String> shows);

  /// Replaces followed creators with [creators].
  Future<void> saveSavedCreators(List<String> creators);
}

/// Session-only store: the default so widget tests behave deterministically
/// without touching platform channels.
class InMemoryLibraryStore implements LibraryStore {
  List<String> _episodes = const [];
  List<String> _shows = const [];
  List<String> _creators = const [];

  @override
  Future<List<String>> loadSavedEpisodes() async => List<String>.of(_episodes);

  @override
  Future<List<String>> loadSavedShows() async => List<String>.of(_shows);

  @override
  Future<List<String>> loadSavedCreators() async => List<String>.of(_creators);

  @override
  Future<void> saveSavedEpisodes(List<String> episodes) async {
    _episodes = List<String>.of(episodes);
  }

  @override
  Future<void> saveSavedShows(List<String> shows) async {
    _shows = List<String>.of(shows);
  }

  @override
  Future<void> saveSavedCreators(List<String> creators) async {
    _creators = List<String>.of(creators);
  }
}

/// [SharedPreferences]-backed store used by the real app entrypoint.
class SharedPreferencesLibraryStore implements LibraryStore {
  static const String _episodesKey = 'saved-episodes-v1';
  static const String _showsKey = 'saved-shows-v1';
  static const String _creatorsKey = 'saved-creators-v1';

  @override
  Future<List<String>> loadSavedEpisodes() async =>
      _read(_episodesKey);

  @override
  Future<List<String>> loadSavedShows() async => _read(_showsKey);

  @override
  Future<List<String>> loadSavedCreators() async => _read(_creatorsKey);

  @override
  Future<void> saveSavedEpisodes(List<String> episodes) async =>
      _write(_episodesKey, episodes);

  @override
  Future<void> saveSavedShows(List<String> shows) async =>
      _write(_showsKey, shows);

  @override
  Future<void> saveSavedCreators(List<String> creators) async =>
      _write(_creatorsKey, creators);

  Future<List<String>> _read(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return <String>[
        for (final dynamic id in list)
          if (id is String && id.trim().isNotEmpty) id,
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _write(String key, List<String> ids) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(ids));
  }
}
