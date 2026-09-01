import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/podcast_episode.dart';

/// Service responsible for fetching, parsing, and caching remote podcast
/// transcripts (WebVTT, SRT, JSON) and chapters (JSON chapters standard).
class PodcastTranscriptService {
  PodcastTranscriptService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  final Map<String, List<PodcastCaption>> _captionCache = {};
  final Map<String, List<PodcastChapter>> _chapterCache = {};

  /// Fetches and parses remote transcript from [url]. Returns null on network/parse failure.
  Future<List<PodcastCaption>?> loadCaptions(String url, {String? type}) async {
    if (_captionCache.containsKey(url)) {
      return _captionCache[url];
    }
    try {
      final response = await _client.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<PodcastCaption> parsed = parseTranscript(response.body, type: type);
        if (parsed.isNotEmpty) {
          _captionCache[url] = parsed;
          return parsed;
        }
      }
    } catch (_) {
      // Graceful fallback to null
    }
    return null;
  }

  /// Fetches and parses remote chapters from [url]. Returns null on failure.
  Future<List<PodcastChapter>?> loadChapters(String url) async {
    if (_chapterCache.containsKey(url)) {
      return _chapterCache[url];
    }
    try {
      final response = await _client.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<PodcastChapter> parsed = parseChaptersJson(response.body);
        if (parsed.isNotEmpty) {
          _chapterCache[url] = parsed;
          return parsed;
        }
      }
    } catch (_) {
      // Graceful fallback to null
    }
    return null;
  }

  /// Parses WebVTT, SRT, or JSON transcript body into [PodcastCaption] models.
  static List<PodcastCaption> parseTranscript(String rawContent, {String? type}) {
    final String content = rawContent.trim();
    if (content.isEmpty) return const [];

    // Try parsing as JSON transcript first if it starts with { or [
    if (content.startsWith('{') || content.startsWith('[')) {
      try {
        final decoded = json.decode(content);
        if (decoded is Map<String, dynamic> && decoded['segments'] is List) {
          final List segments = decoded['segments'] as List;
          return [
            for (final seg in segments)
              if (seg is Map && seg['startTime'] != null && seg['body'] != null)
                PodcastCaption(
                  start: _secondsToDuration((seg['startTime'] as num).toDouble()),
                  text: seg['body'].toString().trim(),
                )
          ];
        }
      } catch (_) {}
    }

    // Parse standard WebVTT / SRT
    return parseWebVttOrSrt(content);
  }

  /// Parses WebVTT / SubRip text cues.
  static List<PodcastCaption> parseWebVttOrSrt(String content) {
    final List<PodcastCaption> captions = [];
    final List<String> lines = const LineSplitter().convert(content);

    final RegExp timecodeRegex = RegExp(
      r'((?:(\d+):)?(\d{1,2}):(\d{2})[.,](\d{3}))\s*-->\s*((?:(\d+):)?(\d{1,2}):(\d{2})[.,](\d{3}))',
    );

    Duration? currentStart;
    final StringBuffer currentText = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i].trim();
      if (line.isEmpty) {
        if (currentStart != null && currentText.isNotEmpty) {
          captions.add(PodcastCaption(
            start: currentStart,
            text: currentText.toString().trim(),
          ));
          currentStart = null;
          currentText.clear();
        }
        continue;
      }

      final Match? match = timecodeRegex.firstMatch(line);
      if (match != null) {
        // Save previous if any
        if (currentStart != null && currentText.isNotEmpty) {
          captions.add(PodcastCaption(
            start: currentStart,
            text: currentText.toString().trim(),
          ));
          currentText.clear();
        }
        currentStart = _parseTimestamp(match.group(1)!);
      } else if (currentStart != null) {
        // Ignore sequence index numbers
        if (RegExp(r'^\d+$').hasMatch(line) && currentText.isEmpty) {
          continue;
        }
        // Remove HTML-like tags (e.g. <v Speaker>, <c.color>)
        final String cleanText = line.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        if (cleanText.isNotEmpty) {
          if (currentText.isNotEmpty) currentText.write(' ');
          currentText.write(cleanText);
        }
      }
    }

    if (currentStart != null && currentText.isNotEmpty) {
      captions.add(PodcastCaption(
        start: currentStart,
        text: currentText.toString().trim(),
      ));
    }

    return captions;
  }

  /// Parses Podcast 2.0 Chapters JSON standard.
  static List<PodcastChapter> parseChaptersJson(String jsonString) {
    final List<PodcastChapter> chapters = [];
    try {
      final decoded = json.decode(jsonString);
      if (decoded is Map<String, dynamic> && decoded['chapters'] is List) {
        final List rawChapters = decoded['chapters'] as List;
        for (final item in rawChapters) {
          if (item is Map<String, dynamic>) {
            final double startTimeSec = (item['startTime'] as num?)?.toDouble() ?? 0.0;
            final String title = (item['title'] as String?)?.trim() ?? 'Untitled Chapter';
            final String? description = (item['description'] as String?)?.trim();
            chapters.add(
              PodcastChapter(
                title: title,
                start: _secondsToDuration(startTimeSec),
                description: description,
              ),
            );
          }
        }
      }
    } catch (_) {}
    return chapters;
  }

  static Duration _parseTimestamp(String timeStr) {
    final String normalized = timeStr.replaceAll(',', '.');
    final List<String> parts = normalized.split(':');
    if (parts.length == 3) {
      final int hours = int.parse(parts[0]);
      final int minutes = int.parse(parts[1]);
      final double seconds = double.parse(parts[2]);
      return Duration(
        hours: hours,
        minutes: minutes,
        milliseconds: (seconds * 1000).round(),
      );
    } else if (parts.length == 2) {
      final int minutes = int.parse(parts[0]);
      final double seconds = double.parse(parts[1]);
      return Duration(
        minutes: minutes,
        milliseconds: (seconds * 1000).round(),
      );
    }
    return Duration.zero;
  }

  static Duration _secondsToDuration(double seconds) {
    return Duration(milliseconds: (seconds * 1000).round());
  }
}
