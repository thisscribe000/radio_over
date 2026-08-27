import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/playback_progress.dart';

/// Persists podcast playback progress across restarts.
///
/// Stores [PlaybackProgress] records keyed by episode id. The actual episode
/// objects stay in the content catalogue — only position/duration/timestamps
/// are written here.
abstract class PlaybackProgressStore {
  /// Restores all saved progress: episode id → record.
  Future<Map<String, PlaybackProgress>> load();

  /// Replaces the stored set with [progress].
  Future<void> save(Map<String, PlaybackProgress> progress);
}

/// Session-only store: the default so widget tests behave deterministically
/// without touching platform channels.
class InMemoryPlaybackProgressStore implements PlaybackProgressStore {
  Map<String, PlaybackProgress> _data = {};

  @override
  Future<Map<String, PlaybackProgress>> load() async =>
      Map<String, PlaybackProgress>.of(_data);

  @override
  Future<void> save(Map<String, PlaybackProgress> progress) async {
    _data = Map<String, PlaybackProgress>.of(progress);
  }
}

/// [SharedPreferences]-backed store used by the real app entrypoint.
class SharedPreferencesPlaybackProgressStore implements PlaybackProgressStore {
  static const String _key = 'playback-progress-v1';

  @override
  Future<Map<String, PlaybackProgress>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return <String, PlaybackProgress>{
        for (final dynamic entry in list)
          if (entry is Map<String, dynamic>)
            if (_fromJson(entry) case final PlaybackProgress progress)
              progress.episodeId: progress,
      };
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> save(Map<String, PlaybackProgress> progress) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final PlaybackProgress p in progress.values) _toJson(p)]),
    );
  }
}

Map<String, dynamic> _toJson(PlaybackProgress p) => <String, dynamic>{
      'episodeId': p.episodeId,
      'positionMs': p.position.inMilliseconds,
      'durationMs': p.duration.inMilliseconds,
      'updatedAtMs': p.updatedAt.millisecondsSinceEpoch,
      'completed': p.completed,
    };

PlaybackProgress? _fromJson(Map<String, dynamic> json) {
  final String? episodeId = (json['episodeId'] as String?)?.trim();
  final int? positionMs = (json['positionMs'] as num?)?.toInt();
  final int? durationMs = (json['durationMs'] as num?)?.toInt();
  final int? updatedAtMs = (json['updatedAtMs'] as num?)?.toInt();
  if (episodeId == null || episodeId.isEmpty || positionMs == null) return null;
  return PlaybackProgress(
    episodeId: episodeId,
    position: Duration(milliseconds: positionMs),
    duration: Duration(milliseconds: durationMs ?? 0),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs ?? 0),
    completed: json['completed'] is bool ? json['completed'] as bool : false,
  );
}
