import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/audio_snippet.dart';

/// Persistence seam for community-shared podcast audio snippets.
abstract class SnippetStore {
  Future<List<AudioSnippet>> loadSnippets();
  Future<void> saveSnippets(List<AudioSnippet> snippets);
}

/// Curated starter snippets so new users immediately have interesting content
/// on the timeline to listen to and interact with.
final List<AudioSnippet> defaultStarterSnippets = [
  AudioSnippet(
    id: 'snippet-starter-1',
    userId: 'user-maya',
    userName: 'Maya Lin',
    isVerified: true,
    podcastId: 'darknet-diaries',
    podcastName: 'Darknet Diaries',
    episodeId: 'darknet-140',
    episodeTitle: 'The Phantom Hacker of Prague',
    audioUrl: 'https://traffic.libsyn.com/darknetdiaries/140_phantom.mp3',
    start: const Duration(minutes: 4, seconds: 12),
    end: const Duration(minutes: 4, seconds: 48),
    caption: '“The moment he realized the server was talking back to him...” Truly chilling audio storytelling!',
    likesCount: 42,
    commentsCount: 2,
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  AudioSnippet(
    id: 'snippet-starter-2',
    userId: 'user-sam',
    userName: 'Sam K.',
    isVerified: true,
    podcastId: '99pi',
    podcastName: '99% Invisible',
    episodeId: '99pi-520',
    episodeTitle: 'The Architecture of Silence',
    audioUrl: 'https://dts.podtrac.com/redirect.mp3/chtbl.com/track/99pi/520_silence.mp3',
    start: const Duration(minutes: 12, seconds: 05),
    end: const Duration(minutes: 12, seconds: 40),
    caption: 'Why anechoic chambers make you hear your own heartbeat in 45 seconds. Mind blown.',
    likesCount: 88,
    commentsCount: 1,
    createdAt: DateTime.now().subtract(const Duration(hours: 7)),
  ),
  AudioSnippet(
    id: 'snippet-starter-3',
    userId: 'user-alex',
    userName: 'Alex Rivers',
    isVerified: false,
    podcastId: 'huberman-lab',
    podcastName: 'Huberman Lab',
    episodeId: 'huberman-182',
    episodeTitle: 'Optimizing Deep Sleep & Circadian Rhythms',
    audioUrl: 'https://dts.podtrac.com/redirect.mp3/chtbl.com/track/huberman/182_sleep.mp3',
    start: const Duration(minutes: 18, seconds: 30),
    end: const Duration(minutes: 19, seconds: 10),
    caption: 'The 10-3-2-1 rule for the best night of sleep you will ever get. Everyone needs to hear this!',
    likesCount: 156,
    commentsCount: 5,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

/// In-memory implementation used during tests and before preferences initialize.
class InMemorySnippetStore implements SnippetStore {
  InMemorySnippetStore({List<AudioSnippet>? initial})
      : _snippets = List.of(initial ?? defaultStarterSnippets);

  final List<AudioSnippet> _snippets;

  @override
  Future<List<AudioSnippet>> loadSnippets() async => List.unmodifiable(_snippets);

  @override
  Future<void> saveSnippets(List<AudioSnippet> snippets) async {
    _snippets
      ..clear()
      ..addAll(snippets);
  }
}

/// SharedPreferences persistent storage for snippets.
class SharedPreferencesSnippetStore implements SnippetStore {
  SharedPreferencesSnippetStore({SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync();

  static const String _key = 'podcast-snippets-v1';
  final SharedPreferencesAsync _prefs;

  @override
  Future<List<AudioSnippet>> loadSnippets() async {
    try {
      final String? raw = await _prefs.getString(_key);
      if (raw == null || raw.isEmpty) {
        return List.of(defaultStarterSnippets);
      }
      final decoded = json.decode(raw);
      if (decoded is List) {
        final loaded = decoded
            .whereType<Map<String, dynamic>>()
            .map(AudioSnippet.fromJson)
            .toList();
        if (loaded.isNotEmpty) return loaded;
      }
    } catch (_) {}
    return List.of(defaultStarterSnippets);
  }

  @override
  Future<void> saveSnippets(List<AudioSnippet> snippets) async {
    try {
      final encoded = json.encode(snippets.map((s) => s.toJson()).toList());
      await _prefs.setString(_key, encoded);
    } catch (_) {}
  }
}
